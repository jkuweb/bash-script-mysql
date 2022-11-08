#!/bin/bash

source helpers.sh
declare -r optional_arg="$1"

export serverip=$(__get_ip)

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"


# Check if you are root user or not
function is_root_user() {
     user=$(id -u)
     write_title "${purpleColour}Verificar si es usuario root${endColour}"
     if [ $user != 0  ]; then
      echo -e "${redColour}[!]Permiso denegado.${endColour}"
      echo -e "${blueColour}Este programa solo puede ser ejecutado por el usuario root${endColour}"
      exit
   else
      clear
      cat templates/texts/welcome
   fi
}

# Set HostName
function set_hostname() {
        write_title "${purpleColour}1. Configurar Hostname${endColour}"
        echo -n -e "\n${yellowColour} ¿Desea configurar un hostname? (y/n): ${endColour}"; read config_host
        if [ "$config_host" == "y" ]; then
                echo -e "\n${blueColour}Ingrese un nombre para identificar a este servidor${endColour}"
                echo -n -e "\n${blueColour}(por ejemplo: myserver): ${endColour}"; read host_name
                echo $host_name > /etc/hostname
                hostname -F /etc/hostname
        fi
        say_done
}

# Configurar locale
function set_locale() {
	write_title "Configurar locale"
	export LANGUAJE=es_ES.UTF-8
	export LANG=es_ES.UTF-8
	export LC=es_ES.UTF-8
	locale-gen es_ES.UTF-8
	dpkg-reconfigure locales
}

# Set time zone
function set_hour() {
    write_title "${purpleColour}2. Configuración de la zona horaria${endColour}"
    dpkg-reconfigure tzdata
    say_done
}


# System update
function sysupdate() {
    write_title "${purpleColour}3. Actualización del sistema${endColour}"
    apt update && apt upgrade -y
    say_done
}

# Crear un nuevo usuario con privilegios
function set_new_user() {
    write_title "Creación de un nuevo usuario"
    echo -n " Indique un nombre para el nuevo usuario: "; read username
    adduser $username
    say_done
}

# Instrucciones para generar una RSA Key
function give_instructions() {
    write_title "Generación de llave RSA en su ordenador local"
    echo " *** SI NO TIENE UNA LLAVE RSA PÚBLICA EN SU ORDENADOR, GENERE UNA ***"
    echo "     Siga las instrucciones y pulse INTRO cada vez que termine una"
    echo "     tarea para recibir una nueva instrucción"
    echo " "
    echo "     EJECUTE LOS SIGUIENTES COMANDOS:"
    echo -n "     a) ssh-keygen "; read foo1
    echo -n "     b) scp .ssh/id_rsa.pub $username@$serverip:/home/$username/ "; read foo2
    say_done
}


#  Mover la llave pública RSA generada
function move_rsa() {
    write_title "Se moverá la llave pública RSA generada en el paso 5"
    mkdir /home/$username/.ssh
    mv /home/$username/id_rsa.pub /home/$username/.ssh/authorized_keys
    chmod 700 /home/$username/.ssh
    chmod 600 /home/$username/.ssh/authorized_keys
    chown -R $username:$username /home/$username/.ssh
    say_done
}

#  Securizar SSH
function ssh_reconfigure() {
    write_title "Securizar accesos SSH"
    
    if [ "$optional_arg" == "--custom" ]; then
        echo -n "Puerto SSH (Ej: 372): "; read puerto
    else
        puerto="372"
    fi

    sed s/USERNAME/$username/g templates/sshd_config > /tmp/sshd_config
    sed s/PUERTO/$puerto/g /tmp/sshd_config > /etc/ssh/sshd_config
    service ssh restart
    say_done
}


#  Establecer reglas para iptables
function set_iptables_rules() {
    write_title "Establecer reglas para iptables (firewall)"
    apt install iptables -y 
    sed s/PUERTO/$puerto/g templates/iptables > /etc/iptables.firewall.rules
    iptables-restore < /etc/iptables.firewall.rules
    say_done
}


#  Crear script de automatizacion iptables
function create_iptable_script() {
    write_title "Crear script de automatización de reglas de iptables tras reinicio"
    cat templates/firewall > /etc/network/if-pre-up.d/firewall
    chmod +x /etc/network/if-pre-up.d/firewall
    say_done
}


# Instalar fail2ban
function install_fail2ban() {
    # para eliminar una regla de fail2ban en iptables utilizar:
    # iptables -D fail2ban-ssh -s IP -j DROP
    write_title "Instalar fail2ban"    
    apt install fail2ban -y
    say_done
}

# Tunning .bashrc
function tunning_bashrc() {
    write_title "${purpleColour}19. Reemplazar .bashrc${endColour}"
    cp templates/bashrc-root /root/.bashrc
    cp templates/bashrc-user /home/$username/.bashrc
    chown $username:$username /home/$username/.bashrc
    cp templates/bashrc-user /etc/skel/.bashrc
        echo 'alias ..="cd .."' >> /home/$username/.bashrc
        echo 'alias ls -la="lsa"' >> /home/$username/.bashrc
    say_done
}


# Install y tunning VIM
function install_vim() {
        apt install vim -y
        git clone https://github.com/jkuweb/my-vim.git
        chown -R $username:$username my-vim/
        rm -rf /home/$username/.vim
        mv -f my-vim/.vim* /home/$username/
        git clone https://github.com/VundleVim/Vundle.vim.git /home/$username/.vim/bundle/Vundle.vim

        rm -rf /root/my-vim
    say_done
}


# Install mysql-server 
function install_mysql-server() {
    write_title "${purpleColour}Instalación de mysql-server${endColour}"
        apt install default-mysql-server -y
        mysql_secure_installation
    say_done
}


# Set Bind address 
function set_mysql_bind_address() {
    write_title "${purpleColour}Modificamos el valor de bind address${endColour}"
        cat templates/mysql_bind_address > /etc/mysql/mariadb.conf.d/50-server.cnf
    say_done
}


# Create database
function create_database() {
    write_title "${purpleColour}Creación de una base de datos${endColour}"
    echo -n -e "\n ${blueColour} Indique un nombre para la base de datos: ${endColour}"; read db_name
        mysql -e "CREATE DATABASE ${db_name};"
        say_done
}


# Create user for database
function create_user_database() {
    write_title "${purpleColour}Creación del usuario${endColour}"
    echo -n -e "\n ${blueColour}Indique el nombre de usuario para la base de datos: ${endColour}"; read username
    echo -n -e "\n ${blueColour} Indique contraseña para el usuario ${username}: ${endColour}"; read passwd

        mysql -e "CREATE USER '${username}'@'%' IDENTIFIED BY '${passwd}';"
        mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${username}'@'%';"
        mysql -e "FLUSH PRIVILEGES;"
        say_done
}

# Define ufw rules
function define_ufw_rules() {
    write_title "${purpleColour}Instalar ufw${endColour}"
        apt install ufw
    write_title "${purpleColour}Definir las reglas para ufw${endColour}"
    write_title "${purpleColour}Habilitar ufw${endColour}"
        ufw enable
    write_title "${purpleColour}Permitir conexiones ssh${endColour}"
        ufw allow ssh
    write_title "${purpleColour}Permitir conexiones del servidor donde tenemos alojada la app${endColour}"
    echo -n -e "\n ${blueColour}Indique la IP del servidor donde esta alojada la APP: ${endColour}"; read app_server_ip
        ufw allow from $app_server_ip to any port 3306
        ufw status
        say_done
}


function final_step() {
    write_title "${purpleColour}Finalizar deploy${endColour}"
    cat templates/texts/bye
    reboot
}



set_pause_on                   

is_root_user                    
set_hostname                    
set_hour
set_locale                        
sysupdate                       
set_new_user 
give_instructions        
move_rsa                        
ssh_reconfigure                 
set_iptables_rules              
create_iptable_script           
install_fail2ban                
install_mysql-server
set_mysql_bind_address 
create_database   
create_user_database 
define_ufw_rules          
config_fail2ban          
tunning_vim                   
kernel_config  
final_step 

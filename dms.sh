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


# Install ModEvasive
function install_modevasive() {
    write_title "${purpleColour}16. Instalar ModEvasive${endColour}"
    echo -n -e "\n${blueColour} Indique e-mail para recibir alertas: ${endColour}"; read inbox

    if [ "$inbox" == "" ]; then
        inbox="root@localhost"
    fi

    apt install libapache2-mod-evasive -y
    mkdir /var/log/mod_evasive
    chown www-data:www-data /var/log/mod_evasive/
    modevasive="/etc/apache2/mods-available/mod-evasive.conf"
    sed s/MAILTO/$inbox/g templates/mod-evasive > $modevasive
    a2enmod evasive
    service apache2 restart
    say_done
}


# Install OWASP for ModSecuity
function install_owasp_core_rule_set() {
    write_title "${purpleColour}14. Instalar OWASP ModSecurity Core Rule Set${endColour}"

    write_title "${purpleColour}14.2 Clonar repositorio${endColour}"
    mkdir /etc/apache2/modsecurity.d
    git clone https://github.com/SpiderLabs/owasp-modsecurity-crs /etc/apache2/modsecurity.d

    write_title "${purpleColour}14.3 Mover archivo de configuración${endColour}"
    mv /etc/apache2/modsecurity.d/crs-setup.conf.example /etc/apache2/modsecurity.d/crs-setup.conf

    write_title "${purpleColour}14.4 Renombrar reglas de pre y post ejecución${endColour}"
    mv /etc/apache2/modsecurity.d/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example \
        /etc/apache2/modsecurity.d/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
    mv /etc/apache2/modsecurity.d/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example \
        /etc/apache2/modsecurity.d/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf

    write_title "${purpleColour}14.4 Reemplazar configuración del módulo${endColour}"
    cp templates/security2 /etc/apache2/mods-available/security2.conf


    modsecrec="/etc/modsecurity/modsecurity.conf${endColour}"
    sed s/SecRuleEngine\ DetectionOnly/SecRuleEngine\ On/g $modsecrec > /tmp/salida
    mv /tmp/salida /etc/modsecurity/modsecurity.conf

    if [ "$optional_arg" == "--custom" ]; then
        echo -n "Firma servidor: "; read firmaserver
        echo -n "Powered: "; read poweredby
    else
        firmaserver="Oracle Solaris 11.2"
        poweredby="n/a"
    fi

    modseccrs10su="/etc/apache2/modsecurity.d/crs-setup.conf"
    echo "SecServerSignature \"$firmaserver\"" >> $modseccrs10su
    echo "Header set X-Powered-By \"$poweredby\"" >> $modseccrs10su

    a2enmod headers
    service apache2 restart
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
sysupdate
tunning_bashrc
install_owasp_core_rule_set
install_modevasive
install_vim
install_mysql-server
set_mysql_bind_address
create_database
create_user_database
define_ufw_rules
final_step

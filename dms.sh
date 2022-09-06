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

# 0. Verificar si es usuario root o no
function is_root_user() {
	if [ echo whoami != "root" ]; then 
		echo -e "\n${redColour}[!]Permiso denegado.${endColour}"
		echo -e "\n${blueColour}Este programa solo puede ser ejecutado por el usuario root.${endColour}"
		exit
	else
		clear
		cat templates/texts/welcome
	fi
}

# 1. Configurar Hostname
function set_hostname() {
	write_title "${purpleColour}1. Configurar Hostname${endColour}"
	echo -e "\n${yellowColour} ¿Desea configurar un hostname? (y/n): ${endColour}"; read config_host
	if [ "$config_host" == "y" ]; then
		echo -e "\n${grayColour}Ingrese un nombre para identificar a este servidor${endColour}"
		echo -e "\n${blueColour}(por ejemplo: myserver) ${endColour}"; read host_name
		echo $host_name > /etc/hostname
		hostname -F /etc/hostname
	fi
	say_done
}

# 2. Configurar zona horaria
function set_hour() {
    write_title "2. Configuración de la zona horaria"
    dpkg-reconfigure tzdata
    say_done
}


function sysupdate() {
    write_title "3. Actualización del sistema"
    apt update && apt upgrade -y
    say_done
}


# 5. Tunnear el archivo .bashrc
function tunning_bashrc() {
    write_title "19. Reemplazar .bashrc"
    cp templates/bashrc-root /root/.bashrc
    cp templates/bashrc-user /home/$username/.bashrc
    chown $username:$username /home/$username/.bashrc
    cp templates/bashrc-user /etc/skel/.bashrc
	echo 'alias ..="cd .."' >> /home/$username/.bashrc
	echo 'alias ls -la="lsa"' >> /home/$username/.bashrc
    say_done
}


# 10. Instalar ModEvasive
function install_modevasive() {
    write_title "16. Instalar ModEvasive"
    echo -n " Indique e-mail para recibir alertas: "; read inbox
    
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

# 8. Instalar OWASP para ModSecuity
function install_owasp_core_rule_set() {
    write_title "14. Instalar OWASP ModSecurity Core Rule Set"
    
    write_title "14.2 Clonar repositorio"
    mkdir /etc/apache2/modsecurity.d
    git clone https://github.com/SpiderLabs/owasp-modsecurity-crs /etc/apache2/modsecurity.d
    
    write_title "14.3 Mover archivo de configuración"
    mv /etc/apache2/modsecurity.d/crs-setup.conf.example /etc/apache2/modsecurity.d/crs-setup.conf
    
    write_title "14.4 Renombrar reglas de pre y post ejecución"
    mv /etc/apache2/modsecurity.d/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example \
        /etc/apache2/modsecurity.d/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
    mv /etc/apache2/modsecurity.d/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example \
        /etc/apache2/modsecurity.d/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
    
    write_title "14.4 Reemplazar configuración del módulo"
    cp templates/security2 /etc/apache2/mods-available/security2.conf 
    

    modsecrec="/etc/modsecurity/modsecurity.conf"
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


# Install mysql-server 
function install_mysql-server() {
    write_title "Instalación de mysql-server"
	apt install default-mysql-server -y
	mysql_secure_installation
    say_done
}


# Set Bind address 
function set_mysql_bind_address() {
    write_title "Modificamos el valor de bind address"
	cat templates/mysql_bind_address > /etc/mysql/mariadb.conf.d/50-server.cnf
    say_done
}


function create_database() {
    write_title "Creación de una base de datos"
    echo -n " Indique un nombre para la base de datos: "; read db_name
	mysql -e "CREATE DATABASE ${db_name};" 
	say_done
}


function create_user_mysql() {
    write_title "Creación del usuario"
    echo -n " Indique el nombre de usuario para la base de datos: "; read username
    echo -n " Indique contraseña para el usuario ${username}: "; read passwd

	mysql -e "CREATE USER '${username}'@'%' IDENTIFIED BY '${passwd}';" 
	mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${username}'@'%';"
	mysql -e "FLUSH PRIVILEGES;"
	say_done
}


function define_ufw_rules() {
    write_title "Instalar ufw"
	apt install ufw
    write_title "Definir las reglas para ufw"
    write_title "Habilitar ufw"
	ufw enable
    write_title "Permitir conexiones ssh"
	ufw allow ssh 
    write_title "Permitir conexiones del servidor donde tenemos alojada la app"
    echo  " Indique la IP del servidor donde esta alojada la APP "; read app_server_ip
	ufw allow from $app_server_ip to any port 3306
	ufw status
	say_done
}


function final_step() {
    write_title "Finalizar deploy"
	cat templates/texts/bye
    reboot
}


set_pause_on
is_root_use
set_hostna
set_hour 
sysupdate
tunning_bashrc
install_owasp_core_rule_set
install_modevasive
install_vim
install_mysql-server
set_mysql_bind_address 
create_database
create_user_mysql
define_ufw_rules
final_step

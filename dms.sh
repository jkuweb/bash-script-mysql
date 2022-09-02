#!/bin/bash

source helpers.sh
declare -r optional_arg="$1"

export serverip=$(__get_ip)

# 0. Verificar si es usuario root o no
function is_root_user() {
	if [ echo whoami != "root" ]; then 
		echo "Permiso denegado."
		echo "Este programa solo puede ser ejecutado por el usuario root"
		exit
	else
		clear
		cat templates/texts/welcome
	fi
}

# 1. Configurar Hostname
function set_hostname() {
	write_title "1. Configurar Hostname"
	echo -n " ¿Desea configurar un hostname? (y/n): "; read config_host
	if [ "$config_host" == "y" ]; then
		echo " Ingrese un nombre para identificar a este servidor"
		echo -n " (por ejemplo: myserver) "; read host_name
		echo -n " ¿Cúal será el dominio principal? "; read domain_name
		echo $host_name > /etc/hostname
		hostname -F /etc/hostname
		echo "127.0.0.1    localhost.localdomain    localhost" >> /etc/hosts 
		echo "$serverip    $host_name.$domain_name  $host_name" >> /etc/hosts 
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

#  4. Crear un nuevo usuario con privilegios
function set_new_user() {
    write_title "4. Creación de un nuevo usuario"
    echo -n " Indique un nombre para el nuevo usuario: "; read username
    adduser $username
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
	apt install default-mysql-server -y
	mysql_secure_installation
}

function create_user_mysql() {
	mysql 
}

# 11. Instalar y tunear VIM
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

set_pause_on                    #  Configurar modo de pausa entre funciones
is_root_user                    #  0. Verificar si es usuario root o no
set_hostname                    #  1. Configurar Hostname
set_hour                        #  2. Configurar zona horaria
sysupdate
set_new_user                    #  4. Crear un nuevo usuario con privilegios
tunning_bashrc                  #  5. Tunnear el archivo .bashrc
install_owasp_core_rule_set
install_modevasive
install_vim
install_mysql-server

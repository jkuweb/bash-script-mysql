# :pushpin: bash-script-mysql 


:heavy_minus_sign:
                 This script is based on JackTheStripper

================================================================================<br>

    JackTheStripper v 3.0
    Official Version for deploy a Debian GNU/Linux server, version 9.x

    Developed by Eugenia Bahit <eugenia.bahit@laeci.org>
    
    Copyright © 2013-2018 Eugenia Bahit <eugenia.bahit@laeci.org>
    License: GNU GPL version 3  <http://gnu.org/licenses/gpl.html>.
    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.
    
    The dms.sh file was migrated from JackTheStripper v 2.7 in collaboration w/
    Marcos Leal Sierra <https://www.linkedin.com/in/marcos-leal-sierra/>
================================================================================
## Description
Script to install mysql on a server<br>

    git clone https://github.com/jkuweb/bash-script-mysql.git
    cd bash-script-mysql
    chmod +x dms.sh
    ./dms.sh


## Defined functions
1. **set_pause_on**
2. **is_root_user**
3. **set_hostname**
4. **set_hour**
5. **sysupdate**
6. **tunning_bashrc**
7. **install_owasp_core_rule_set**
8. **install_modevasive**
9. **install_vim**
10. **install_mysql-server**
11. **set_mysql_bind_address**
12. **create_database**
13. **create_user_database**
14. **define_ufw_rules**
15. **final_step**

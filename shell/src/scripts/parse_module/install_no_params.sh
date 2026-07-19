#!/usr/bin/env bash

source "${CAINIAOTOOL_ROOT}/lib/logging.sh"

check_firewall() {
    if [ ! -e ~/.oneinstack ]; then
        while true; do
            echo
            read -e -p "Do you want to enable firewall? [y/n]: " firewall_flag
            if [[ ${firewall_flag} =~ ^[y,n]$ ]]; then
                break
            fi
            echo -e "${C_WARNING} input error! Please only input 'y' or 'n'${C_END}"
        done
    fi
}

choice_web_server() {
    while :; do
        echo
        read -e -p "Do you want to install Web server? [y/n]: " web_flag
        if [[ ! ${web_flag} =~ ^[y,n]$ ]]; then
            echo -e "${C_WARNING}input error! Please only input 'y' or 'n'${C_END}"
        else
            if [ "${web_flag}" == 'y' ]; then
                while :; do
                    echo
                    echo 'Please select Web server type:'
                    echo -e "${C_MSG}\t1${C_END}. Install Nginx"
                    echo -e "${C_MSG}\t4${C_END}. Install Caddy"
                    echo -e "${C_MSG}\t5${C_END}. Do not install"
                    read -e -p "Please input a number:(Default 1 press Enter) " nginx_option
                    nginx_option=${nginx_option:-1}
                    if [[ ! ${nginx_option} =~ ^[1-5]$ ]]; then
                        echo -e "${C_WARNING}input error! Please only input number 1~5${C_END}"
                    else
                        [ "${nginx_option}" != '5' -a -e "${nginx_install_dir}/sbin/nginx" ] && {
                            echo -e "${C_WARNING}Nginx already installed!${C_END}"
                            unset nginx_option
                        }
                        [ "${nginx_option}" != '5' -a -e "${caddy_install_dir}/bin/caddy" ] && {
                            echo -e "${C_WARNING}Caddy already installed!${C_END}"
                            unset nginx_option
                        }
                        break
                    fi
                done
                if [[ ${nginx_option} =~ ^[1-3]$ ]]; then
                    # Apache
                    while :; do
                        echo
                        read -e -p "Do you want to install Apache? [y/n]: " apache_flag
                        if [[ ! ${apache_flag} =~ ^[y,n]$ ]]; then
                            echo "${C_WARNING}input error! Please only input 'y' or 'n'${C_END}"
                        else
                            [ "${apache_flag}" == 'y' -a -e "${apache_install_dir}/bin/httpd" ] && {
                                echo "${C_WARNING}Aapche already installed! ${C_END}"
                                unset apache_flag
                            }
                            break
                        fi
                    done
                    # Apache2.4 mode and Apache2.4 MPM
                    if [ "${apache_flag}" == 'y' -o -e "${apache_install_dir}/bin/httpd" ]; then
                        while :; do
                            echo
                            echo 'Please select Apache mode:'
                            echo -e "\t${C_MSG}1${C_END}. php-fpm"
                            echo -e "\t${C_MSG}2${C_END}. mod_php"
                            read -e -p "Please input a number:(Default 1 press Enter) " apache_mode_option
                            apache_mode_option=${apache_mode_option:-1}
                            if [[ ! ${apache_mode_option} =~ ^[1-2]$ ]]; then
                                echo "${C_WARNING}input error! Please only input number 1~2${C_END}"
                            else
                                break
                            fi
                        done
                        while :; do
                            echo
                            echo 'Please select Apache MPM:'
                            echo -e "\t${C_MSG}1${C_END}. event"
                            echo -e "\t${C_MSG}2${C_END}. prefork"
                            echo -e "\t${C_MSG}3${C_END}. worker"
                            read -e -p "Please input a number:(Default 1 press Enter) " apache_mpm_option
                            apache_mpm_option=${apache_mpm_option:-1}
                            if [[ ! ${apache_mpm_option} =~ ^[1-3]$ ]]; then
                                echo "${C_WARNING}input error! Please only input number 1~3${C_END}"
                            else
                                break
                            fi
                        done
                    fi
                    # Tomcat
                    while :; do
                        echo
                        echo 'Please select tomcat server:'
                        echo -e "\t${C_MSG}1${C_END}. Install Tomcat-11"
                        echo -e "\t${C_MSG}2${C_END}. Install Tomcat-10"
                        echo -e "\t${C_MSG}7${C_END}. Do not install"
                        read -e -p "Please input a number:(Default 7 press Enter) " tomcat_option
                        tomcat_option=${tomcat_option:-7}
                        if [[ ! ${tomcat_option} =~ ^[1-7]$ ]]; then
                            echo "${C_WARNING}input error! Please only input number 1~7${C_END}"
                        else
                            [ "${tomcat_option}" != '7' -a -e "$tomcat_install_dir/conf/server.xml" ] && {
                                echo "${C_WARNING}Tomcat already installed! ${C_END}"
                                unset tomcat_option
                            }
                            if [[ "${tomcat_option}" =~ ^1$ ]]; then
                                while :; do
                                    echo
                                    echo 'Please select JDK version:'
                                    echo -e "\t${C_MSG}1${C_END}. Install openjdk-8-jdk"
                                    echo -e "\t${C_MSG}2${C_END}. Install openjdk-11-jdk"
                                    echo -e "\t${C_MSG}3${C_END}. Install openjdk-17-jdk"
                                    echo -e "\t${C_MSG}4${C_END}. Install openjdk-18-jdk"
                                    read -e -p "Please input a number:(Default 1 press Enter) " jdk_option
                                    jdk_option=${jdk_option:-1}
                                    if [[ ! ${jdk_option} =~ ^[1-4]$ ]]; then
                                        echo "${C_WARNING}input error! Please only input number 1~4${C_END}"
                                    else
                                        break
                                    fi
                                done
                            elif [[ "${tomcat_option}" =~ ^[2-3]$ ]]; then
                                while :; do
                                    echo
                                    echo 'Please select JDK version:'
                                    echo -e "\t${C_MSG}1${C_END}. Install openjdk-8-jdk"
                                    echo -e "\t${C_MSG}2${C_END}. Install openjdk-11-jdk"
                                    echo -e "\t${C_MSG}3${C_END}. Install openjdk-17-jdk"
                                    read -e -p "Please input a number:(Default 1 press Enter) " jdk_option
                                    jdk_option=${jdk_option:-1}
                                    if [[ ! ${jdk_option} =~ ^[1-3]$ ]]; then
                                        echo "${C_WARNING}input error! Please only input number 1~3${C_END}"
                                    else
                                        break
                                    fi
                                done
                            fi
                            break
                        fi
                    done
                elif [ "${nginx_option}" == '4' ]; then
                    # Caddy
                    while :; do
                        echo
                        read -e -p "Do you want to install Caddy? [y/n]: " caddy_flag
                        if [[ ! ${caddy_flag} =~ ^[y,n]$ ]]; then
                            echo "${C_WARNING}input error! Please only input 'y' or 'n'${C_END}"
                        else
                            [ "${caddy_flag}" == 'y' -a -e "${caddy_install_dir}/bin/caddy" ] && {
                                echo "${C_WARNING}Caddy already installed! ${C_END}"
                                unset caddy_flag
                            }
                            break
                        fi
                    done
                fi
            fi
            break
        fi
    done
}

choice_database() {
    while :; do
        echo
        read -e -p "Do you want to install Database? [y/n]: " db_flag
        if [[ ! ${db_flag} =~ ^[y,n]$ ]]; then
            echo "${C_WARNING}input error! Please only input 'y' or 'n'${C_END}"
        else
            if [ "${db_flag}" == 'y' ]; then
                while :; do
                    echo
                    echo 'Please select a version of the Database:'
                    echo -e "\t${C_MSG} 0${C_END}. Install MySQL-8.4 (LTS)"
                    echo -e "\t${C_MSG} 5${C_END}. Install MariaDB-10.11"
                    echo -e "\t${C_MSG} 9${C_END}. Install Percona-8.0"
                    echo -e "\t${C_MSG}13${C_END}. Install PostgreSQL"
                    echo -e "\t${C_MSG}14${C_END}. Install MongoDB"
                    read -e -p "Please input a number:(Default 0 press Enter) " db_option
                    db_option=${db_option:-0}
                    if [[ "${db_option}" =~ ^[0-9]$|^1[0-4]$ ]]; then
                        if [ "${db_option}" == '13' ]; then
                            [ -e "${pgsql_install_dir}/bin/psql" ] && {
                                echo "${C_WARNING}PostgreSQL already installed! ${C_END}"
                                unset db_option
                                break
                            }
                        elif [ "${db_option}" == '14' ]; then
                            [ -e "${mongo_install_dir}/bin/mongo" ] && {
                                echo "${C_WARNING}MongoDB already installed! ${C_END}"
                                unset db_option
                                break
                            }
                        else
                            [ -d "${mysql_install_dir}/support-files" ] && {
                                echo "${C_WARNING}MySQL already installed! ${C_END}"
                                unset db_option
                                break
                            }
                        fi
                        while :; do
                            if [ "${db_option}" == '13' ]; then
                                read -e -p "Please input the postgres password of PostgreSQL(default: ${dbpostgrespwd}): " dbpwd
                                dbpwd=${dbpwd:-${dbpostgrespwd}}
                            elif [ "${db_option}" == '14' ]; then
                                read -e -p "Please input the root password of MongoDB(default: ${dbmongopwd}): " dbpwd
                                dbpwd=${dbpwd:-${dbmongopwd}}
                            else
                                read -e -p "Please input the root password of MySQL(default: ${dbrootpwd}): " dbpwd
                                dbpwd=${dbpwd:-${dbrootpwd}}
                            fi
                            [ -n "$(echo ${dbpwd} | grep '[+|&]')" ] && {
                                echo "${C_WARNING}input error,not contain a plus sign (+) and & ${C_END}"
                                continue
                            }
                            if ((${#dbpwd} >= 5)); then
                                if [ "${db_option}" == '13' ]; then
                                    dbpostgrespwd=${dbpwd}
                                elif [ "${db_option}" == '14' ]; then
                                    dbmongopwd=${dbpwd}
                                else
                                    dbrootpwd=${dbpwd}
                                fi
                                break
                            else
                                echo "${C_WARNING}password least 5 characters! ${C_END}"
                            fi
                        done
                        # choose install methods
                        if [[ "${db_option}" =~ ^[0-9]$|^1[0-4]$ ]]; then
                            while :; do
                                echo
                                echo "Please choose installation of the database:"
                                echo -e "\t${C_MSG}1${C_END}. Install database from binary package."
                                echo -e "\t${C_MSG}2${C_END}. Install database from source package."
                                read -e -p "Please input a number:(Default 1 press Enter) " dbinstallmethod
                                dbinstallmethod=${dbinstallmethod:-1}
                                if [[ ! ${dbinstallmethod} =~ ^[1-2]$ ]]; then
                                    echo "${C_WARNING}input error! Please only input number 1~2${C_END}"
                                else
                                    break
                                fi
                            done
                        fi
                        break
                    else
                        echo "${C_WARNING}input error! Please only input number 1~14${C_END}"
                    fi
                done
            fi
            break
        fi
    done

}

choice_php() {
    while :; do
        echo
        read -e -p "Do you want to install PHP? [y/n]: " php_flag
        if [[ ! ${php_flag} =~ ^[y,n]$ ]]; then
            echo "${C_WARNING}input error! Please only input 'y' or 'n'${C_END}"
        else
            if [ "${php_flag}" == 'y' ]; then
                [ -e "${php_install_dir}/bin/phpize" ] && {
                    echo "${C_WARNING}PHP already installed! ${C_END}"
                    unset php_option
                    break
                }
                while :; do
                    echo
                    echo 'Please select a version of the PHP:'
                    echo -e "\t${C_MSG} 1${C_END}. Install php-5.3"
                    echo -e "\t${C_MSG} 2${C_END}. Install php-5.4"
                    echo -e "\t${C_MSG} 3${C_END}. Install php-5.5"
                    echo -e "\t${C_MSG} 4${C_END}. Install php-5.6"
                    echo -e "\t${C_MSG} 5${C_END}. Install php-7.0"
                    echo -e "\t${C_MSG} 6${C_END}. Install php-7.1"
                    echo -e "\t${C_MSG} 7${C_END}. Install php-7.2"
                    echo -e "\t${C_MSG} 8${C_END}. Install php-7.3"
                    echo -e "\t${C_MSG} 9${C_END}. Install php-7.4"
                    echo -e "\t${C_MSG}10${C_END}. Install php-8.0"
                    echo -e "\t${C_MSG}11${C_END}. Install php-8.1"
                    echo -e "\t${C_MSG}12${C_END}. Install php-8.2"
                    echo -e "\t${C_MSG}13${C_END}. Install php-8.3"
                    echo -e "\t${C_MSG}14${C_END}. Install php-8.4"
                    echo -e "\t${C_MSG}15${C_END}. Install php-8.5"
                    read -e -p "Please input a number:(Default 15 press Enter) " php_option
                    php_option=${php_option:-15}
                    if [[ ! ${php_option} =~ ^[1-9]$|^1[0-5]$ ]]; then
                        echo "${C_WARNING}input error! Please only input number 1~14${C_END}"
                    else
                        break
                    fi
                done
            else
                php_option=""
            fi
            break
        fi
    done
}

php_opcode_cache_and_extensions() {
    if [ -e "${php_install_dir}/bin/phpize" ]; then
        PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
        PHP_main_ver=${PHP_detail_ver%.*}
    fi

    # PHP opcode cache and extensions
    if [[ ${php_option} =~ ^[1-9]$|^1[0-3]$ ]] || [ -e "${php_install_dir}/bin/phpize" ]; then
        while :; do
            echo
            read -e -p "Do you want to install opcode cache of the PHP? [y/n]: " phpcache_flag
            if [[ ! ${phpcache_flag} =~ ^[y,n]$ ]]; then
                echo "${C_WARNING}input error! Please only input 'y' or 'n'${C_END}"
            else
                if [ "${phpcache_flag}" == 'y' ]; then
                    if [[ ${php_option} =~ ^[5-9]$|^1[0-4]$ ]] || [[ "${PHP_main_ver}" =~ ^7.[0-4]$|^8.[0-4]$ ]]; then
                        while :; do
                            echo 'Please select a opcode cache of the PHP:'
                            echo -e "\t${C_MSG}1${C_END}. Install Zend OPcache"
                            echo -e "\t${C_MSG}2${C_END}. Install APCU"
                            read -e -p "Please input a number:(Default 1 press Enter) " phpcache_option
                            phpcache_option=${phpcache_option:-1}
                            if [[ ! ${phpcache_option} =~ ^[1-2]$ ]]; then
                                echo "${C_WARNING}input error! Please only input number 1~2${C_END}"
                            else
                                break
                            fi
                        done
                    fi
                fi
                break
            fi
        done

        # PHP extension
        while :; do
            echo
            echo 'Please select PHP extensions:'
            echo -e "\t${C_MSG} 0${C_END}. Do not install"
            echo -e "\t${C_MSG} 1${C_END}. Install zendguardloader(PHP<=5.6)"
            echo -e "\t${C_MSG} 2${C_END}. Install ioncube"
            echo -e "\t${C_MSG} 3${C_END}. Install sourceguardian(PHP<=7.2)"
            echo -e "\t${C_MSG} 4${C_END}. Install imagick"
            echo -e "\t${C_MSG} 5${C_END}. Install gmagick"
            echo -e "\t${C_MSG} 6${C_END}. Install fileinfo"
            echo -e "\t${C_MSG} 7${C_END}. Install imap"
            echo -e "\t${C_MSG} 8${C_END}. Install ldap"
            echo -e "\t${C_MSG} 9${C_END}. Install phalcon(PHP>=5.5)"
            echo -e "\t${C_MSG}10${C_END}. Install yaf(PHP>=7.0)"
            echo -e "\t${C_MSG}11${C_END}. Install redis"
            echo -e "\t${C_MSG}12${C_END}. Install memcached"
            echo -e "\t${C_MSG}13${C_END}. Install memcache"
            echo -e "\t${C_MSG}14${C_END}. Install mongodb"
            echo -e "\t${C_MSG}15${C_END}. Install swoole"
            echo -e "\t${C_MSG}16${C_END}. Install xdebug(PHP>=5.5)"
            read -e -p "Please input numbers:(Default '4 11 12' press Enter) " phpext_option
            phpext_option=${phpext_option:-'4 11 12'}
            [ "${phpext_option}" == '0' ] && break
            array_phpext=(${phpext_option})
            array_all=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)
            for v in "${array_phpext[@]}"; do
                [ -z "$(echo "${array_all[@]}" | grep -w ${v})" ] && phpext_flag=1
            done
            if [ "${phpext_flag:-}" == '1' ]; then
                unset phpext_flag
                echo
                echo "${C_WARNING}input error! Please only input number 4 11 12 and so on${C_END}"
                echo
                continue
            else
                [ -n "$(echo "${array_phpext[@]}" | grep -w 1)" ] && pecl_zendguardloader=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 2)" ] && pecl_ioncube=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 3)" ] && pecl_sourceguardian=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 4)" ] && pecl_imagick=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 5)" ] && pecl_gmagick=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 6)" ] && pecl_fileinfo=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 7)" ] && pecl_imap=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 8)" ] && pecl_ldap=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 9)" ] && pecl_phalcon=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 10)" ] && pecl_yaf=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 11)" ] && pecl_redis=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 12)" ] && pecl_memcached=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 13)" ] && pecl_memcache=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 14)" ] && pecl_mongodb=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 15)" ] && pecl_swoole=1
                [ -n "$(echo "${array_phpext[@]}" | grep -w 16)" ] && pecl_xdebug=1
                break
            fi
        done
    fi
}

choice_nodejs() {
    while :; do
        echo
        read -e -p "Do you want to install Nodejs? [y/n]: " nodejs_flag
        if [[ ! ${nodejs_flag} =~ ^[y,n]$ ]]; then
            echo "${C_WARNING}input error! Please only input 'y' or 'n'${C_END}"
        else
            [ "${nodejs_flag}" == 'y' -a -e "${nodejs_install_dir}/bin/node" ] && {
                echo "${C_WARNING}Nodejs already installed! ${C_END}"
                unset nodejs_flag
            }
            break
        fi
    done
}

choice_pureftpd() {
    while :; do
        echo
        read -e -p "Do you want to install Pure-FTPd? [y/n]: " pureftpd_flag
        if [[ ! ${pureftpd_flag} =~ ^[y,n]$ ]]; then
            echo "${C_WARNING}input error! Please only input 'y' or 'n'${C_END}"
        else
            [ "${pureftpd_flag}" == 'y' -a -e "${pureftpd_install_dir}/sbin/pure-ftpwho" ] && {
                echo "${C_WARNING}Pure-FTPd already installed! ${C_END}"
                unset pureftpd_flag
            }
            break
        fi
    done
}

choice_phpmyadmin() {
    if [[ ${php_option} =~ ^[1-9]$|^1[0-3]$ ]] || [ -e "${php_install_dir}/bin/phpize" ]; then
        while :; do
            echo
            read -e -p "Do you want to install phpMyAdmin? [y/n]: " phpmyadmin_flag
            if [[ ! ${phpmyadmin_flag} =~ ^[y,n]$ ]]; then
                echo "${C_WARNING}input error! Please only input 'y' or 'n'${C_END}"
            else
                [ "${phpmyadmin_flag}" == 'y' -a -d "${wwwroot_dir}/default/phpMyAdmin" ] && {
                    echo "${C_WARNING}phpMyAdmin already installed! ${C_END}"
                    unset phpmyadmin_flag
                }
                break
            fi
        done
    fi
}

choice_redis() {
    while :; do
        echo
        read -e -p "Do you want to install redis-server? [y/n]: " redis_flag
        if [[ ! ${redis_flag} =~ ^[y,n]$ ]]; then
            echo "${C_WARNING}input error! Please only input 'y' or 'n'${C_END}"
        else
            [ "${redis_flag}" == 'y' -a -e "${redis_install_dir}/bin/redis-server" ] && {
                echo "${C_WARNING}redis-server already installed! ${C_END}"
                unset redis_flag
            }
            break
        fi
    done
}

choice_memcached() {
    while :; do
        echo
        read -e -p "Do you want to install memcached-server? [y/n]: " memcached_flag
        if [[ ! ${memcached_flag} =~ ^[y,n]$ ]]; then
            echo "${C_WARNING}input error! Please only input 'y' or 'n'${C_END}"
        else
            [ "${memcached_flag}" == 'y' -a -e "${memcached_install_dir}/bin/memcached" ] && {
                echo "${C_WARNING}memcached-server already installed! ${C_END}"
                unset memcached_flag
            }
            break
        fi
    done
}

insert_no_params() {
    if [[ "${1}" == "0" ]]; then
        check_firewall
        choice_web_server
        choice_database
        choice_php
        php_opcode_cache_and_extensions
        choice_nodejs
        choice_pureftpd
        choice_phpmyadmin
        choice_redis
        choice_memcached
    fi
}

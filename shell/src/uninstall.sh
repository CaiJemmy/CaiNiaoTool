#!/bin/bash

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
clear
printf "
#######################################################################
#       OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+      #
#                         Uninstall OneinStack                        #
#       For more information please visit https://oneinstack.com      #
#######################################################################
"
# Check if user is root
[ $(id -u) != "0" ] && {
    echo "Error: You must be root to run this script"
    exit 1
}

ARG_NUM=$#

CAINIAOTOOL_ROOT=$(dirname "$(readlink -f $0)")
pushd "${CAINIAOTOOL_ROOT}" >/dev/null || exit 0
source "${CAINIAOTOOL_ROOT}/options.conf"
source "${CAINIAOTOOL_ROOT}/lib/logging.sh"
source "${CAINIAOTOOL_ROOT}/include/get_char.sh"
source "${CAINIAOTOOL_ROOT}/include/check_dir.sh"

Show_Help() {
    echo
    echo "Usage: $0  command ...[parameters]....
  --help, -h                    Show this help message, More: https://oneinstack.com
  --quiet, -q                   quiet operation
  --all                         Uninstall All
  --web                         Uninstall Nginx/Tengine/OpenResty/Apache/Tomcat/Caddy
  --mysql                       Uninstall MySQL/MariaDB/Percona
  --postgresql                  Uninstall PostgreSQL
  --mongodb                     Uninstall MongoDB
  --php                         Uninstall PHP (PATH: ${php_install_dir})
  --mphp_ver [53~83]            Uninstall another PHP version (PATH: ${php_install_dir}\${mphp_ver})
  --allphp                      Uninstall all PHP
  --phpcache                    Uninstall PHP opcode cache
  --php_extensions [ext name]   Uninstall PHP extensions, include zendguardloader,ioncube,
                                sourceguardian,imagick,gmagick,fileinfo,imap,ldap,calendar,phalcon,
                                yaf,yar,redis,memcached,memcache,mongodb,swoole,xdebug
  --pureftpd                    Uninstall PureFtpd
  --redis                       Uninstall Redis-server
  --memcached                   Uninstall Memcached-server
  --phpmyadmin                  Uninstall phpMyAdmin
  --nodejs                      Uninstall Nodejs (PATH: ${nodejs_install_dir})
  "
}

TEMP=$(getopt -o hvVq --long help,version,quiet,all,web,mysql,postgresql,mongodb,php,mphp_ver:,allphp,phpcache,php_extensions:,pureftpd,redis,memcached,phpmyadmin,nodejs -- "$@" 2>/dev/null)
[ $? != 0 ] && echo "${CWARNING}ERROR: unknown argument! ${CEND}" && Show_Help && exit 1
eval set -- "${TEMP}"
while :; do
    [ -z "$1" ] && break
    case "$1" in
    -h | --help)
        Show_Help
        exit 0
        ;;
    -q | --quiet)
        quiet_flag=y
        uninstall_flag=y
        shift 1
        ;;
    --all)
        all_flag=y
        web_flag=y
        mysql_flag=y
        postgresql_flag=y
        mongodb_flag=y
        allphp_flag=y
        nodejs_flag=y
        pureftpd_flag=y
        redis_flag=y
        memcached_flag=y
        phpmyadmin_flag=y
        shift 1
        ;;
    --web)
        web_flag=y
        shift 1
        ;;
    --mysql)
        mysql_flag=y
        shift 1
        ;;
    --postgresql)
        postgresql_flag=y
        shift 1
        ;;
    --mongodb)
        mongodb_flag=y
        shift 1
        ;;
    --php)
        php_flag=y
        shift 1
        ;;
    --mphp_ver)
        mphp_ver=$2
        mphp_flag=y
        shift 2
        [[ ! "${mphp_ver}" =~ ^5[3-6]$|^7[0-4]$|^8[0-1]$ ]] && {
            echo "${CWARNING}mphp_ver input error! Please only input number 53~81${CEND}"
            exit 1
        }
        ;;
    --allphp)
        allphp_flag=y
        shift 1
        ;;
    --phpcache)
        phpcache_flag=y
        shift 1
        ;;
    --php_extensions)
        php_extensions=$2
        shift 2
        [ -n "$(echo ${php_extensions} | grep -w zendguardloader)" ] && pecl_zendguardloader=1
        [ -n "$(echo ${php_extensions} | grep -w ioncube)" ] && pecl_ioncube=1
        [ -n "$(echo ${php_extensions} | grep -w sourceguardian)" ] && pecl_sourceguardian=1
        [ -n "$(echo ${php_extensions} | grep -w imagick)" ] && pecl_imagick=1
        [ -n "$(echo ${php_extensions} | grep -w gmagick)" ] && pecl_gmagick=1
        [ -n "$(echo ${php_extensions} | grep -w fileinfo)" ] && pecl_fileinfo=1
        [ -n "$(echo ${php_extensions} | grep -w imap)" ] && pecl_imap=1
        [ -n "$(echo ${php_extensions} | grep -w ldap)" ] && pecl_ldap=1
        [ -n "$(echo ${php_extensions} | grep -w calendar)" ] && pecl_calendar=1
        [ -n "$(echo ${php_extensions} | grep -w phalcon)" ] && pecl_phalcon=1
        [ -n "$(echo ${php_extensions} | grep -w yaf)" ] && pecl_yaf=1
        [ -n "$(echo ${php_extensions} | grep -w yar)" ] && pecl_yar=1
        [ -n "$(echo ${php_extensions} | grep -w redis)" ] && pecl_redis=1
        [ -n "$(echo ${php_extensions} | grep -w memcached)" ] && pecl_memcached=1
        [ -n "$(echo ${php_extensions} | grep -w memcache)" ] && pecl_memcache=1
        [ -n "$(echo ${php_extensions} | grep -w mongodb)" ] && pecl_mongodb=1
        [ -n "$(echo ${php_extensions} | grep -w swoole)" ] && pecl_swoole=1
        [ -n "$(echo ${php_extensions} | grep -w xdebug)" ] && pecl_xdebug=1
        ;;
    --nodejs)
        nodejs_flag=y
        shift 1
        ;;
    --pureftpd)
        pureftpd_flag=y
        shift 1
        ;;
    --redis)
        redis_flag=y
        shift 1
        ;;
    --memcached)
        memcached_flag=y
        shift 1
        ;;
    --phpmyadmin)
        phpmyadmin_flag=y
        shift 1
        ;;
    --)
        shift
        ;;
    *)
        echo "${CWARNING}ERROR: unknown argument! ${CEND}" && Show_Help && exit 1
        ;;
    esac
done

uninstall_status() {
    if [ "${quiet_flag}" != 'y' ]; then
        while :; do
            echo
            read -e -p "Do you want to uninstall? [y/n]: " uninstall_flag
            if [[ ! ${uninstall_flag} =~ ^[y,n]$ ]]; then
                log_error "input error! Please only input 'y' or 'n'"
            else
                break
            fi
        done
    fi
}

print_warn() {
    echo
    log_warn "You will uninstall OneinStack, Please backup your configure files and DB data!"
}

print_web() {
    [ -d "${nginx_install_dir}" ] && echo ${nginx_install_dir}
    [ -d "${tengine_install_dir}" ] && echo ${tengine_install_dir}
    [ -d "${openresty_install_dir}" ] && echo ${openresty_install_dir}
    [ -e "/etc/init.d/nginx" ] && echo /etc/init.d/nginx
    [ -e "/lib/systemd/system/nginx.service" ] && echo /lib/systemd/system/nginx.service
    [ -e "/etc/logrotate.d/nginx" ] && echo /etc/logrotate.d/nginx

    [ -d "${caddy_install_dir}" ] && echo ${caddy_install_dir}
    [ -e "/lib/systemd/system/caddy.service" ] && echo /lib/systemd/system/caddy.service

    [ -d "${apache_install_dir}" ] && echo ${apache_install_dir}
    [ -e "/lib/systemd/system/httpd.service" ] && echo /lib/systemd/system/httpd.service
    [ -e "/etc/init.d/httpd" ] && echo /etc/init.d/httpd
    [ -e "/etc/logrotate.d/apache" ] && echo /etc/logrotate.d/apache

    [ -d "${tomcat_install_dir}" ] && echo ${tomcat_install_dir}
    [ -e "/etc/init.d/tomcat" ] && echo /etc/init.d/tomcat
    [ -e "/etc/logrotate.d/tomcat" ] && echo /etc/logrotate.d/tomcat
    [ -d "/usr/java" ] && echo /usr/java
    [ -d "${apr_install_dir}" ] && echo ${apr_install_dir}
}

uninstall_web() {
    [ -d "${nginx_install_dir}" ] && {
        killall nginx >/dev/null 2>&1
        rm -rf ${nginx_install_dir} /etc/init.d/nginx /etc/logrotate.d/nginx
        sed -i "s@${nginx_install_dir}/sbin:@@" /etc/profile
        echo "${CMSG}Nginx uninstall completed! ${CEND}"
    }
    [ -d "${tengine_install_dir}" ] && {
        killall nginx >/dev/null 2>&1
        rm -rf ${tengine_install_dir} /etc/init.d/nginx /etc/logrotate.d/nginx
        sed -i "s@${tengine_install_dir}/sbin:@@" /etc/profile
        echo "${CMSG}Tengine uninstall completed! ${CEND}"
    }
    [ -d "${openresty_install_dir}" ] && {
        killall nginx >/dev/null 2>&1
        rm -rf ${openresty_install_dir} /etc/init.d/nginx /etc/logrotate.d/nginx
        sed -i "s@${openresty_install_dir}/nginx/sbin:@@" /etc/profile
        echo "${CMSG}OpenResty uninstall completed! ${CEND}"
    }
    [ -d "${caddy_install_dir}" ] && {
        killall caddy >/dev/null 2>&1
        rm -rf ${caddy_install_dir} /etc/init.d/caddy /etc/logrotate.d/caddy
        sed -i "s@${caddy_install_dir}/bin:@@" /etc/profile
        echo "${CMSG}Caddy uninstall completed! ${CEND}"
    }
    [ -e "/lib/systemd/system/nginx.service" ] && {
        systemctl disable nginx >/dev/null 2>&1
        rm -f /lib/systemd/system/nginx.service
    }
    [ -e "/lib/systemd/system/caddy.service" ] && {
        systemctl disable caddy >/dev/null 2>&1
        rm -f /lib/systemd/system/caddy.service
    }
    [ -d "${apache_install_dir}" ] && {
        service httpd stop >/dev/null 2>&1
        rm -rf ${apache_install_dir} /etc/init.d/httpd /etc/logrotate.d/apache
        sed -i "s@${apache_install_dir}/bin:@@" /etc/profile
        echo "${CMSG}Apache uninstall completed! ${CEND}"
    }
    [ -e "/lib/systemd/system/httpd.service" ] && {
        systemctl disable httpd >/dev/null 2>&1
        rm -f /lib/systemd/system/httpd.service
    }
    [ -d "${tomcat_install_dir}" ] && {
        killall java >/dev/null 2>&1
        rm -rf ${tomcat_install_dir} /etc/init.d/tomcat /etc/logrotate.d/tomcat
        echo "${CMSG}Tomcat uninstall completed! ${CEND}"
    }
    [ -d "/usr/java" ] && {
        rm -rf /usr/java
        sed -i '/export JAVA_HOME=/d' /etc/profile
        sed -i '/export CLASSPATH=/d' /etc/profile
        sed -i 's@\$JAVA_HOME/bin:@@' /etc/profile
    }
    [ -e "${wwwroot_dir}" ] && /bin/mv ${wwwroot_dir}{,$(date +%Y%m%d%H)}
    sed -i 's@^website_name=.*@website_name=@' ./options.conf
    sed -i 's@^backup_content=.*@backup_content=@' ./options.conf
    [ -d "${apr_install_dir}" ] && rm -rf ${apr_install_dir}
}

print_MySQL() {
    [ -e "${db_install_dir}" ] && echo ${db_install_dir}
    [ -e "/etc/init.d/mysqld" ] && echo /etc/init.d/mysqld
    [ -e "/etc/my.cnf" ] && echo /etc/my.cnf
}

uninstall_MySQL() {
    # uninstall mysql,mariadb,percona
    if [ -d "${db_install_dir}/support-files" ]; then
        service mysqld stop >/dev/null 2>&1
        rm -rf ${db_install_dir} /etc/init.d/mysqld /etc/my.cnf* /etc/ld.so.conf.d/*{mysql,mariadb,percona}*.conf
        id -u mysql >/dev/null 2>&1
        [ $? -eq 0 ] && userdel mysql
        [ -e "${db_data_dir}" ] && /bin/mv ${db_data_dir}{,$(date +%Y%m%d%H)}
        sed -i 's@^dbrootpwd=.*@dbrootpwd=@' ./options.conf
        sed -i "s@${db_install_dir}/bin:@@" /etc/profile
        echo "${CMSG}MySQL uninstall completed! ${CEND}"
    fi
}

print_allPHP() {
    [ -e "${php_install_dir}" ] && echo ${php_install_dir}
    [ -e "/lib/systemd/system/php-fpm.service" ] && echo /lib/systemd/system/php-fpm.service
    [ -e "${imagick_install_dir}" ] && echo ${imagick_install_dir}
    [ -e "${gmagick_install_dir}" ] && echo ${gmagick_install_dir}
    [ -e "${curl_install_dir}" ] && echo ${curl_install_dir}
}

uninstall_allPHP() {
    [ -e "/lib/systemd/system/php-fpm.service" ] && {
        systemctl stop php-fpm >/dev/null 2>&1
        systemctl disable php-fpm >/dev/null 2>&1
        rm -f /lib/systemd/system/php-fpm.service
    }
    [ -e "${apache_install_dir}/conf/httpd.conf" ] && [ -n "$(grep libphp ${apache_install_dir}/conf/httpd.conf)" ] && sed -i '/libphp/d' ${apache_install_dir}/conf/httpd.conf
    [ -e "${php_install_dir}" ] && {
        rm -rf ${php_install_dir}
        echo "${CMSG}PHP uninstall completed! ${CEND}"
    }
    sed -i "s@${php_install_dir}/bin:@@" /etc/profile
    [ -e "${imagick_install_dir}" ] && rm -rf ${imagick_install_dir}
    [ -e "${gmagick_install_dir}" ] && rm -rf ${gmagick_install_dir}
    [ -e "${curl_install_dir}" ] && rm -rf ${curl_install_dir}
}

uninstall_PHPextension() {
    # imagick
    if [ "${pecl_imagick}" == '1' ]; then
        . include/ImageMagick.sh
        Uninstall_ImageMagick
        Uninstall_pecl_imagick
    fi

    # gmagick
    if [ "${pecl_gmagick}" == '1' ]; then
        . include/GraphicsMagick.sh
        Uninstall_GraphicsMagick
        Uninstall_pecl_gmagick
    fi

    # ldap
    if [ "${pecl_ldap}" == '1' ]; then
        . include/pecl_ldap.sh
        Uninstall_pecl_ldap
    fi

    # yaf
    if [ "${pecl_yaf}" == '1' ]; then
        . include/pecl_yaf.sh
        Uninstall_pecl_yaf 2>&1 | tee -a ${oneinstack_dir}/install.log
    fi

    # yar
    if [ "${pecl_yar}" == '1' ]; then
        . include/pecl_yar.sh
        Uninstall_pecl_yar 2>&1 | tee -a ${oneinstack_dir}/install.log
    fi

    # pecl_redis
    if [ "${pecl_redis}" == '1' ]; then
        . include/redis.sh
        Uninstall_pecl_redis
    fi

    # swoole
    if [ "${pecl_swoole}" == '1' ]; then
        . include/pecl_swoole.sh
        Uninstall_pecl_swoole
    fi

    # xdebug
    if [ "${pecl_xdebug}" == '1' ]; then
        . include/pecl_xdebug.sh
        Uninstall_pecl_xdebug
    fi

    # reload php_module
    [ -e "${php_install_dir}/sbin/php-fpm" ] && { [ -e "/bin/systemctl" ] && systemctl reload php-fpm || service php-fpm reload; }
    [ -n "${mphp_ver}" -a -e "${php_install_dir}${mphp_ver}/sbin/php-fpm" ] && { [ -e "/bin/systemctl" ] && systemctl reload php${mphp_ver}-fpm || service php${mphp_ver}-fpm reload; }
    [ -e "${apache_install_dir}/bin/apachectl" ] && ${apache_install_dir}/bin/apachectl -k graceful
}

menu_PHPextension() {
    while :; do
        echo 'Please select uninstall PHP extensions:'
        echo -e "\t${CMSG} 0${CEND}. Do not uninstall"
        echo -e "\t${CMSG} 4${CEND}. Uninstall imagick"
        echo -e "\t${CMSG} 5${CEND}. Uninstall gmagick"
        echo -e "\t${CMSG} 8${CEND}. Uninstall ldap"
        echo -e "\t${CMSG} 8${CEND}. Uninstall yaf"
        echo -e "\t${CMSG} 8${CEND}. Uninstall yar"
        echo -e "\t${CMSG}10${CEND}. Uninstall redis"
        echo -e "\t${CMSG}14${CEND}. Uninstall swoole"
        echo -e "\t${CMSG}15${CEND}. Uninstall xdebug(PHP>=5.5)"
        read -e -p "Please input a number:(Default 0 press Enter) " phpext_option
        phpext_option=${phpext_option:-0}
        [ "${phpext_option}" == '0' ] && break
        array_phpext=(${phpext_option})
        array_all=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)
        for v in "${array_phpext[@]}"; do
            [ -z "$(echo "${array_all[@]}" | grep -w ${v})" ] && phpext_flag=1
        done
        if [ "${phpext_flag}" == '1' ]; then
            unset phpext_flag
            echo
            echo "${CWARNING}input error! Please only input number 1 2 3 14 and so on${CEND}"
            echo
            continue
        else
            [ -n "$(echo "${array_phpext[@]}" | grep -w 4)" ] && pecl_imagick=1
            [ -n "$(echo "${array_phpext[@]}" | grep -w 5)" ] && pecl_gmagick=1
            [ -n "$(echo "${array_phpext[@]}" | grep -w 8)" ] && pecl_ldap=1
            [ -n "$(echo "${array_phpext[@]}" | grep -w 8)" ] && pecl_yaf=1
            [ -n "$(echo "${array_phpext[@]}" | grep -w 8)" ] && pecl_yar=1
            [ -n "$(echo "${array_phpext[@]}" | grep -w 10)" ] && pecl_redis=1
            [ -n "$(echo "${array_phpext[@]}" | grep -w 14)" ] && pecl_swoole=1
            [ -n "$(echo "${array_phpext[@]}" | grep -w 15)" ] && pecl_xdebug=1
            break
        fi
    done
}

print_redis_server() {
    # 使用 apt 安装，无法指定redis 的安装目录，只能安装在默认目录下
    # /usr/bin/redis*
    # /etc/redis/redis.conf /etc/default/redis-server
    # /lib/systemd/system/redis-server.service /lib/systemd/system/redis-server@.service
    # /var/lib/redis/
    # /var/log/redis/
    # redis 用户组
    #
    [ -e "/usr/bin/redis-server" ] && echo "/usr/bin"
    [ -e "/lib/systemd/system/redis-server.service" ] && echo /lib/systemd/system/redis-server.service
}

uninstall_redis_server() {
    [ -e "/usr/bin/redis-server" ] && {
        systemctl stop redis-server >/dev/null 2>&1
        [ -e "/usr/bin/redis-check-aof" ] && rm -f "/usr/bin/redis-check-aof"
        [ -e "/usr/bin/redis-check-rdb" ] && rm -f "/usr/bin/redis-check-rdb"
        apt remove --purge redis-server redis-tools -y
        apt autoremove -y
        rm -rf /etc/redis /var/lib/redis /var/log/redis /etc/default/redis-server
        systemctl disable redis-server >/dev/null 2>&1
        rm -f /lib/systemd/system/redis-server.service /lib/systemd/system/redis-server@.service
        id -u redis >/dev/null 2>&1
        [ $? -eq 0 ] && userdel redis
        log_info "Redis uninstall completed!"
    }

    [ -e "/usr/bin/redis-benchmark" ] && rm -f "/usr/bin/redis-benchmark"
    [ -e "/usr/bin/redis-cli" ] && rm -f "/usr/bin/redis-cli"
}

print_phpMyAdmin() {
    [ -d "${wwwroot_dir}/default/phpMyAdmin" ] && echo ${wwwroot_dir}/default/phpMyAdmin
}

uninstall_phpMyAdmin() {
    [ -d "${wwwroot_dir}/default/phpMyAdmin" ] && rm -rf ${wwwroot_dir}/default/phpMyAdmin
}

print_openssl() {
    [ -d "${openssl_install_dir}" ] && echo ${openssl_install_dir}
}

uninstall_openssl() {
    [ -d "${openssl_install_dir}" ] && rm -rf ${openssl_install_dir}
}

print_nodejs() {
    [ -e "${nodejs_install_dir}" ] && echo ${nodejs_install_dir}
    [ -e "/etc/profile.d/nodejs.sh" ] && echo /etc/profile.d/nodejs.sh
}

uninstall_menu() {
    while :; do
        printf "
What Are You Doing?
\t${CMSG} 0${CEND}. Uninstall All
\t${CMSG} 1${CEND}. Uninstall Nginx/Tengine/OpenResty/Apache/Tomcat/Caddy
\t${CMSG} 2${CEND}. Uninstall MySQL/MariaDB/Percona
\t${CMSG} 5${CEND}. Uninstall all PHP
\t${CMSG} 7${CEND}. Uninstall PHP extensions
\t${CMSG} 9${CEND}. Uninstall Redis
\t${CMSG}11${CEND}. Uninstall phpMyAdmin
\t${CMSG}12${CEND}. Uninstall Nodejs (PATH: ${nodejs_install_dir})
\t${CMSG} q${CEND}. Exit
"
        echo
        read -e -p "Please input the correct option: " Number
        if [[ ! "${Number}" =~ ^[0-9,q]$|^1[0-3]$ ]]; then
            echo "${CWARNING}input error! Please only input 0~12 and q${CEND}"
        else
            case "$Number" in
            0)
                print_warn
                print_web
                print_MySQL
                print_allPHP
                print_redis_server
                print_openssl
                print_phpMyAdmin
                print_nodejs
                uninstall_status
                if [ "${uninstall_flag}" == 'y' ]; then
                    uninstall_web
                    uninstall_MySQL
                    uninstall_allPHP
                    uninstall_redis_server
                    uninstall_openssl
                    uninstall_phpMyAdmin
                    source "${CAINIAOTOOL_ROOT}/scripts/server_manager/nodejs.sh"
                    uninstall_nodejs
                else
                    exit
                fi
                ;;
            1)
                print_warn
                print_web
                uninstall_status
                [ "${uninstall_flag}" == 'y' ] && uninstall_web || exit
                ;;
            2)
                print_warn
                print_MySQL
                uninstall_status
                [ "${uninstall_flag}" == 'y' ] && uninstall_MySQL || exit
                ;;
            5)
                print_allPHP
                uninstall_status
                [ "${uninstall_flag}" == 'y' ] && uninstall_allPHP || exit
                ;;
            7)
                menu_PHPextension
                [ "${phpext_option}" != '0' ] && uninstall_status
                [ "${uninstall_flag}" == 'y' ] && uninstall_PHPextension || exit
                ;;
            9)
                print_redis_server
                uninstall_status
                [ "${uninstall_flag}" == 'y' ] && uninstall_redis_server || exit
                ;;
            11)
                print_phpMyAdmin
                uninstall_status
                [ "${uninstall_flag}" == 'y' ] && uninstall_phpMyAdmin || exit
                ;;
            12)
                print_nodejs
                uninstall_status
                [ "${uninstall_flag}" == 'y' ] && {
                    source "${CAINIAOTOOL_ROOT}/scripts/server_manager/nodejs.sh"
                    uninstall_nodejs
                } || exit
                ;;
            q)
                exit
                ;;
            esac
        fi
    done
}

main(){
if [ ${ARG_NUM} == 0 ]; then
    uninstall_menu
else
    [ "${web_flag}" == 'y' ] && print_web
    [ "${mysql_flag}" == 'y' ] && print_MySQL
    if [ "${allphp_flag}" == 'y' ]; then
        print_allPHP
    fi
    [ "${redis_flag}" == 'y' ] && print_redis_server
    [ "${phpmyadmin_flag}" == 'y' ] && print_phpMyAdmin
    [ "${nodejs_flag}" == 'y' ] && print_nodejs
    [ "${all_flag}" == 'y' ] && print_openssl
    uninstall_status
    if [ "${uninstall_flag}" == 'y' ]; then
        [ "${web_flag}" == 'y' ] && uninstall_web
        [ "${mysql_flag}" == 'y' ] && uninstall_MySQL
        if [ "${allphp_flag}" == 'y' ]; then
            uninstall_allPHP
        else
            [ -n "${php_extensions}" ] && uninstall_PHPextension
        fi
        [ "${redis_flag}" == 'y' ] && uninstall_redis_server
        [ "${phpmyadmin_flag}" == 'y' ] && uninstall_phpMyAdmin
        [ "${nodejs_flag}" == 'y' ] && {
            source "${CAINIAOTOOL_ROOT}/scripts/server_manager/nodejs.sh"
            uninstall_nodejs
        }
        [ "${all_flag}" == 'y' ] && uninstall_openssl
    fi
fi
}

main
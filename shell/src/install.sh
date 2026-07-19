#!/bin/bash

ARG_NUM=$#
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

CAINIAOTOOL_ROOT=$(dirname "$(readlink -f "$0")")

source "${CAINIAOTOOL_ROOT}/options.conf"

init_pwd() {
    dbrootpwd=$(</dev/urandom tr -dc A-Za-z0-9 | head -c8)
    dbpostgrespwd=$(</dev/urandom tr -dc A-Za-z0-9 | head -c8)
    dbmongopwd=$(</dev/urandom tr -dc A-Za-z0-9 | head -c8)
    xcachepwd=$(</dev/urandom tr -dc A-Za-z0-9 | head -c8)
    jmxremotepwd=$(</dev/urandom tr -dc A-Za-z0-9 | head -c8)
    phpMyAdminpwd=$(</dev/urandom tr -dc A-Za-z0-9 | head -c8)
    dbinstallmethod=1
}
init_pwd

pushd "${CAINIAOTOOL_ROOT}" || exit 0
source "${CAINIAOTOOL_ROOT}/lib/logging.sh"
source "${CAINIAOTOOL_ROOT}/lib/utils.sh"
source "${CAINIAOTOOL_ROOT}/lib/set_trap.sh"
source "${CAINIAOTOOL_ROOT}/versions.txt"
source "${CAINIAOTOOL_ROOT}/include/check_os.sh"
source "${CAINIAOTOOL_ROOT}/include/get_char.sh"

clear
printf "
#######################################################################
#       OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+      #
#       For more information please visit https://oneinstack.com      #
#######################################################################
"
# Check if user is root
[ "$(id -u)" != "0" ] && {
    log_error "Error: You must be root to run this script"
    exit 1
}

source "${CAINIAOTOOL_ROOT}/scripts/parse_module/install_with_params.sh"
insert_with_params "$@"

# Check md5sum
check_md5sum() {
    if [ ${ARG_NUM} == 0 ] && [ ! -e ~/.oneinstack ]; then
        # Check md5sum
        while :; do
            echo
            read -e -p "Do you want to check md5sum? [y/n]: " md5sum_flag
            if [[ ! ${md5sum_flag} =~ ^[y,n]$ ]]; then
                echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
            else
                break
            fi
        done
    fi
    if [ "${md5sum_flag}" == 'y' ]; then
        [ -e "${CAINIAOTOOL_ROOT}.tar.gz" ] && oneinstack_file=${CAINIAOTOOL_ROOT}.tar.gz
        [ -e "${CAINIAOTOOL_ROOT}-full.tar.gz" ] && oneinstack_file=${CAINIAOTOOL_ROOT}-full.tar.gz
        oneinstack_tgz=${oneinstack_file##*/}
        if [ -e "${oneinstack_file}" ]; then
            now_oneinstack_md5=$(md5sum ${oneinstack_file} | awk '{print $1}')
            latest_oneinStack_md5=$(curl --connect-timeout 3 -m 5 -s ${mirror_link}/md5sum.txt | grep ${oneinstack_tgz} | awk '{print $1}')
            if [ "${now_oneinstack_md5}" != "${latest_oneinStack_md5}" ]; then
                echo "${CFAILURE}Error: The md5 value of the installation package does not match the official website, please download again, url: ${mirror_link}/${oneinstack_tgz}${CEND}"
                exit 1
            fi
        else
            echo "${CFAILURE}Error: ${oneinstack_file} does not exist${CEND}"
            exit 1
        fi
    fi
}

set_ssh_port() {
    # Use default SSH port 22. If you use another SSH port on your server
    if [ -e "/etc/ssh/sshd_config" ]; then
        [ -z "$(grep ^Port /etc/ssh/sshd_config)" ] && now_ssh_port=22 || now_ssh_port=$(grep ^Port /etc/ssh/sshd_config | awk '{print $2}' | head -1)
        while :; do
            echo
            [ ${ARG_NUM} == 0 ] && read -e -p "Please input SSH port(Default: ${now_ssh_port}): " ssh_port
            ssh_port=${ssh_port:-${now_ssh_port}}
            # if [ ${ssh_port} -eq 22 >/dev/null 2>&1 -o ${ssh_port} -gt 1024 >/dev/null 2>&1 -a ${ssh_port} -lt 65535 >/dev/null 2>&1 ]; then
            if [[ ${ssh_port} -eq 22 || ${ssh_port} -gt 1024 && ${ssh_port} -lt 65535 ]]; then
                break
            else
                echo "${CWARNING}input error! Input range: 22,1025~65534${CEND}"
                exit 1
            fi
        done

        if [ -z "$(grep ^Port /etc/ssh/sshd_config)" -a "${ssh_port}" != '22' ]; then
            sed -i "s@^#Port.*@&\nPort ${ssh_port}@" /etc/ssh/sshd_config
        elif [ -n "$(grep ^Port /etc/ssh/sshd_config)" ]; then
            sed -i "s@^Port.*@Port ${ssh_port}@" /etc/ssh/sshd_config
        fi
    fi
}

source "${CAINIAOTOOL_ROOT}/scripts/parse_module/install_no_params.sh"
insert_no_params "${ARG_NUM}"

create_www_dir() {
    if [[ ${nginx_option} =~ ^[1-4]$ ]] || [ "${apache_flag}" == 'y' ] || [ "${caddy_flag}" == 'y' ] || [[ ${tomcat_option} =~ ^[1-6]$ ]]; then
        [ ! -d ${wwwroot_dir}/default ] && mkdir -p ${wwwroot_dir}/default
        [ ! -d ${wwwlogs_dir} ] && mkdir -p ${wwwlogs_dir}
    fi
    [ -d /data ] && chmod 755 /data
}
#create_www_dir

# install wget gcc curl
if [ ! -e ~/.oneinstack ]; then
    downloadDepsSrc=1
    [ "${PM}" == 'apt-get' ] && apt-get -y update >/dev/null
    [ "${PM}" == 'yum' ] && yum clean all >/dev/null
    ${PM} -y install wget gcc curl >/dev/null
fi
# get the IP information
IPADDR=$(get_internal_ipv4)
PUBLIC_IP=$(get_public_ip)
echo "${IPADDR}"
echo "${PUBLIC_IP}"

# openSSL
# . ./include/install_openssl.sh

# Check download source packages
source "${CAINIAOTOOL_ROOT}/common/check_download.sh"
check_download

# get OS Memory
source "${CAINIAOTOOL_ROOT}/include/memory.sh"

if [ ! -e ~/.oneinstack ]; then
    # Check binary dependencies packages
    source "${CAINIAOTOOL_ROOT}/common/install_dependence.sh"
    case "${Family}" in
    "rhel")
        installDepsRHEL 2>&1 | tee ${CAINIAOTOOL_ROOT}/install.log
        . include/init_RHEL.sh 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
        ;;
    "debian")
        install_dependence_debian
        source "${CAINIAOTOOL_ROOT}/common/init_debian.sh"
        ;;
    "ubuntu")
        installDepsUbuntu 2>&1 | tee ${CAINIAOTOOL_ROOT}/install.log
        . include/init_Ubuntu.sh 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
        ;;
    esac
    # Install dependencies from source package
    install_dependence_by_src
fi

# start Time
startTime=$(date +%s)

# openSSL
source "${CAINIAOTOOL_ROOT}/scripts/php_module/install_openssl.sh"
install_openSSL

# Jemalloc
if [[ ${nginx_option:-1} =~ ^[1-3]$ ]] || [[ "${db_option}" =~ ^[1-9]$|^1[0-2]$ ]]; then
    source "${CAINIAOTOOL_ROOT}/scripts/middleware_module/install_jemalloc.sh"
    install_jemalloc
fi

insert_database() {
    # Database
    case "${db_option:-0}" in
    0)
        source "${CAINIAOTOOL_ROOT}/scripts/db_module/install_mysql-8.4.sh"
        install_MySQL84
        ;;
    5)
        . include/mariadb-10.11.sh
        Install_MariaDB1011 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
        ;;
    9)
        [ "${Family}" == 'rhel' ] && [ "${RHEL_ver}" == '8' ] && dbinstallmethod=2 && checkDownload
        . include/percona-8.0.sh
        Install_Percona80 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
        ;;
    13)
        . include/postgresql.sh
        Install_PostgreSQL 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
        ;;
    14)
        . include/mongodb.sh
        Install_MongoDB 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
        ;;
    esac
}
insert_database

insert_midder() {
    # Nginx server
    case "${nginx_option:-4}" in
    1)
        . include/nginx.sh
        Install_Nginx 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
        ;;
    2)
        . include/tengine.sh
        Install_Tengine 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
        ;;
    3)
        . include/openresty.sh
        Install_OpenResty 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
        ;;
    4)
        source "${CAINIAOTOOL_ROOT}/scripts/middleware_module/install_caddy.sh"
        install_caddy
        caddy_flag='y'
        ;;
    esac

    # Apache
    if [ "${apache_flag:-y}" == 'y' ]; then
        apache_mode_option=${apache_mode_option:-1}
        apache_mpm_option=${apache_mpm_option:-1}
        source "${CAINIAOTOOL_ROOT}/scripts/middleware_module/install_apache.sh"
        install_apache
    fi
}
insert_midder

insert_php() {
    # PHP
    case "${php_option:-15}" in
    13)
        . include/php-8.3.sh
        Install_PHP83 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
        ;;
    14)
        . include/php-8.4.sh
        Install_PHP84 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
        ;;
    15)
        source "${CAINIAOTOOL_ROOT}/scripts/php_module/install_php-8.5.sh"
        install_PHP85
        ;;
    esac
}
insert_php

PHP_addons() {
    # PHP opcode cache PHP 编译时已经支持
#    case "${phpcache_option:-1}" in
#    1)
#        source "${CAINIAOTOOL_ROOT}/scripts/php_module/extension_zendopcache.sh"
#        install_zend_opcache
#        ;;
#    2)
#        . include/apcu.sh
#        Install_APCU 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
#        ;;
#    esac

    # imagick
    if [ "${pecl_imagick:-}" == '1' ]; then
        source "${CAINIAOTOOL_ROOT}/scripts/php_module/extension_image_magick.sh"
        install_image_magick
        install_pecl_imagick
    fi

    # gmagick
    if [ "${pecl_gmagick:-}" == '1' ]; then
        source "${CAINIAOTOOL_ROOT}/scripts/php_module/extension_graphics_magick.sh"
        install_graphics_magick
        install_pecl_gmagick
    fi

    # fileinfo PHP 编译时已经支持
#    if [ "${pecl_fileinfo}" == '1' ]; then
#        . include/pecl_fileinfo.sh
#        Install_pecl_fileinfo 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
#    fi

    # imap 从 PHP 8.4 开始，IMAP 扩展已被移除并解绑（DEPRECATED and UNBUNDLED），PHP 8.5.1 也不再包含此扩展。
#    if [ "${pecl_imap}" == '1' ]; then
#        . include/pecl_imap.sh
#        Install_pecl_imap 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
#    fi

    # ldap
    if [ "${pecl_ldap:-}" == '1' ]; then
        source "${CAINIAOTOOL_ROOT}/scripts/php_module/extension_pecl_ldap.sh"
        install_pecl_ldap
    fi

    # calendar PHP 编译时已经支持
#    if [ "${pecl_calendar}" == '1' ]; then
#        . include/pecl_calendar.sh
#        Install_pecl_calendar 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
#    fi

    # phalcon 安装编译时很吃内容，建议8GB起步，不建议使用
#    if [ "${pecl_phalcon:-}" == '1' ]; then
#        source "${CAINIAOTOOL_ROOT}/scripts/php_module/extension_pecl_phalcon.sh"
#        install_pecl_phalcon
#    fi

    # yaf
    if [ "${pecl_yaf:-1}" == '1' ]; then
        source "${CAINIAOTOOL_ROOT}/scripts/php_module/extension_pecl_yaf.sh"
        install_pecl_yaf
    fi

    # yar
    if [ "${pecl_yar:-1}" == '1' ]; then
        source "${CAINIAOTOOL_ROOT}/scripts/php_module/extension_pecl_yar.sh"
        install_pecl_yar
    fi

    # pecl_memcached 能用redis就用redis
#    if [ "${pecl_memcached}" == '1' ]; then
#        . include/memcached.sh
#        Install_pecl_memcached 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
#    fi

    # pecl_memcache 已停止维护
#    if [ "${pecl_memcache}" == '1' ]; then
#        . include/memcached.sh
#        Install_pecl_memcache 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
#    fi

    # pecl_redis
    if [ "${pecl_redis:-}" == '1' ]; then
        source "${CAINIAOTOOL_ROOT}/scripts/php_module/extension_pecl_redis.sh"
        install_pecl_redis
    fi

    # pecl_mongodb 根据实际情况再说
#    if [ "${pecl_mongodb}" == '1' ]; then
#        . include/pecl_mongodb.sh
#        Install_pecl_mongodb 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
#    fi

    # swoole
    if [ "${pecl_swoole:-}" == '1' ]; then
        source "${CAINIAOTOOL_ROOT}/scripts/php_module/extension_pecl_swoole.sh"
        install_pecl_swoole
    fi

    # xdebug
    if [ "${pecl_xdebug:-}" == '1' ]; then
        source "${CAINIAOTOOL_ROOT}/scripts/php_module/extension_pecl_xdebug.sh"
        install_pecl_xdebug
    fi

    # pecl_pgsql 根据实际情况再说
#    if [ -e "${pgsql_install_dir}/bin/psql" ]; then
#        . include/pecl_pgsql.sh
#        Install_pecl_pgsql 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
#    fi
}

[ "${mphp_addons_flag:-}" != 'y' ] && PHP_addons

# 简写害死人，这里是指多版本的PHP
if [ "${mphp_flag:-}" == 'y' ]; then
    . include/mphp.sh
    Install_MPHP 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
    php_install_dir=${php_install_dir}${mphp_ver}
    PHP_addons
fi

insert_jdk() {
    # JDK
    case "${jdk_option:-1}" in
    1)
        source "${CAINIAOTOOL_ROOT}/scripts/middleware_module/install_openjdk-21.sh"
        install_openJDK21
        ;;
    esac
}
insert_jdk

insert_tomcat() {
    case "${tomcat_option:-1}" in
    1)
        source "${CAINIAOTOOL_ROOT}/scripts/middleware_module/install_tomcat-11.sh"
        install_tomcat11
        ;;
    esac
}
insert_tomcat

insert_server_manager() {
    if [ "${nodejs_flag:-}" == 'y' ]; then
        source "${CAINIAOTOOL_ROOT}/scripts/server_manager/nodejs.sh"
        install_nodejs
    fi

    # Pure-FTPd
    if [ "${pureftpd_flag:-}" == 'y' ]; then
        . include/pureftpd.sh
        Install_PureFTPd 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
    fi

    # phpMyAdmin
    if [ "${phpmyadmin_flag:-}" == 'y' ]; then
        source "${CAINIAOTOOL_ROOT}/scripts/server_manager/phpmyadmin.sh"
        install_phpMyAdmin
    fi

    # redis
    if [ "${redis_flag:-}" == 'y' ]; then
        . include/redis.sh
        Install_redis_server 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
    fi

    # memcached 使用redis
#    if [ "${memcached_flag}" == 'y' ]; then
#        . include/memcached.sh
#        Install_memcached_server 2>&1 | tee -a ${CAINIAOTOOL_ROOT}/install.log
#    fi
}
insert_server_manager

# index example
if [ -d "${wwwroot_dir}/default" ]; then
    source "${CAINIAOTOOL_ROOT}/common/demo.sh"
    demo
fi

# get web_install_dir and db_install_dir
. include/check_dir.sh

# Starting DB
[ -d "/etc/mysql" ] && /bin/mv /etc/mysql{,_bk}
[ -d "${db_install_dir}/support-files" ] && [ -z "$(ps -ef | grep mysqld_safe | grep -v grep)" ] && service mysqld start

# reload php_module
[ -e "${php_install_dir}/sbin/php-fpm" ] && { [ -e "/bin/systemctl" ] && systemctl reload php-fpm || service php-fpm reload; }
[ -n "${mphp_ver}" -a -e "${php_install_dir}${mphp_ver}/sbin/php-fpm" ] && { [ -e "/bin/systemctl" ] && systemctl reload php${mphp_ver}-fpm || service php${mphp_ver}-fpm reload; }
[ -e "${apache_install_dir}/bin/apachectl" ] && ${apache_install_dir}/bin/apachectl -k graceful

endTime=$(date +%s)
((installTime = ($endTime - $startTime) / 60))
echo "####################Congratulations########################"
echo "Total OneinStack Install Time: ${CQUESTION}${installTime}${CEND} minutes"
[[ "${nginx_option}" =~ ^[1-3]$ ]] && echo -e "\n$(printf "%-32s" "Nginx install dir":)${CMSG}${web_install_dir}${CEND}"
[ "${apache_flag}" == 'y' ] && echo -e "\n$(printf "%-32s" "Apache install dir":)${CMSG}${apache_install_dir}${CEND}"
[ "${caddy_flag}" == 'y' ] && echo -e "\n$(printf "%-32s" "Caddy install dir":)${CMSG}${caddy_install_dir}${CEND}"
[[ "${tomcat_option}" =~ ^[1-6]$ ]] && echo -e "\n$(printf "%-32s" "Tomcat install dir":)${CMSG}${tomcat_install_dir}${CEND}"
[[ "${db_option}" =~ ^[1-9]$|^1[0-2]$ ]] && echo -e "\n$(printf "%-32s" "Database install dir:")${CMSG}${db_install_dir}${CEND}"
[[ "${db_option}" =~ ^[1-9]$|^1[0-2]$ ]] && echo "$(printf "%-32s" "Database data dir:")${CMSG}${db_data_dir}${CEND}"
[[ "${db_option}" =~ ^[1-9]$|^1[0-2]$ ]] && echo "$(printf "%-32s" "Database user:")${CMSG}root${CEND}"
[[ "${db_option}" =~ ^[1-9]$|^1[0-2]$ ]] && echo "$(printf "%-32s" "Database password:")${CMSG}${dbrootpwd}${CEND}"
[ "${db_option}" == '13' ] && echo -e "\n$(printf "%-32s" "PostgreSQL install dir:")${CMSG}${pgsql_install_dir}${CEND}"
[ "${db_option}" == '13' ] && echo "$(printf "%-32s" "PostgreSQL data dir:")${CMSG}${pgsql_data_dir}${CEND}"
[ "${db_option}" == '13' ] && echo "$(printf "%-32s" "PostgreSQL user:")${CMSG}postgres${CEND}"
[ "${db_option}" == '13' ] && echo "$(printf "%-32s" "postgres password:")${CMSG}${dbpostgrespwd}${CEND}"
[ "${db_option}" == '14' ] && echo -e "\n$(printf "%-32s" "MongoDB install dir:")${CMSG}${mongo_install_dir}${CEND}"
[ "${db_option}" == '14' ] && echo "$(printf "%-32s" "MongoDB data dir:")${CMSG}${mongo_data_dir}${CEND}"
[ "${db_option}" == '14' ] && echo "$(printf "%-32s" "MongoDB user:")${CMSG}root${CEND}"
[ "${db_option}" == '14' ] && echo "$(printf "%-32s" "MongoDB password:")${CMSG}${dbmongopwd}${CEND}"
[[ "${php_option}" =~ ^[1-9]$|^1[0-2]$ ]] && echo -e "\n$(printf "%-32s" "PHP install dir:")${CMSG}${php_install_dir}${CEND}"
[ "${phpcache_option}" == '1' ] && echo "$(printf "%-32s" "Opcache Control Panel URL:")${CMSG}http://${IPADDR}/ocp.php${CEND}"
[ "${phpcache_option}" == '2' ] && echo "$(printf "%-32s" "APC Control Panel URL:")${CMSG}http://${IPADDR}/apc.php${CEND}"
[ "${phpcache_option}" == '3' -a -e "${php_install_dir}/etc/php.d/04-xcache.ini" ] && echo "$(printf "%-32s" "xcache Control Panel URL:")${CMSG}http://${IPADDR}/xcache${CEND}"
[ "${phpcache_option}" == '3' -a -e "${php_install_dir}/etc/php.d/04-xcache.ini" ] && echo "$(printf "%-32s" "xcache user:")${CMSG}admin${CEND}"
[ "${phpcache_option}" == '3' -a -e "${php_install_dir}/etc/php.d/04-xcache.ini" ] && echo "$(printf "%-32s" "xcache password:")${CMSG}${xcachepwd}${CEND}"
[ "${phpcache_option}" == '4' -a -e "${php_install_dir}/etc/php.d/02-eaccelerator.ini" ] && echo "$(printf "%-32s" "eAccelerator Control Panel URL:")${CMSG}http://${IPADDR}/control.php${CEND}"
[ "${phpcache_option}" == '4' -a -e "${php_install_dir}/etc/php.d/02-eaccelerator.ini" ] && echo "$(printf "%-32s" "eAccelerator user:")${CMSG}admin${CEND}"
[ "${phpcache_option}" == '4' -a -e "${php_install_dir}/etc/php.d/02-eaccelerator.ini" ] && echo "$(printf "%-32s" "eAccelerator password:")${CMSG}eAccelerator${CEND}"
[ "${pureftpd_flag}" == 'y' ] && echo -e "\n$(printf "%-32s" "Pure-FTPd install dir:")${CMSG}${pureftpd_install_dir}${CEND}"
[ "${pureftpd_flag}" == 'y' ] && echo "$(printf "%-32s" "Create FTP virtual script:")${CMSG}./pureftpd_vhost.sh${CEND}"
[ "${phpmyadmin_flag}" == 'y' ] && echo -e "\n$(printf "%-32s" "phpMyAdmin dir:")${CMSG}${wwwroot_dir}/default/phpMyAdmin${CEND}"
[ "${phpmyadmin_flag}" == 'y' ] && echo "$(printf "%-32s" "phpMyAdmin Control Panel URL:")${CMSG}http://${IPADDR}/phpMyAdmin${CEND}"
[ "${redis_flag}" == 'y' ] && echo -e "\n$(printf "%-32s" "redis install dir:")${CMSG}${redis_install_dir}${CEND}"
[ "${memcached_flag}" == 'y' ] && echo -e "\n$(printf "%-32s" "memcached install dir:")${CMSG}${memcached_install_dir}${CEND}"
if [[ ${nginx_option} =~ ^[1-4]$ ]] || [ "${apache_flag}" == 'y' ] || [[ ${tomcat_option} =~ ^[1-6]$ ]]; then
    echo -e "\n$(printf "%-32s" "Index URL:")${CMSG}http://${IPADDR}/${CEND}"
fi
if [ ${ARG_NUM} == 0 ]; then
    while :; do
        echo
        echo "${CMSG}Please restart the server and see if the services start up fine.${CEND}"
        read -e -p "Do you want to restart OS ? [y/n]: " reboot_flag
        if [[ ! "${reboot_flag}" =~ ^[y,n]$ ]]; then
            echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
        else
            break
        fi
    done
fi
[ "${reboot_flag}" == 'y' ] && reboot

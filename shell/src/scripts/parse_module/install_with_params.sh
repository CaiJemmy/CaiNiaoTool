#!/usr/bin/env bash

source "${CAINIAOTOOL_ROOT}/lib/logging.sh"

version() {
    echo "version: 2.7"
    echo "updated date: 2026-01-07"
}

Show_Help() {
    version
    echo "Usage: $0  command ...[parameters]....
  --help, -h                  Show this help message, More: https://oneinstack.com/auto
  --version, -v               Show version info
  --nginx_option [1-4]        Install Nginx server version, 1: nginx, 2: Tengine, 3: OpenResty, 4: Caddy
  --apache                    Install Apache
  --apache_mode_option [1-2]  Apache2.4 mode, 1(default): php-fpm, 2: mod_php
  --apache_mpm_option [1-3]   Apache2.4 MPM, 1(default): event, 2: prefork, 3: worker
  --php_option [1-15]         Install PHP version
  --mphp_ver [53~85]          Install another PHP version (PATH: ${php_install_dir}\${mphp_ver})
  --mphp_addons               Only install another PHP addons
  --phpcache_option [1-4]     Install PHP opcode cache, default: 1 opcache
  --php_extensions [ext name] Install PHP extensions, include zendguardloader,ioncube,
                              sourceguardian,imagick,gmagick,fileinfo,imap,ldap,calendar,phalcon,
                              yaf,yar,redis,memcached,memcache,mongodb,swoole,xdebug
  --nodejs                    Install Nodejs
  --tomcat_option [1-6]       Install Tomcat version
  --jdk_option [1-3]          Install JDK version
  --db_option [1-15]          Install DB version
  --dbinstallmethod [1-2]     DB install method, default: 1 binary install
  --dbrootpwd [password]      DB super password
  --pureftpd                  Install Pure-Ftpd
  --redis                     Install Redis
  --memcached                 Install Memcached
  --phpmyadmin                Install phpMyAdmin
  --ssh_port [No.]            SSH port
  --firewall                  Enable firewall
  --md5sum                    Check md5sum
  --reboot                    Restart the server after installation
Example:
  $0 --help or $0 -h
  $0 --version or $0 -v or $0 -V
  $0 --nginx_option 1
  $0 --apache
  $0 --apache_mode_option 1
  $0 --apache_mpm_option 1
  $0 --php_option 1
  $0 --mphp_ver   # todo
  $0 --mphp_addons # todo
  $0 --phpcache_option
  $0 --php_extensions
  $0 --nodejs
  $0 --tomcat_option
  $0 --jdk_option
  $0 --db_option
  $0 --dbinstallmethod
  $0 --dbrootpwd
  $0 --pureftpd
  $0 --redis
  $0 --memcached
  $0 --phpmyadmin
  $0 --ssh_port
  $0 --firewall
  $0 --md5sum
  $0 --reboot
  $0 --
  "
}

insert_with_params() {
    set +u
    TEMP=$(getopt -o hvV --long help,version,nginx_option:,apache,apache_mode_option:,apache_mpm_option:,php_option:,mphp_ver:,mphp_addons,phpcache_option:,php_extensions:,nodejs,tomcat_option:,jdk_option:,db_option:,dbrootpwd:,dbinstallmethod:,pureftpd,redis,memcached,phpmyadmin,ssh_port:,firewall,md5sum,reboot -- "$@" 2>/dev/null)
    [ $? != 0 ] && log_error "ERROR: unknown argument!" && Show_Help && exit 1
    eval set -- "${TEMP}"

    while :; do
        [ -z "$1" ] && break
        case "$1" in
        -h | --help)
            Show_Help
            exit 0
            ;;
        -v | -V | --version)
            version
            exit 0
            ;;
        --nginx_option)
            nginx_option=$2
            shift 2
            [[ ! ${nginx_option} =~ ^[1-4]$ ]] && {
                echo "${CWARNING}nginx_option input error! Please only input number 1~4${CEND}"
                exit 1
            }
            [ -e "${nginx_install_dir}/sbin/nginx" ] && {
                echo "${CWARNING}Nginx already installed! ${CEND}"
                unset nginx_option
            }
            [ -e "${tengine_install_dir}/sbin/nginx" ] && {
                echo "${CWARNING}Tengine already installed! ${CEND}"
                unset nginx_option
            }
            [ -e "${openresty_install_dir}/nginx/sbin/nginx" ] && {
                echo "${CWARNING}OpenResty already installed! ${CEND}"
                unset nginx_option
            }
            [ -e "${caddy_install_dir}/bin/caddy" ] && {
                echo "${CWARNING}Caddy already installed! ${CEND}"
                unset nginx_option
            }
            ;;
        --apache)
            apache_flag=y
            shift 1
            [ -e "${apache_install_dir}/bin/httpd" ] && {
                echo "${CWARNING}Aapche already installed! ${CEND}"
                unset apache_flag
            }
            ;;
        --apache_mode_option)
            apache_mode_option=$2
            shift 2
            [[ ! ${apache_mode_option} =~ ^[1-2]$ ]] && {
                echo "${CWARNING}apache_mode_option input error! Please only input number 1~2${CEND}"
                exit 1
            }
            ;;
        --apache_mpm_option)
            apache_mpm_option=$2
            shift 2
            [[ ! ${apache_mpm_option} =~ ^[1-3]$ ]] && {
                echo "${CWARNING}apache_mpm_option input error! Please only input number 1~3${CEND}"
                exit 1
            }
            ;;
        --php_option)
            php_option=$2
            shift 2
            [[ ! ${php_option} =~ ^[1-9]$|^1[0-5]$ ]] && {
                echo "${CWARNING}php_option input error! Please only input number 1~15${CEND}"
                exit 1
            }
            [ -e "${php_install_dir}/bin/phpize" ] && {
                echo "${CWARNING}PHP already installed! ${CEND}"
                unset php_option
            }
            ;;
        --mphp_ver)
            mphp_ver=$2
            mphp_flag=y
            shift 2
            [[ ! "${mphp_ver}" =~ ^5[3-6]$|^7[0-4]$|^8[0-5]$ ]] && {
                echo "${CWARNING}mphp_ver input error! Please only input number 53~85${CEND}"
                exit 1
            }
            ;;
        --mphp_addons)
            mphp_addons_flag=y
            shift 1
            ;;
        --phpcache_option)
            phpcache_option=$2
            shift 2
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
            [ -e "${nodejs_install_dir}/bin/node" ] && {
                echo "${CWARNING}Nodejs already installed! ${CEND}"
                unset nodejs_flag
            }
            ;;
        --tomcat_option)
            tomcat_option=$2
            shift 2
            [[ ! ${tomcat_option} =~ ^[1-6]$ ]] && {
                echo "${CWARNING}tomcat_option input error! Please only input number 1~6${CEND}"
                exit 1
            }
            [ -e "$tomcat_install_dir/conf/server.xml" ] && {
                echo "${CWARNING}Tomcat already installed! ${CEND}"
                unset tomcat_option
            }
            ;;
        --jdk_option)
            jdk_option=$2
            shift 2
            [[ ! ${jdk_option} =~ ^[1-4]$ ]] && {
                echo "${CWARNING}jdk_option input error! Please only input number 1~4${CEND}"
                exit 1
            }
            ;;
        --db_option)
            db_option=$2
            shift 2
            if [[ "${db_option}" =~ ^[1-9]$|^1[0-2]$ ]]; then
                [ -d "${db_install_dir}/support-files" ] && {
                    echo "${CWARNING}MySQL already installed! ${CEND}"
                    unset db_option
                }
            elif [ "${db_option}" == '13' ]; then
                [ -e "${pgsql_install_dir}/bin/psql" ] && {
                    echo "${CWARNING}PostgreSQL already installed! ${CEND}"
                    unset db_option
                }
            elif [ "${db_option}" == '15' ]; then
                [ -e "${mongo_install_dir}/bin/mongo" ] && {
                    echo "${CWARNING}MongoDB already installed! ${CEND}"
                    unset db_option
                }
            else
                echo "${CWARNING}db_option input error! Please only input number 1~15${CEND}"
                exit 1
            fi
            ;;
        --dbrootpwd)
            dbrootpwd=$2
            shift 2
            dbpostgrespwd="${dbrootpwd}"
            dbmongopwd="${dbrootpwd}"
            ;;
        --dbinstallmethod)
            dbinstallmethod=$2
            shift 2
            [[ ! ${dbinstallmethod} =~ ^[1-2]$ ]] && {
                echo "${CWARNING}dbinstallmethod input error! Please only input number 1~2${CEND}"
                exit 1
            }
            ;;
        --pureftpd)
            pureftpd_flag=y
            shift 1
            [ -e "${pureftpd_install_dir}/sbin/pure-ftpwho" ] && {
                echo "${CWARNING}Pure-FTPd already installed! ${CEND}"
                unset pureftpd_flag
            }
            ;;
        --redis)
            redis_flag=y
            shift 1
            [ -e "${redis_install_dir}/bin/redis-server" ] && {
                echo "${CWARNING}redis-server already installed! ${CEND}"
                unset redis_flag
            }
            ;;
        --memcached)
            memcached_flag=y
            shift 1
            [ -e "${memcached_install_dir}/bin/memcached" ] && {
                echo "${CWARNING}memcached-server already installed! ${CEND}"
                unset memcached_flag
            }
            ;;
        --phpmyadmin)
            phpmyadmin_flag=y
            shift 1
            [ -d "${wwwroot_dir}/default/phpMyAdmin" ] && {
                echo "${CWARNING}phpMyAdmin already installed! ${CEND}"
                unset phpmyadmin_flag
            }
            ;;
        --ssh_port)
            ssh_port=$2
            shift 2
            ;;
        --firewall)
            firewall_flag=y
            shift 1
            ;;
        --md5sum)
            md5sum_flag=y
            shift 1
            ;;
        --reboot)
            reboot_flag=y
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
    set -u
}

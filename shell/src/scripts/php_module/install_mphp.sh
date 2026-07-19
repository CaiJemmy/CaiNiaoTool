#!/bin/bash

install_MPHP() {
  if [ -e "${php_install_dir}/sbin/php-fpm" ]; then
    if [ -e "${php_install_dir}${mphp_ver}/bin/phpize" ]; then
      log_info "PHP${mphp_ver} already installed!"
    else
      [ -e "/lib/systemd/system/php-fpm.service" ] && /bin/mv /lib/systemd/system/php-fpm.service{,_bk}
      php_install_dir=${php_install_dir}${mphp_ver}
      case "${mphp_ver}" in
        84)
          . include/php-8.4.sh
          Install_PHP84 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
      esac
      if [ -e "${php_install_dir}/sbin/php-fpm" ]; then
        systemctl stop php-fpm
        sed -i "s@/dev/shm/php-cgi.sock@/dev/shm/php${mphp_ver}-cgi.sock@" ${php_install_dir}/etc/php-fpm.conf
        [ -e "/lib/systemd/system/php-fpm.service" ] && /bin/mv /lib/systemd/system/php-fpm.service /lib/systemd/system/php${mphp_ver}-fpm.service
        [ -e "/lib/systemd/system/php-fpm.service_bk" ] && /bin/mv /lib/systemd/system/php-fpm.service{_bk,}
        systemctl enable php${mphp_ver}-fpm
        systemctl enable php-fpm
        systemctl start php-fpm
        systemctl start php${mphp_ver}-fpm
        sed -i "s@${php_install_dir}/bin:@@" /etc/profile
      fi
    fi
  else
    log_error "To use the multiple PHP versions, You need to use PHP-FPM!"
  fi
}

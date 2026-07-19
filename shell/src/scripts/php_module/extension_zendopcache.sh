#!/bin/bash

install_zend_opcache() {
    if [ -e "${php_install_dir}/bin/phpize" ]; then
        php -m 2>/dev/null | grep -qi "opcache" && {
            log_info "PHP Zend OPcache module installed!"
            return 0
        }

        if [ -e "${php_install_dir}/etc/php.d/02-opcache.ini" ]; then
            log_info "PHP opcache module installed!"
            return 0
        fi

        local enable_opcache=$(${php_install_dir}/bin/php -m | grep -i opcache | grep -v grep | wc -l)
        if [[ ${enable_opcache} -ge 1 ]]; then
            cat >${php_install_dir}/etc/php.d/02-opcache.ini <<EOF
[opcache]
zend_extension=opcache.so
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=${Memory_limit}
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=100000
opcache.max_wasted_percentage=5
opcache.use_cwd=1
opcache.validate_timestamps=1
opcache.revalidate_freq=60
;opcache.save_comments=0
opcache.fast_shutdown=1
opcache.consistency_checks=0
;opcache.optimization_level=0
EOF

            log_info "PHP opcache module installed successfully!"
            return 0
        fi

        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
        PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
        tar xzf php-${PHP_detail_ver}.tar.gz
        pushd php-${PHP_detail_ver}/ext/opcache >/dev/null

        ${php_install_dir}/bin/phpize
        log_exec ./configure --with-php-config=${php_install_dir}/bin/php-config
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null
        if [ -f "${phpExtensionDir}/opcache.so" ]; then
            # write opcache configs
            # For php_module 5.5+
            cat >${php_install_dir}/etc/php.d/02-opcache.ini <<EOF
[opcache]
zend_extension=opcache.so
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=${Memory_limit}
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=100000
opcache.max_wasted_percentage=5
opcache.use_cwd=1
opcache.validate_timestamps=1
opcache.revalidate_freq=60
;opcache.save_comments=0
opcache.fast_shutdown=1
opcache.consistency_checks=0
;opcache.optimization_level=0
EOF

            log_info "PHP opcache module installed successfully!"
            rm -rf php-${PHP_detail_ver}
        else
            log_error "PHP opcache module install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        fi
        popd >/dev/null
    fi
}

uninstall_zend_opcache() {
    if [ -e "${php_install_dir}/etc/php.d/02-opcache.ini" ]; then
        rm -f ${php_install_dir}/etc/php.d/02-opcache.ini
        echo
        log_info "PHP opcache module uninstall completed"
    else
        echo
        log_warn "PHP opcache module does not exist!"
    fi
}

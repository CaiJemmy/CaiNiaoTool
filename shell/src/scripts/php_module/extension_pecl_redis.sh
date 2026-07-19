#!/bin/bash

install_pecl_redis() {
    if [[ -f "${php_install_dir}/etc/php.d/05-redis.ini" ]]; then
        log_info "redis already installed!"
        return 0
    fi

    if [ -e "${php_install_dir}/bin/phpize" ]; then
        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)

        tar xzf redis-${pecl_redis_ver}.tgz
        pushd redis-${pecl_redis_ver} >/dev/null

        ${php_install_dir}/bin/phpize
        log_exec ./configure --with-php-config=${php_install_dir}/bin/php-config
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null

        if [ -f "${phpExtensionDir}/redis.so" ]; then
            echo 'extension=redis.so' >${php_install_dir}/etc/php.d/05-redis.ini
            log_info "PHP Redis module installed successfully!"
            rm -rf redis-${pecl_redis_ver}
        else
            log_error "PHP Redis module install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        fi
        popd >/dev/null
    fi
}

Uninstall_pecl_redis() {
    if [ -e "${php_install_dir}/etc/php.d/05-redis.ini" ]; then
        rm -f ${php_install_dir}/etc/php.d/05-redis.ini
        echo
        echo "${CMSG}PHP redis module uninstall completed${CEND}"
    else
        echo
        echo "${CWARNING}PHP redis module does not exist! ${CEND}"
    fi
}

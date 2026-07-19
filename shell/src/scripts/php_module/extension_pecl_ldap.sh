#!/bin/bash

install_pecl_ldap() {
    if [ -e "${php_install_dir}/bin/phpize" ]; then
        if [[ -f "${php_install_dir}/etc/php.d/04-ldap.ini" ]]; then
            log_info "ldap already installed!"
            return 0
        fi

        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
        PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)

        tar xzf php-${PHP_detail_ver}.tar.gz
        pushd php-${PHP_detail_ver}/ext/ldap >/dev/null

        log_exec apt-get -y install libldap2-dev
        ln -s /usr/lib/${ARCH}-linux-gnu/libldap.so /usr/lib/
        ln -s /usr/lib/${ARCH}-linux-gnu/liblber.so /usr/lib/

        ${php_install_dir}/bin/phpize
        log_exec ./configure --with-php-config=${php_install_dir}/bin/php-config --with-ldap --with-libdir=lib/x86_64-linux-gnu
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null
        if [ -f "${phpExtensionDir}/ldap.so" ]; then
            echo 'extension=ldap.so' >${php_install_dir}/etc/php.d/04-ldap.ini
            log_info "PHP ldap module installed successfully!"
            rm -rf php-${PHP_detail_ver}
        else
            log_error "PHP ldap module install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        fi
        popd >/dev/null
    fi
}

Uninstall_pecl_ldap() {
    if [ -e "${php_install_dir}/etc/php.d/04-ldap.ini" ]; then
        rm -f ${php_install_dir}/etc/php.d/04-ldap.ini
        echo
        echo "${CMSG}PHP ldap module uninstall completed${CEND}"
    else
        echo
        echo "${CWARNING}PHP ldap module does not exist! ${CEND}"
    fi
}

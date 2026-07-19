#!/bin/bash

install_pecl_yaf() {
    if [ -e "${php_install_dir}/bin/phpize" ]; then
        if [[ -f "${php_install_dir}/etc/php.d/04-yaf.ini" ]]; then
            log_info "yaf already installed!"
            return 0
        fi

        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
        tar xzf yaf-${yaf_ver}.tgz

        pushd yaf-${yaf_ver} >/dev/null
        ${php_install_dir}/bin/phpize
        log_exec ./configure --with-php-config=${php_install_dir}/bin/php-config
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null

        if [ -f "${phpExtensionDir}/yaf.so" ]; then
            echo 'extension=yaf.so' >${php_install_dir}/etc/php.d/04-yaf.ini
            log_info "PHP yaf module installed successfully!"
            rm -rf yaf-${yaf_ver}
        else
            log_error "PHP yaf module install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        fi

        popd >/dev/null
    fi
}

Uninstall_pecl_yaf() {
    if [ -e "${php_install_dir}/etc/php.d/04-yaf.ini" ]; then
        rm -f ${php_install_dir}/etc/php.d/04-yaf.ini
        echo
        echo "${CMSG}PHP yaf module uninstall completed${CEND}"
    else
        echo
        echo "${CWARNING}PHP yaf module does not exist! ${CEND}"
    fi
}

#!/bin/bash

install_pecl_yar() {
    if [ -e "${php_install_dir}/bin/phpize" ]; then
        if [[ -f "${php_install_dir}/etc/php.d/04-yar.ini" ]]; then
            log_info "yar already installed!"
            return 0
        fi

        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
        tar xzf yar-${yar_ver}.tgz

        pushd yar-${yar_ver} >/dev/null
        ${php_install_dir}/bin/phpize
        log_exec ./configure --with-php-config=${php_install_dir}/bin/php-config --with-curl=${curl_install_dir}
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null

        if [ -f "${phpExtensionDir}/yar.so" ]; then
            echo 'extension=yar.so' >${php_install_dir}/etc/php.d/04-yar.ini
            log_info "PHP yar module installed successfully!"
            rm -rf yar-${yar_ver}
        else
            log_error "PHP yar module install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        fi

        popd >/dev/null
    fi
}

Uninstall_pecl_yar() {
    if [ -e "${php_install_dir}/etc/php.d/04-yar.ini" ]; then
        rm -f ${php_install_dir}/etc/php.d/04-yar.ini
        echo
        echo "${CMSG}PHP yar module uninstall completed${CEND}"
    else
        echo
        echo "${CWARNING}PHP yar module does not exist! ${CEND}"
    fi
}

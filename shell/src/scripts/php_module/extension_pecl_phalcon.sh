#!/bin/bash

install_pecl_phalcon() {
    if [ -e "${php_install_dir}/bin/phpize" ]; then
        if [[ -f "${php_install_dir}/etc/php.d/04-phalcon.ini" ]]; then
            log_info "phalcon already installed!"
            return 0
        fi

        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
        tar xzf cphalcon-${phalcon_ver}.tar.gz

        pushd cphalcon-${phalcon_ver}/build >/dev/null
        log_exec ./install
        popd >/dev/null
        rm -fr cphalcon-${phalcon_ver}

        if [ -f "${phpExtensionDir}/phalcon.so" ]; then
            echo 'extension=phalcon.so' >${php_install_dir}/etc/php.d/04-phalcon.ini
            log_info "PHP phalcon module installed successfully!"
            rm -rf cphalcon-${phalcon_oldver} phalcon-${phalcon_ver}
        else
            log_error "PHP phalcon module install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        fi
        popd >/dev/null
    fi
}

Uninstall_pecl_phalcon() {
    if [ -e "${php_install_dir}/etc/php.d/04-phalcon.ini" ]; then
        rm -f ${php_install_dir}/etc/php.d/04-phalcon.ini
        echo
        echo "${CMSG}PHP phalcon module uninstall completed${CEND}"
    else
        echo
        echo "${CWARNING}PHP phalcon module does not exist! ${CEND}"
    fi
}

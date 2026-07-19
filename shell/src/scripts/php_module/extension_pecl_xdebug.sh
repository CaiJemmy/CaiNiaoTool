#!/bin/bash

install_pecl_xdebug() {
    if [ -e "${php_install_dir}/bin/phpize" ]; then
        if [[ -f "${php_install_dir}/etc/php.d/08-xdebug.ini" ]]; then
            log_info "xdebug already installed!"
            return 0
        fi

        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)

        tar xzf xdebug-${xdebug_ver}.tgz
        pushd xdebug-${xdebug_ver} >/dev/null
        ${php_install_dir}/bin/phpize

        log_exec ./configure --with-php-config=${php_install_dir}/bin/php-config
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null

        if [ -f "${phpExtensionDir}/xdebug.so" ]; then
            tar zxf webgrind-1.9.4.tgz
            /bin/mv webgrind-1.9.4 ${wwwroot_dir}/default/webgrind
            [ ! -e /tmp/xdebug ] && {
                mkdir /tmp/xdebug
                chown ${run_user}:${run_group} /tmp/xdebug
            }
            [ ! -e /tmp/webgrind ] && {
                mkdir /tmp/webgrind
                chown ${run_user}:${run_group} /tmp/webgrind
            }
            chown -R ${run_user}:${run_group} ${wwwroot_dir}/default/webgrind
            sed -i 's@static $storageDir.*@static $storageDir = "/tmp/webgrind";@' ${wwwroot_dir}/default/webgrind/config.php
            sed -i 's@static $profilerDir.*@static $profilerDir = "/tmp/xdebug";@' ${wwwroot_dir}/default/webgrind/config.php
            cat >${php_install_dir}/etc/php.d/08-xdebug.ini <<EOF
[xdebug]
zend_extension=xdebug.so
xdebug.trace_output_dir=/tmp/xdebug
xdebug.profiler_output_dir = /tmp/xdebug
xdebug.profiler_enable = On
xdebug.profiler_enable_trigger = 1
EOF
            log_info "PHP xdebug module installed successfully!"
            echo
            log_info "Webgrind URL: http://${PUBLIC_IP}/webgrind"
            rm -rf xdebug-${xdebug_ver}
        else
            log_error "PHP xdebug module install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        fi

        popd >/dev/null
    fi
}

Uninstall_pecl_xdebug() {
    if [ -e "${php_install_dir}/etc/php.d/08-xdebug.ini" ]; then
        rm -rf ${php_install_dir}/etc/php.d/08-xdebug.ini /tmp/{xdebug,webgrind} ${wwwroot_dir}/default/webgrind
        echo
        echo "${CMSG}PHP xdebug module uninstall completed${CEND}"
    else
        echo
        echo "${CWARNING}PHP xdebug module does not exist! ${CEND}"
    fi
}

#!/bin/bash

install_graphics_magick() {
    if [ -d "${gmagick_install_dir}" ]; then
        log_info "GraphicsMagick already installed!"
    else
        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        tar zxf libheif-1.23.1.tar.gz
        pushd libheif-1.23.1 >/dev/null
        mkdir build
        cd build
        cmake --preset=release ..
        log_exec make -j ${THREAD}
        log_exec make install
        ldconfig
        popd >/dev/null
        rm -fr libheif-1.23.1

        tar xJf GraphicsMagick-${graphicsmagick_ver}.tar.xz
        pushd GraphicsMagick-${graphicsmagick_ver} >/dev/null
        log_exec ./configure --prefix=${gmagick_install_dir} --enable-shared --enable-static --enable-symbol-prefix
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null
        rm -rf GraphicsMagick-${graphicsmagick_ver}
        popd >/dev/null
    fi
}

Uninstall_GraphicsMagick() {
    if [ -d "${gmagick_install_dir}" ]; then
        rm -rf ${gmagick_install_dir}
        echo
        echo "${CMSG}GraphicsMagick uninstall completed${CEND}"
    fi
}

install_pecl_gmagick() {
    if [[ -f "${php_install_dir}/etc/php.d/03-gmagick.ini" ]]; then
        log_info "gmagick already installed!"
        return 0
    fi

    if [ -e "${php_install_dir}/bin/phpize" ]; then
        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
        tar xzf gmagick-${gmagick_ver}.tgz
        pushd gmagick-${gmagick_ver} >/dev/null
        export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
        ${php_install_dir}/bin/phpize
        log_exec ./configure --with-php-config=${php_install_dir}/bin/php-config --with-gmagick=${gmagick_install_dir}
        sed -i 's/zend_exception_get_default()/zend_ce_exception/g' ${CAINIAOTOOL_ROOT}/src/gmagick-${gmagick_ver}/gmagick.c
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null
        if [ -f "${phpExtensionDir}/gmagick.so" ]; then
            echo 'extension=gmagick.so' >${php_install_dir}/etc/php.d/03-gmagick.ini
            log_info "PHP gmagick module installed successfully!"
            rm -rf gmagick-${gmagick_ver}
        else
            log_error "PHP gmagick module install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        fi
        popd >/dev/null
    fi
}

Uninstall_pecl_gmagick() {
    if [ -e "${php_install_dir}/etc/php.d/03-gmagick.ini" ]; then
        rm -f ${php_install_dir}/etc/php.d/03-gmagick.ini
        echo
        echo "${CMSG}PHP gmagick module uninstall completed${CEND}"
    else
        echo
        echo "${CWARNING}PHP gmagick module does not exist! ${CEND}"
    fi
}

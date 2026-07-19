#!/bin/bash

install_image_magick() {
    if [ -d "${imagick_install_dir}" ]; then
        log_info "ImageMagick already installed!"
    else
        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        tar xzf ImageMagick-${imagemagick_ver}.tar.gz
        pushd ImageMagick-${imagemagick_ver} >/dev/null
        log_exec ./configure --prefix=${imagick_install_dir} --enable-shared --enable-static
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null
        rm -rf ImageMagick-${imagemagick_ver}
        popd >/dev/null
    fi
}

Uninstall_ImageMagick() {
    if [ -d "${imagick_install_dir}" ]; then
        rm -rf ${imagick_install_dir}
        echo
        echo "${CMSG}ImageMagick uninstall completed${CEND}"
    fi
}

install_pecl_imagick() {
    if [[ -f "${php_install_dir}/etc/php.d/03-imagick.ini" ]]; then
        log_info "imagick already installed!"
        return 0
    fi

    if [ -e "${php_install_dir}/bin/phpize" ]; then
        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
        tar xzf imagick-${imagick_ver}.tar.gz
        pushd imagick-${imagick_ver} >/dev/null
        export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
        ${php_install_dir}/bin/phpize
        log_exec ./configure --with-php-config=${php_install_dir}/bin/php-config --with-imagick=${imagick_install_dir}
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null
        if [ -f "${phpExtensionDir}/imagick.so" ]; then
            echo 'extension=imagick.so' >${php_install_dir}/etc/php.d/03-imagick.ini
            log_info "PHP imagick module installed successfully!"
            rm -rf imagick-${imagick_ver} imagick-${imagick_oldver}
        else
            log_error "PHP imagick module install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        fi
        popd >/dev/null
    fi
}

Uninstall_pecl_imagick() {
    if [ -e "${php_install_dir}/etc/php.d/03-imagick.ini" ]; then
        rm -f ${php_install_dir}/etc/php.d/03-imagick.ini
        echo
        echo "${CMSG}PHP imagick module uninstall completed${CEND}"
    else
        echo
        echo "${CWARNING}PHP imagick module does not exist! ${CEND}"
    fi
}

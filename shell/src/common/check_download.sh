#!/bin/bash

source "${CAINIAOTOOL_ROOT}/lib/utils.sh"
source "${CAINIAOTOOL_ROOT}/lib/logging.sh"

download_openssl() {
    log_info "Download openSSL..."
    local src_url="https://github.com/openssl/openssl/releases/download/openssl-${openssl_ver}/openssl-${openssl_ver}.tar.gz"
    local target="openssl-${openssl_ver}.tar.gz"
    download_file "${src_url}" "${target}"

    log_info "Download cacert.pem..."
    src_url="https://curl.se/ca/cacert.pem"
    target="cacert.pem"
    download_file "${src_url}" "${target}"
}

download_icu() {
    local src_url="${mirror_link}/oneinstack/src/icu4c-${icu4c_ver}-src.tgz"
    local target="icu4c-${icu4c_ver}-src.tgz"
    download_file "${src_url}" "${target}"
}

download_jemalloc() {
    if [[ ${nginx_option:-1} =~ ^[1-3]$ ]] || [[ "${db_option:-1}" =~ ^[1-9]$|^1[0-2]$ ]]; then
        local src_url=${mirror_link}/oneinstack/src/jemalloc-${jemalloc_ver}.tar.bz2
        local target="jemalloc-${jemalloc_ver}.tar.bz2"
        download_file "${src_url}" "${target}"
    fi
}

download_mysqldb() {
    if [[ ${nginx_option:-1} =~ ^[1-3]$ ]] || [[ "${db_option:-1}" =~ ^[1-9]$|^1[0-2]$ ]]; then
        local src_url="https://cdn.mysql.com//Downloads/MySQL-8.4/mysql-${mysql84_ver}-linux-glibc2.28-x86_64.tar.xz"
        local target="mysql-${mysql84_ver}-linux-glibc2.28-x86_64.tar.xz"
        download_file "${src_url}" "${target}"

        src_url="https://pagure.io/libaio/archive/libaio-0.3.113/libaio-libaio-0.3.113.tar.gz"
        target="libaio-libaio-0.3.113.tar.gz"
        download_file "${src_url}" "${target}"
    fi
}

download_caddy() {
    if [[ ${nginx_option:-1} =~ ^[1-3]$ ]] || [[ "${db_option:-1}" =~ ^[1-9]$|^1[0-2]$ ]]; then
        local src_url="https://github.com/caddyserver/caddy/releases/download/v2.11.4/caddy_${caddy_ver}_linux_amd64.tar.gz"
        local target="caddy_${caddy_ver}_linux_amd64.tar.gz"
        download_file "${src_url}" "${target}"
    fi
}

download_php() {
    if [[ ${nginx_option:-1} =~ ^[1-3]$ ]] || [[ "${db_option:-1}" =~ ^[1-9]$|^1[0-2]$ ]]; then
        local src_url="${mirror_link}/oneinstack/src/php-${php85_ver}.tar.gz"
        local target="php-${php85_ver}.tar.gz"
        download_file "${src_url}" "${target}"
    fi
}

download_pcre() {
    if [[ "${nginx_option:-1}" =~ ^[1-3]$ ]] || [ "${apache_flag}" == 'y' ]; then
        local src_url="${mirror_link}/oneinstack/src/pcre-${pcre_ver}.tar.gz"
        local target="pcre-${pcre_ver}.tar.gz"
        download_file "${src_url}" "${target}"
    fi
}

download_apache() {
    if [ "${apache_flag:-y}" == 'y' ]; then
        local src_url="http://archive.apache.org/dist/httpd/httpd-${apache_ver}.tar.gz"
        local target="httpd-${apache_ver}.tar.gz"
        download_file "${src_url}" "${target}"

        src_url="http://archive.apache.org/dist/apr/apr-${apr_ver}.tar.gz"
        target="apr-${apr_ver}.tar.gz"
        download_file "${src_url}" "${target}"

        src_url="http://archive.apache.org/dist/apr/apr-util-${apr_util_ver}.tar.gz"
        target="apr-util-${apr_util_ver}.tar.gz"
        download_file "${src_url}" "${target}"

        src_url="${mirror_link}/oneinstack/src/nghttp2-${nghttp2_ver}.tar.gz"
        target="nghttp2-${nghttp2_ver}.tar.gz"
        download_file "${src_url}" "${target}"
    fi
}

download_php_image_magick() {
    if [ "${pecl_imagick:-1}" == '1' ]; then
        local src_url="${mirror_link}/oneinstack/src/ImageMagick-${imagemagick_ver}.tar.gz"
        local target="ImageMagick-${imagemagick_ver}.tar.gz"
        download_file "${src_url}" "${target}"

        src_url="https://github.com/Imagick/imagick/archive/refs/tags/${imagick_ver}.tar.gz"
        target="imagick-${imagick_ver}.tar.gz"
        download_file "${src_url}" "${target}"
    fi
}

download_php_graphics_magick() {
    if [ "${pecl_gmagick:-1}" == '1' ]; then
        local src_url="https://github.com/strukturag/libheif/archive/refs/tags/v1.23.1.tar.gz"
        local target="libheif-1.23.1.tar.gz"
        download_file "${src_url}" "${target}"

        # http://www.graphicsmagick.org/ 官网地址，sourceforge.net 下载地址不统一
        src_url="https://sf-eu-introserv-1.dl.sourceforge.net/project/graphicsmagick/graphicsmagick/${graphicsmagick_ver}/GraphicsMagick-${graphicsmagick_ver}.tar.xz?viasf=1&fid=c21e253c66dc8660&e=1784443212&st=3Zzf-Eqx90Ic-oFJtqbczQ"
        target="GraphicsMagick-${graphicsmagick_ver}.tar.xz"
        download_file "${src_url}" "${target}"

        # https://pecl.php.net/package/gmagick
        src_url="https://pecl.php.net/get/gmagick-${gmagick_ver}.tgz"
        target="gmagick-${gmagick_ver}.tgz"
        download_file "${src_url}" "${target}"
    fi
}

# 这个github下载站点有问题
# 参考 https://pecl.php.net/get/phalcon-5.16.0.tgz
download_php_phalcon() {
    if [ "${pecl_phalcon:-1}" == '1' ]; then
        local src_url="https://github.com/phalcon/cphalcon/archive/refs/tags/v${phalcon_ver}.tar.gz"
        local target="cphalcon-${phalcon_ver}.tar.gz"
        download_file "${src_url}" "${target}"
    fi
}

download_php_yaf() {
    if [ "${pecl_yaf:-1}" == '1' ]; then
        local src_url="https://pecl.php.net/get/yaf-${yaf_ver}.tgz"
        local target="yaf-${yaf_ver}.tgz"
        download_file "${src_url}" "${target}"
    fi
}

download_php_yar() {
    if [ "${pecl_yar:-1}" == '1' ]; then
        local src_url="https://pecl.php.net/get/yar-${yar_ver}.tgz"
        local target="yar-${yar_ver}.tgz"
        download_file "${src_url}" "${target}"
    fi
}

download_php_swoole() {
    if [ "${pecl_swoole:-1}" == '1' ]; then
        local src_url="https://pecl.php.net/get/swoole-${swoole_ver}.tgz"
        local target="swoole-${swoole_ver}.tgz"
        download_file "${src_url}" "${target}"
    fi
}

download_php_xdebug() {
    if [ "${pecl_xdebug:-1}" == '1' ]; then
        local src_url="https://pecl.php.net/get/xdebug-${xdebug_ver}.tgz"
        local target="xdebug-${xdebug_ver}.tgz"
        download_file "${src_url}" "${target}"

        src_url="https://github.com/jokkedk/webgrind/archive/refs/tags/v1.9.4.tar.gz"
        target="webgrind-1.9.4.tgz"
        download_file "${src_url}" "${target}"
    fi
}

download_tomcat() {
    if [ "${tomcat_option:-1}" == '1' ]; then
        local src_url="https://dlcdn.apache.org/tomcat/tomcat-11/v${tomcat11_ver}/bin/apache-tomcat-${tomcat11_ver}.tar.gz"
        local target="apache-tomcat-${tomcat11_ver}.tar.gz"
        download_file "${src_url}" "${target}"

        src_url="https://dlcdn.apache.org/tomcat/tomcat-connectors/native/${tomcat_native_ver}/source/tomcat-native-${tomcat_native_ver}-src.tar.gz"
        target="tomcat-native-${tomcat_native_ver}-src.tar.gz"
        download_file "${src_url}" "${target}"
    fi
}

# https://github.com/redis/redis/archive/refs/tags/<version>.tar.gz
download_redis_server() {
    if [ "${redis_flag:-y}" == 'y' ]; then
        local src_url="https://github.com/redis/redis/archive/refs/tags/${redis_ver}.tar.gz"
        local target="redis-${redis_ver}.tar.gz"
        download_file "${src_url}" "${target}"
    fi
}

download_php_redis() {
    if [ "${pecl_redis:-1}" == '1' ]; then
        local src_url="https://pecl.php.net/get/redis-${pecl_redis_ver}.tgz"
        local target="redis-${pecl_redis_ver}.tgz"
        download_file "${src_url}" "${target}"
    fi
}

download_nodejs() {
    if [ "${nodejs_flag:-}" == 'y' ]; then
        local src_url="https://nodejs.org/dist/v${nodejs_ver}/node-v${nodejs_ver}-linux-${SYS_ARCH_n}.tar.gz"
        local target="node-v${nodejs_ver}-linux-${SYS_ARCH_n}.tar.gz"
        download_file "${src_url}" "${target}"
    fi
}

download_phpMyAdmin() {
    if [ "${phpmyadmin_flag}" == 'y' ]; then
        local src_url="https://files.phpmyadmin.net/phpMyAdmin/${phpmyadmin_ver}/phpMyAdmin-${phpmyadmin_ver}-all-languages.tar.gz"
        local target="phpMyAdmin-${phpmyadmin_ver}-all-languages.tar.gz"
        download_file "${src_url}" "${target}"
    fi
}

check_download() {
    ensure_dir "${CAINIAOTOOL_ROOT}/src"
    pushd "${CAINIAOTOOL_ROOT}/src" >/dev/null || retrun

    download_openssl
    download_icu
    download_jemalloc
    download_mysqldb
    download_caddy
    download_php
    download_pcre
    download_apache
    download_php_image_magick
    download_php_graphics_magick
    download_php_phalcon
    download_php_yaf
    download_php_yar
    download_php_swoole
    download_php_xdebug
    download_tomcat
    download_redis_server
    download_php_redis
    download_nodejs
    download_phpMyAdmin

    popd >/dev/null || return
}

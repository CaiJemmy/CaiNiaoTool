#!/bin/bash

source "${CAINIAOTOOL_ROOT}/lib/logging.sh"

if openssl version | grep -Eqi 'OpenSSL 1.0.2*'; then
    php83_with_openssl="--with-openssl"
    php84_with_openssl="--with-openssl"
    php85_with_openssl="--with-openssl"

    php83_with_ssl="--with-ssl"
    php84_with_ssl="--with-ssl"
    php85_with_ssl="--with-ssl"

    php83_with_curl="--with-curl"
    php84_with_curl="--with-curl"
    php85_with_curl="--with-curl"
elif openssl version | grep -Eqi 'OpenSSL 1.1.*'; then
    php83_with_openssl="--with-openssl"
    php84_with_openssl="--with-openssl"
    php85_with_openssl="--with-openssl"

    php83_with_ssl="--with-ssl"
    php84_with_ssl="--with-ssl"
    php85_with_ssl="--with-ssl"

    php83_with_curl="--with-curl"
    php84_with_curl="--with-curl"
    php85_with_curl="--with-curl"
    [[ ${php_option} =~ ^[1-4]$ ]] || [[ "${mphp_ver}" =~ ^5[3-6]$ ]] && with_old_openssl_flag=y
elif openssl version | grep -Eqi 'OpenSSL 3.*'; then
    php83_with_openssl="--with-openssl"
    php84_with_openssl="--with-openssl"
    php85_with_openssl="--with-openssl"

    php83_with_ssl="--with-ssl"
    php84_with_ssl="--with-ssl"
    php85_with_ssl="--with-ssl"

    php83_with_curl="--with-curl"
    php84_with_curl="--with-curl"
    php85_with_curl="--with-curl"
    [[ ${php_option:-14} =~ ^[1-9]$|^1[0-5]$ ]] || [[ "${mphp_ver}" =~ ^5[3-6]$|^70$ ]] && with_old_openssl_flag=y
else
    php83_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"
    php84_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"
    php85_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"

    php83_with_ssl="--with-ssl=${openssl_install_dir}"
    php84_with_ssl="--with-ssl=${openssl_install_dir}"
    php85_with_ssl="--with-ssl=${openssl_install_dir}"

    php83_with_curl="--with-curl=${curl_install_dir}"
    php84_with_curl="--with-curl=${curl_install_dir}"
    php85_with_curl="--with-curl=${curl_install_dir}"
    with_old_openssl_flag=y
fi

install_openSSL() {
    if [[ "${with_old_openssl_flag}" == 'y' ]]; then
        if [[ ! -e "${openssl_install_dir}/lib/libssl.a" && ! -e "${openssl_install_dir}/lib64/libssl.a" ]]; then
            pushd "${CAINIAOTOOL_ROOT}/src" >/dev/null || retrun
            log_exec tar xzf openssl-${openssl_ver}.tar.gz
            pushd openssl-${openssl_ver} >/dev/null || retrun
            log_exec ./config -Wl,-rpath=${openssl_install_dir}/lib -fPIC --prefix=${openssl_install_dir} --openssldir=${openssl_install_dir}
            log_exec make depend
            log_exec make -j ${THREAD}
            log_exec make install
            popd >/dev/null || return
            if [[ -f "${openssl_install_dir}/lib/libcrypto.a" || -f "${openssl_install_dir}/lib64/libcrypto.a" ]]; then
                log_info "openSSL installed successfully!"
                log_exec /bin/cp cacert.pem ${openssl_install_dir}/cert.pem
                log_exec rm -rf openssl-${openssl_ver}
            else
                log_error "openSSL install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
                kill -9 $$
                exit 1
            fi
            popd >/dev/null || return
        fi
    fi
}

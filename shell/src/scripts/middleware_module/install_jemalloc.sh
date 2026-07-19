#!/bin/bash

source "${CAINIAOTOOL_ROOT}/lib/logging.sh"

install_jemalloc() {
    if [[ ! -e "/usr/local/lib/libjemalloc.so" ]]; then
        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
        log_exec tar xjf jemalloc-${jemalloc_ver}.tar.bz2
        pushd jemalloc-${jemalloc_ver} >/dev/null
        log_exec ./configure
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null
        if [[ -f "/usr/local/lib/libjemalloc.so" ]]; then
            if [ "${Family}" == 'rhel' ]; then
                ln -s /usr/local/lib/libjemalloc.so.2 /usr/lib64/libjemalloc.so.1
            else
                ln -s /usr/local/lib/libjemalloc.so.2 /usr/lib/libjemalloc.so.1
            fi
            [ -z "$(grep /usr/local/lib /etc/ld.so.conf.d/*.conf)" ] && echo '/usr/local/lib' >/etc/ld.so.conf.d/local.conf
            ldconfig
            log_info "jemalloc module installed successfully!"
            rm -rf jemalloc-${jemalloc_ver}
        else
            log_error "jemalloc install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
            kill -9 $$
            exit 1
        fi
        popd >/dev/null
    fi
}

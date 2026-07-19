#!/bin/bash

install_caddy() {
    pushd ${CAINIAOTOOL_ROOT}/src >/dev/null

    if ! id -g ${run_group} >/dev/null 2>&1; then
        groupadd ${run_group}
    fi
    if ! id -u ${run_user} >/dev/null 2>&1; then
        useradd -g ${run_group} -M -s /sbin/nologin ${run_user}
    fi
    #unzip caddy_${caddy_ver}_linux_amd64.zip
    tar xzf caddy_${caddy_ver}_linux_amd64.tar.gz

    #move caddy to /usr/local/caddy/bin
    [ ! -d "${caddy_install_dir}/bin" ] && mkdir -p ${caddy_install_dir}/bin
    /bin/cp caddy ${caddy_install_dir}/bin

    chmod +x ${caddy_install_dir}/bin/caddy

    [ -z "$(grep ^'export PATH=' /etc/profile)" ] && echo "export PATH=${caddy_install_dir}/bin:\$PATH" >>/etc/profile
    [ -n "$(grep ^'export PATH=' /etc/profile)" -a -z "$(grep ${caddy_install_dir} /etc/profile)" ] && sed -i "s@^export PATH=\(.*\)@export PATH=${caddy_install_dir}/bin:\1@" /etc/profile
    . /etc/profile

    #make soft link
    # [ ! -L "/usr/local/bin/caddy" ] && ln -s ${caddy_install_dir}/bin/caddy /usr/local/bin/caddy

    #move caddyfile to /usr/local/caddy/conf
    [ ! -d "${caddy_install_dir}/conf/vhost" ] && mkdir -p ${caddy_install_dir}/conf/vhost
    /bin/cp "${CAINIAOTOOL_ROOT}/config/Caddyfile" "${caddy_install_dir}/conf/"
    sed -i "s@/usr/local/caddy@${caddy_install_dir}@g" ${caddy_install_dir}/conf/Caddyfile

    #move caddy.service to /lib/systemd/system
    /bin/cp "${CAINIAOTOOL_ROOT}/init.d/caddy.service" "/lib/systemd/system/"

    #modify caddy.service
    sed -i "s@/usr/local/caddy@${caddy_install_dir}@g" /lib/systemd/system/caddy.service

    #设置caddy开机启动
    systemctl enable caddy

    #reload systemd
    systemctl daemon-reload

    #start caddy service
    systemctl start caddy

    log_info "Caddy installed successfully!"
}

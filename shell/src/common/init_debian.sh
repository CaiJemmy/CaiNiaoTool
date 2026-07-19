#!/bin/bash

custom_profile() {
    cat >/etc/profile.d/cainiao.sh <<EOF
HISTSIZE=10000
PS1='\${debian_chroot:+(\$debian_chroot)}\\[\\e[1;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '
HISTTIMEFORMAT="%F %T \$(whoami) "

alias l='ls -AFhlt --color=auto'
alias lh='l | head'
alias ll='ls -l --color=auto'
alias ls='ls --color=auto'
alias vi=vim

GREP_OPTIONS="--color=auto"
alias grep='grep --color'
alias egrep='egrep --color'
alias fgrep='fgrep --color'
EOF

    # history
    sed -i '/^# End of file/,$d' ~/.bashrc
    cat >>~/.bashrc <<EOF
# End of file
EOF
    [ -z "$(grep history-timestamp ~/.bashrc)" ] && echo "PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });user=\$(whoami); echo \$(date \"+%Y-%m-%d %H:%M:%S\"):\$user:\`pwd\`/:\$msg ---- \$(who am i); } >> /tmp/\`hostname\`.\`whoami\`.history-timestamp'" >>~/.bashrc
    # /etc/hosts 这个需要看情况，云主机不需要做设置。
    # [ "$(hostname -i | awk '{print $1}')" != "127.0.0.1" ] && sed -i "s@127.0.0.1.*localhost@&\n127.0.0.1 $(hostname)@g" /etc/hosts
}

set_limits() {
    # /etc/security/limits.conf
    # 进程数限制
    #[ -e /etc/security/limits.d/*nproc.conf ] && rename nproc.conf nproc.conf_bk /etc/security/limits.d/*nproc.conf
    for file in /etc/security/limits.d/*nproc.conf; do
        rename "${file}" "${file}_bak"
    done

    # 确保 limits.conf 配置能够生效（通过 PAM 模块）
    [ -z "$(grep 'session required pam_limits.so' /etc/pam.d/common-session)" ] && echo "session required pam_limits.so" >>/etc/pam.d/common-session

    MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
    # 计算合理的限制
    if [ $MEM_MB -lt 1024 ]; then
        # 小于 1GB 内存
        MAX_PROC=4096
        MAX_FILE=65535
    elif [ $MEM_MB -lt 4096 ]; then
        # 1-4GB 内存
        MAX_PROC=16384
        MAX_FILE=131072
    elif [ $MEM_MB -lt 16384 ]; then
        # 4-16GB 内存
        MAX_PROC=65536
        MAX_FILE=262144
    else
        # 大于 16GB 内存
        MAX_PROC=262144
        MAX_FILE=524288
    fi

    sed -i '/^# End of file/,$d' /etc/security/limits.conf
    cat >>/etc/security/limits.conf <<EOF
# End of file
* soft nproc $MAX_PROC
* hard nproc $MAX_PROC
* soft nofile $MAX_FILE
* hard nofile $MAX_FILE
root soft nproc unlimited
root hard nproc unlimited
root soft nofile $MAX_FILE
root hard nofile $MAX_FILE
EOF
}

set_sysctl_conf() {
    # /etc/sysctl.conf，配置片段目录中配置参数，更容易维护
    [[ ! -f "/etc/sysctl.d/99-cainiao.conf" ]] && cat >/etc/sysctl.d/99-cainiao.conf <<EOF
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
EOF
    sysctl -p
}

set_other_conf() {
    sed -i 's@^"syntax on@syntax on@' /etc/vim/vimrc

    # Set timezone
    local localtime_file="$(readlink -f /etc/localtime)"
    if [[ ! "${localtime_file##*/}" == "Shanghai" ]]; then
        rm -rf /etc/localtime
        ln -s /usr/share/zoneinfo/${timezone} /etc/localtime
    fi

    # /etc/default/console-setup 是 控制台设置配置文件，主要用于配置 Linux 文本控制台（TTY）的字体、字符映射和键盘布局。
    # /etc/locale.gen 是 系统区域设置生成配置文件，用于定义系统支持哪些语言环境（locale）。它控制 locale-gen 命令生成哪些 locale 文件。
    # locale-gen：根据此文件生成 locale，文件包含注释掉的 locale 定义，取消注释并运行 locale-gen 后，系统会生成对应的 locale 文件
    # sed -i 's@^ACTIVE_CONSOLES.*@ACTIVE_CONSOLES="/dev/tty[1-2]"@' /etc/default/console-setup
    sed -i 's@^# en_US.UTF-8@en_US.UTF-8@' /etc/locale.gen
    #init q
    systemctl daemon-reload
}

set_dns() {
    # Set DNS
    cat >/etc/resolv.conf <<EOF
nameserver 114.114.114.114
nameserver 8.8.8.8
EOF
}
set_dns

set_ufw() {
    if [ "${firewall_flag:-n}" == 'y' ]; then
        ufw allow 22/tcp
        [ "${ssh_port}" != "22" ] && ufw allow ${ssh_port}/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw --force enable
    else
        ufw --force disable
    fi
}

post_set() {
    systemctl restart rsyslog ssh

    . /etc/profile
    . ~/.bashrc
}

main() {
    custom_profile
    set_limits
    set_sysctl_conf
    set_other_conf
    # set_dns
    set_ufw
    post_set
}

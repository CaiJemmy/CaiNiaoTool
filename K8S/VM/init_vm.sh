#!/bin/bash

echo=echo
for cmd in echo /bin/echo; do
  $cmd >/dev/null 2>&1 || continue
  if ! $cmd -e "" | grep -qE '^-e'; then
    echo=$cmd
    break
  fi
done
COLOR_ANSI=$($echo -e "\033[")

C_RESET="${COLOR_ANSI}0m"
COLOR_RED="${COLOR_ANSI}1;31m"
COLOR_GREEN="${COLOR_ANSI}1;32m"
COLOR_YELLOW="${COLOR_ANSI}1;33m"
COLOR_BLUE="${COLOR_ANSI}1;34m"
COLOR_MAGENTA="${COLOR_ANSI}1;35m"
COLOR_CYAN="${COLOR_ANSI}1;36m"
C_SUCCESS="$COLOR_GREEN"
C_FAILURE="$COLOR_RED"
C_QUESTION="$COLOR_MAGENTA"
C_WARNING="$COLOR_YELLOW"
C_MSG="$COLOR_CYAN"

[ "$(id -u)" -ne 0 ] && echo "${C_FAILURE}Error: This script must be run as the root user.${C_RESET}" && exit 1

validate_hostname() {
    local hostname=$1

    if [ ${#hostname} -gt 15 ]; then
        echo "错误：主机名长度不能超过 15 个字符。"
        return 1
    fi

    if echo "$hostname" | grep -Eq '^[a-zA-Z0-9][a-zA-Z0-9-]{0,13}[a-zA-Z0-9]$'; then
        return 0
    else
        echo "错误：主机名只能包含字母、数字和连字符，且不能以连字符开头或结尾。"
        return 1
    fi
}

is_valid_ipv4() {
    local check_ip=$1
    check_ip=$(echo "$check_ip" | grep -Eo '^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$')
    if [ -n "${check_ip}" ]; then
        return 0
    else
        return 1
    fi
}

set_vm_hostname() {
    echo '
    主机名要求：
    1、主机名只能包含字母、数字和连字符，且不能以连字符开头或结尾。
    2、主机名长度不能超过 15 个字符。
    '

    read -p "请输入主机名: " hostname

    if ! validate_hostname "$hostname"; then
        return 1
    fi

    if sudo hostnamectl set-hostname "$hostname"; then
        echo "主机名已成功设置为 $hostname。"
        return 0
    else
        echo "错误：设置主机名失败。"
        return 1
    fi
}

is_valid_ipv4() {
    local check_ip=$1
    check_ip=$(echo "$check_ip" | grep -Eo '^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$')
    if [ -n "${check_ip}" ]; then
        return 0
    else
        return 1
    fi
}

# 计算默认网关地址（x.x.x.2）
get_default_gateway() {
    local input_ip=$1
    local network="${input_ip%.*}"
    echo "${network}.2"
}

# 检查两个 IP 地址是否在同一网段
is_same_subnet() {
    local ip1=$1
    local ip2=$2
    local mask=${3:-24}  # 默认掩码为 24

    local subnet1=$(ipcalc -n "$ip1/$mask" | cut -d'=' -f2)
    local subnet2=$(ipcalc -n "$ip2/$mask" | cut -d'=' -f2)

    if [[ "$subnet1" == "$subnet2" ]]; then
        return 0
    else
        return 1
    fi
}

set_vm_ip_and_gateway() {
    echo '
    IP和网关要求：
    1、IP地址满足IPv4要求。
    2、IP地址默认24位掩码，默认值为输入网段的 x.x.x.2 IP，修改默认网关地址时，输入的IP要和IP地址在同一网段。
    '

    while true; do
        read -p "请输入 IP 地址（默认掩码为 24）：" ip
        if is_valid_ipv4 "$ip"; then
            break
        else
            echo "错误：IP 地址格式无效，请重新输入。"
        fi
    done

    default_gateway=$(get_default_gateway "$ip")
    echo "默认网关地址为：$default_gateway"

    while true; do
        read -p "请输入网关地址（默认为 $default_gateway）：" gateway
        if [ -z "$gateway" ]; then
            gateway=$default_gateway
            break
        elif ! is_valid_ipv4 "$gateway"; then
            echo "错误：网关地址格式无效，请重新输入。"
        elif ! is_same_subnet "$ip" "$gateway"; then
            echo "错误：网关地址必须与 IP 地址在同一网段，请重新输入。"
        else
            break
        fi
    done

    nmcli connection modify template_ens33 \
    ipv4.method manual \
    ipv4.addresses ${ip}/24 \
    ipv4.gateway $gateway \
    ipv4.dns "$gateway 8.8.8.8"

    echo "cat /etc/NetworkManager/system-connections/template_ens33.nmconnection"
    cat /etc/NetworkManager/system-connections/template_ens33.nmconnection

    ip a s
}

is_ip_duplicate() {
    local ip=$1
    local ips=("${@:2}")

    for existing_ip in "${ips[@]}"; do
        if [[ "$existing_ip" == "$ip" ]]; then
            echo "错误：IP 地址 $ip 不能重复。"
            return 1
        fi
    done

    return 0
}

is_hostname_duplicate() {
    local hostname=$1
    local hostnames=("${@:2}")

    for existing_hostname in "${hostnames[@]}"; do
        if [[ "$existing_hostname" == "$hostname" ]]; then
            echo "错误：主机名 $hostname 不能重复。"
            return 1
        fi
    done

    return 0
}

set_vm_hosts() {
    echo '
    默认3虚机的集群环境（1主2从：master01、worker01、worker02），hosts配置要求：
    1、需要输入三次IP 和 hostname，且三次ip 和 hostname 不能相同；
    2、IP地址满足IPv4要求；
    3、满足主机名要求。
    请输入 IP 地址和主机名，格式为：IP hostname
    例如：192.168.10.100 master01
    '

    declare -a ips       # 用于存储所有 IP
    declare -a hostnames # 用于存储所有主机名

    for i in {1..3}; do
        echo "请输入第 $i 组 IP 地址和主机名，格式为：IP hostname"
        read -p "请输入: " input

        local ip=$(echo "$input" | awk '{print $1}')
        local hostname=$(echo "$input" | awk '{print $2}')

        if ! is_valid_ipv4 "$ip"; then
            echo "错误：IP 地址 $ip 不符合 IPv4 格式。"
            return 1
        fi

        if ! validate_hostname "$hostname"; then
            return 1
        fi

        if ! is_ip_duplicate "$ip" "${ips[@]}"; then
            return 1
        fi

        if ! is_hostname_duplicate "$hostname" "${hostnames[@]}"; then
            return 1
        fi

        ips+=("$ip")
        hostnames+=("$hostname")
    done

    echo "设置 /etc/hosts"
    for i in "${!ips[@]}"; do
        echo "${ips[$i]} ${hostnames[$i]}" >> /etc/hosts
    done
    echo "设置后 /etc/hosts 内容如下："
    cat /etc/hosts

    return 0
}

load_br_netfilter() {
    echo "正在加载 br_netfilter 模块..."
    if modprobe br_netfilter; then
        echo "br_netfilter 模块加载成功。"
    else
        echo "错误：无法加载 br_netfilter 模块。"
        return 1
    fi

    if lsmod | grep -q br_netfilter; then
        echo "br_netfilter 模块已加载。"
    else
        echo "错误：br_netfilter 模块未加载。"
        return 1
    fi
}

apply_k8s_conf() {
    echo "正在应用 /etc/sysctl.d/k8s.conf 配置..."
    echo '
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 0
' > /etc/sysctl.d/k8s.conf

    if sysctl -p /etc/sysctl.d/k8s.conf; then
        echo "k8s.conf 配置应用成功。"
    else
        echo "错误：无法应用 k8s.conf 配置。"
        return 1
    fi
}

install_packages() {
    echo "正在安装 ipset 和 ipvsadm..."
    if apt-get update && apt-get install -y ipset ipvsadm; then
        echo "ipset 和 ipvsadm 安装成功。"
        return 0
    else
        echo "错误：无法安装 ipset 和 ipvsadm。"
        return 1
    fi
}

# 配置 ipvsadm 模块加载方式
configure_ipvsadm_modules() {
    echo "正在配置 ipvsadm 模块加载方式..."
    cat > /etc/ipvsadm.rules <<EOF
#!/bin/bash
modprobe -- br_netfilter
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
EOF

    # 授权并运行
    chmod 755 /etc/ipvsadm.rules && bash /etc/ipvsadm.rules

    # 检查模块是否加载
    if lsmod | grep -q -e ip_vs -e nf_conntrack; then
        echo "ipvsadm 模块加载成功。"
        return 0
    else
        echo "错误：ipvsadm 模块未加载。"
        return 1
    fi
}

# 创建并启用 systemd 服务
create_ipvsadm_service() {
    echo "正在创建并启用 ipvsadm systemd 服务..."
    cat > /etc/systemd/system/ipvsadm.service <<EOF
[Unit]
Description=IPVS Load Balancer
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/ipvsadm.rules
ExecStop=/sbin/ipvsadm -C
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # 启用并启动服务
    systemctl daemon-reload
    systemctl enable ipvsadm && systemctl start ipvsadm

    if systemctl is-active --quiet ipvsadm; then
        echo "ipvsadm 服务已成功启用并启动。"
        return 0
    else
        echo "错误：ipvsadm 服务未启动。"
        return 1
    fi
}

set_vm_k8s() {
    echo "是否加载 Kubernetes 网络配置？"
    read -p "请输入 [y/N]（默认不加载）: " choice

    # 默认不加载
    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        echo "用户选择不加载 Kubernetes 网络配置。"
        return 0
    fi

    echo "开始加载 Kubernetes 网络配置..."

    if ! load_br_netfilter; then
        echo "脚本执行 load_br_netfilter 失败。"
        return 1
    fi

    if ! apply_k8s_conf; then
        echo "脚本执行 apply_k8s_conf 失败。"
        return 1
    fi

    if ! install_packages; then
        echo "脚本执行 install_packages 失败。"
        return 1
    fi

    if ! configure_ipvsadm_modules; then
        echo "脚本执行 configure_ipvsadm_modules 失败。"
        return 1
    fi

    if ! create_ipvsadm_service; then
        echo "脚本执行 create_ipvsadm_service 失败。"
        return 1
    fi

    echo "Kubernetes 网络配置加载成功。"
}

set_vm_swap() {
    echo "swap 默认已关闭，是否开启？"
    read -p "请输入 [y/n]（默认不开启）: " choice

    # 默认不加载
    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        echo "用户选择不开启swap。如需开启，请在 /etc/fstab 配置文件打开swap相关配置即可。"
        return 0
    fi

    FSTAB_FILE="/etc/fstab"

    if [[ ! -f "$FSTAB_FILE" ]]; then
        echo "错误：文件 $FSTAB_FILE 不存在。"
        return 1
    fi

    # 使用 sed 命令打开最后两行的注释
    sed -i 's/^#\(.*swap.*\)/\1/; s/^#\(.*\/dev\/sr0.*\)/\1/' "$FSTAB_FILE"

    # 检查是否成功
    if grep -q '^UUID=.*swap' "$FSTAB_FILE" && grep -q '^/dev/sr0' "$FSTAB_FILE"; then
        echo "成功打开最后两行的注释。"
    else
        echo "错误：无法打开最后两行的注释。"
        return 1
    fi

    systemctl daemon-reload
    return 0
}

vm_reboot() {
    echo "${C_SUCCESS}配置完成，开始重启主机，主机重启后请重新登录。${C_RESET}"
    echo "K8S配置，重启后验证:"
    echo "网络配置：ping -c 2 master01 && ping -c 2 worker01 && ping -c 2 worker02"
    echo "模块加载：lsmod | grep -e ip_vs -e nf_conntrack -e br_netfilter"
    echo "K8S网桥：sysctl -a | egrep \"net.bridge.bridge-nf-call-ip|net.ipv4.ip_forward |vm.swappiness\""
    echo "swap分区：free -m"

    reboot
}

main() {
    echo "开始虚机配置 ..."

    ! set_vm_hostname && echo "${C_FAILURE}设置主机名失败，退出脚本。${C_RESET}" && exit 1

    ! set_vm_ip_and_gateway && echo "${C_FAILURE}设置IP 和 网关失败，退出脚本。${C_RESET}" && exit 1

    ! set_vm_hosts && echo "${C_FAILURE}设置 hosts 失败，退出脚本。${C_RESET}" && exit 1

    ! set_vm_k8s && echo "${C_FAILURE}设置 K8S 失败，退出脚本。${C_RESET}" && exit 1

    ! set_vm_swap && echo "${C_FAILURE}设置 swap 失败，退出脚本。${C_RESET}" && exit 1

    vm_reboot

    exit 0
}

main

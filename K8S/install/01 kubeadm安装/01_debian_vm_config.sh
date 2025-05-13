############################################################
# K8S 环境搭建时，主机配置
############################################################

# 虚机配置过程，已经提炼为shell脚本，参考 VM/init_vm.sh

# 配置root 账号可以直接登录
# vim /etc/ssh/sshd_config
PermitRootLogin yes
systemctl restart ssh


# 1、主机名配置
# master节点,名称为master1
hostnamectl set-hostname master01

# worker1节点,名称为worker1
hostnamectl set-hostname worker01

# worker2节点,名称为worker2
hostnamectl set-hostname worker02

# 2、主机IP地址配置
# master节点IP地址为：192.168.52.129/24
# vim /etc/network/interfaces  这个下面不要做配置，不生效
# 使用界面做的配置
# Debian 12 默认使用 NetworkManager 或 systemd-networkd 管理网络，而不是传统的 ifupdown 工具。
# 如果 NetworkManager 或 systemd-networkd 正在管理网络接口，/etc/network/interfaces 的配置会被忽略。

# 以下是排查过程
# NetworkManager 正在管理该接口
root@master01:~# nmcli device status
DEVICE  TYPE      STATE                   CONNECTION
ens33   ethernet  connected               Wired connection 1
lo      loopback  connected (externally)  lo

# 查看 systemd-networkd 是否启用
root@master01:~# systemctl status systemd-networkd
○ systemd-networkd.service - Network Configuration
     Loaded: loaded (/lib/systemd/system/systemd-networkd.service; disabled; preset: enabled)
     Active: inactive (dead)
TriggeredBy: ○ systemd-networkd.socket
       Docs: man:systemd-networkd.service(8)
             man:org.freedesktop.network1(5)

# NetworkManager 的配置文件位于 /etc/NetworkManager/system-connections/ 目录下。可以通过编辑配置文件来设置静态 IP。
# 方式1：修改以下部分：
cd /etc/NetworkManager/system-connections/
mv "Wired connection 1" master01_ens33.nmconnection

[ipv4]
method=manual
address1=192.168.52.129/24,192.168.52.2
dns=192.168.52.2;8.8.8.8;

# 运行以下命令重新加载配置：
sudo nmcli connection reload
sudo nmcli connection down master01_ens33
sudo nmcli connection up master01_ens33

# 方式2：命令修改以下部分：
cd /etc/NetworkManager/system-connections/
mv "Wired connection 1" master01_ens33.nmconnection
sudo nmcli connection reload

sudo nmcli connection modify master01_ens33 \
    ipv4.method manual \
    ipv4.addresses 192.168.52.129/24 \
    ipv4.gateway 192.168.52.2 \
    ipv4.dns "192.168.52.2 8.8.8.8"

# 激活连接
sudo nmcli connection down master01_ens33
sudo nmcli connection up master01_ens33
sudo nmcli connection down master01_ens33 && sudo nmcli connection up master01_ens33


# worker01 节点IP地址为：192.168.52.140/24
cd /etc/NetworkManager/system-connections/
mv "Wired connection 1" worker01_ens33.nmconnection
sudo nmcli connection reload

sudo nmcli connection modify worker01_ens33 \
    ipv4.method manual \
    ipv4.addresses 192.168.52.140/24 \
    ipv4.gateway 192.168.52.2 \
    ipv4.dns "192.168.52.2 8.8.8.8"

# 激活连接
sudo nmcli connection down worker01_ens33
sudo nmcli connection up worker01_ens33
sudo nmcli connection down worker01_ens33 && sudo nmcli connection up worker01_ens33

# worker02 节点IP地址为：192.168.52.141/24
cd /etc/NetworkManager/system-connections/
mv "Wired connection 1" worker02_ens33.nmconnection
sudo nmcli connection reload

sudo nmcli connection modify worker02_ens33 \
    ipv4.method manual \
    ipv4.addresses 192.168.52.141/24 \
    ipv4.gateway 192.168.52.2 \
    ipv4.dns "192.168.52.2 8.8.8.8"

# 激活连接
sudo nmcli connection down worker02_ens33
sudo nmcli connection up worker02_ens33
sudo nmcli connection down worker02_ens33 && sudo nmcli connection up worker02_ens33

# 3、主机名与IP地址解析
# 所有集群主机均需要进行配置。
# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.52.129 master01
192.168.52.140 worker01
192.168.52.141 worker02
# 验证： ping -c 4 master01 && ping -c 4 worker01 && ping -c 4 worker02

# 4、防火墙配置
# 所有主机均需要操作。
# 在 Debian 12 中，默认的防火墙工具是 nftables（替代了之前的 iptables）。以下是关闭防火墙和查看防火墙状态的命令：
# 检查 nftables 状态
sudo nft list ruleset

# 检查 firewalld 状态（如果安装了）
sudo firewall-cmd --state

# 检查 ufw 状态（如果安装了）
sudo ufw status

systemctl status nftables.service


# 5、SELINUX配置
# 所有主机均需要操作。修改SELinux配置需要重启操作系统。
# sed -ri 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
# 在 Debian 系统中，默认不安装 SELinux。
sudo aa-status
# 如果输出显示 apparmor module is loaded，表示 AppArmor 正在运行。
# 在 Debian 系统上安装 Kubernetes 时，通常不需要关闭 AppArmor。AppArmor 与 Kubernetes 和常见容器运行时兼容，
# 并提供额外的安全性。只有在特定情况下（如配置不当或兼容性问题）才需要关闭 AppArmor。

# 6、时间同步配置
# 所有主机均需要操作。最小化安装系统需要安装ntpdate软件。
# apt -y install ntpdate
crontab -l
0 */1 * * * /usr/sbin/ntpdate time1.aliyun.com

# 7、升级操作系统内核
# 所有主机均需要操作。


# 8、配置内核转发及网桥过滤
# 所有主机均需要操作。
# 添加网桥过滤及内核转发配置文件
# cat /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 0

# 加载br_netfilter模块
modprobe br_netfilter

# 查看是否加载
# lsmod | grep br_netfilter
br_netfilter           22256  0
bridge                151336  1 br_netfilter


# 加载网桥过滤及内核转发配置文件
# sysctl -p /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 0


# 9、安装ipset及ipvsadm
# 所有主机均需要操作。主要用于实现service转发。
# 安装ipset及ipvsadm
apt -y install ipset ipvsadm

# 配置ipvsadm模块加载方式
# 添加需要加载的模块
cat > /etc/ipvsadm.rules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
EOF

# 授权、运行、检查是否加载
chmod 755 /etc/ipvsadm.rules && bash /etc/ipvsadm.rules && lsmod | grep -e ip_vs -e nf_conntrack

vim /etc/systemd/system/ipvsadm.service
# 将启动内容拷贝
[Unit]
Description=IPVS Load Balancer
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ipvsadm-restore < /etc/ipvsadm.rules
ExecStop=/sbin/ipvsadm -C
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target

sudo systemctl enable ipvsadm
sudo systemctl start ipvsadm

sudo systemctl status ipvsadm


# 10、关闭SWAP分区
# 修改完成后需要重启操作系统，如不重启，可临时关闭，命令为swapoff -a

# 永远关闭swap分区，需要重启操作系统
# cat /etc/fstab
......

# /dev/mapper/centos-swap swap                    swap    defaults        0 0

# 在上一行中行首添加#


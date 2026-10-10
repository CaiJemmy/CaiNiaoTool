############################################################
# K8S 环境搭建时，主机配置
############################################################

# 虚机配置过程，centos，openEuler整体没有跑通

# 1、主机名配置
# master节点,名称为master1
hostnamectl set-hostname master01

# worker1节点,名称为worker1
hostnamectl set-hostname worker01

# worker2节点,名称为worker2
hostnamectl set-hostname worker02

# 2、主机IP地址配置
# master节点IP地址为：192.168.10.11/24
# vim /etc/sysconfig/network-scripts/ifcfg-ens33
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=ens33
UUID=07840657-c5e1-486c-9a91-0fc38dc3b76f
DEVICE=ens33
ONBOOT=yes
IPADDR=192.168.0.50
PREFIX=24
GATEWAY=192.168.0.1
DNS1=192.168.0.1
DNS2=8.8.8.8

# 使用 NetworkManager 管理网络
nmcli connection show
nmcli connection reload
nmcli connection down ens33
nmcli connection up ens33

# worker1节点IP地址为：192.168.10.12/24
# vim /etc/sysconfig/network-scripts/ifcfg-ens33
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=ens33
UUID=07840657-c5e1-486c-9a91-0fc38dc3b76f
DEVICE=ens33
ONBOOT=yes
IPADDR=192.168.0.60
PREFIX=24
GATEWAY=192.168.0.1
DNS1=192.168.0.1
DNS2=8.8.8.8

# worker2节点IP地址为：192.168.10.13/24
# vim /etc/sysconfig/network-scripts/ifcfg-ens33
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=ens33
UUID=07840657-c5e1-486c-9a91-0fc38dc3b76f
DEVICE=ens33
ONBOOT=yes
IPADDR=192.168.0.61
PREFIX=24
GATEWAY=192.168.0.1
DNS1=192.168.0.1
DNS2=8.8.8.8

# 3、主机名与IP地址解析
# 所有集群主机均需要进行配置。
# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.0.50 master01
192.168.0.60 worker01
192.168.0.61 worker02

# 4、防火墙配置
# 所有主机均需要操作。
# 关闭现有防火墙firewalld
systemctl disable firewalld
systemctl stop firewalld
firewall-cmd --state
not running

# 5、SELINUX配置
# 所有主机均需要操作。修改SELinux配置需要重启操作系统。
sed -ri 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# 6、时间同步配置
# 所有主机均需要操作。最小化安装系统需要安装ntpdate软件。
# yum install ntpdate
crontab -l
0 */1 * * * /usr/sbin/ntpdate time1.aliyun.com

# 7、升级操作系统内核
# 所有主机均需要操作。
# 导入 ELRepo 的 GPG key
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -qa gpg-pubkey*

cat /etc/yum.repos.d/openEuler.repo

# 清理缓存：
yum clean all
# 更新仓库：
yum makecache

# 下面这个步骤没有起作用，为什么？
# yum install --enablerepo=elrepo-kernel kernel-lt

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
yum -y install ipset ipvsadm

# 配置ipvsadm模块加载方式
# 添加需要加载的模块
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
EOF

# 授权、运行、检查是否加载
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack

# 10、关闭SWAP分区
# 修改完成后需要重启操作系统，如不重启，可临时关闭，命令为swapoff -a

# 永远关闭swap分区，需要重启操作系统
# cat /etc/fstab
......

# /dev/mapper/centos-swap swap                    swap    defaults        0 0

# 在上一行中行首添加#
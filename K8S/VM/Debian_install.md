# Debian 版本选择

> debian-12.10.0-amd64-DVD-1.iso


# 安装配置

> 4U4G 100GB 这个是模板，后期可以调整。
> 最小化安装

# 安装后设置

## 1、放开root登录

```shell
# vim /etc/ssh/sshd_config
PermitRootLogin yes
systemctl restart ssh
```

## 2、更新镜像源

```shell
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak

vi /etc/apt/sources.list

# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.aliyun.com/debian/ bookworm main contrib non-free non-free-firmware
# deb-src https://mirrors.aliyun.com/debian/ bookworm main contrib non-free non-free-firmware

deb https://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free non-free-firmware
# deb-src https://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free non-free-firmware

deb https://mirrors.aliyun.com/debian/ bookworm-backports main contrib non-free non-free-firmware
# deb-src https://mirrors.aliyun.com/debian/ bookworm-backports main contrib non-free non-free-firmware

deb https://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free non-free-firmware
# deb-src https://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free non-free-firmware


sudo apt update
sudo apt upgrade


如果遇到 GPG 密钥错误，可以运行以下命令导入密钥：
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys <密钥ID>
其中 <密钥ID> 是错误信息中提示的密钥 ID。
```

## 3、安装必要的软件包

```shell
apt -y install wget vim lrzsz ipcalc
```

## 4、关闭防火墙

```shell
# 在 Debian 12 中，默认的防火墙工具是 nftables（替代了之前的 iptables）。以下是关闭防火墙和查看防火墙状态的命令：
# 检查 nftables 状态
sudo nft list ruleset

# 检查 firewalld 状态（如果安装了）
sudo firewall-cmd --state

# 检查 ufw 状态（如果安装了）
sudo ufw status

systemctl status nftables.service
```

## 5、selinux关闭

```shell
# 所有主机均需要操作。修改SELinux配置需要重启操作系统。
# sed -ri 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
# 在 Debian 系统中，默认不安装 SELinux。
sudo aa-status
# 如果输出显示 apparmor module is loaded，表示 AppArmor 正在运行。
# 在 Debian 系统上安装 Kubernetes 时，通常不需要关闭 AppArmor。AppArmor 与 Kubernetes 和常见容器运行时兼容，
# 并提供额外的安全性。只有在特定情况下（如配置不当或兼容性问题）才需要关闭 AppArmor。
```

## 6、内核升级

> 通过 uname -r 检查内核版本，通过下面的命令进行升级

```shell
sudo apt update
sudo apt upgrade
```

## 7、时间同步配置

```shell
# 所有主机均需要操作。最小化安装系统需要安装ntpdate软件。
# apt -y install ntpdate
crontab -l
0 */1 * * * /usr/sbin/ntpdate time1.aliyun.com
```

## 8、主机配置调整

```shell
# 1、修改网卡配置，重点是删除uuid，并配置静态IP

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
mv "Wired connection 1" template_ens33.nmconnection

sed -i '/uuid=/d' template_ens33.nmconnection
sed -i 's/id=Wired connection 1/id=template_ens33/' template_ens33.nmconnection

sudo nmcli connection modify template_ens33 \
    ipv4.method manual \
    ipv4.addresses 192.168.52.130/24 \
    ipv4.gateway 192.168.52.2 \
    ipv4.dns "192.168.52.2 8.8.8.8"

[ipv4]
method=manual
address1=192.168.52.130/24,192.168.52.2
dns=192.168.52.2;8.8.8.8;

# 运行以下命令重新加载配置：
sudo nmcli connection reload
sudo nmcli connection down template_ens33
sudo nmcli connection up template_ens33
```

```shell
# 2、关闭swap分区
vim /etc/fstab
```

```shell
# 3、清理安装文件
sudo apt autoremove
sudo apt clean
sudo apt autoremove --purge
sudo journalctl --vacuum-time=1d

```
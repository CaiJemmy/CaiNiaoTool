# 放弃了，内核版本无法升级


# CentOS 版本选择

> CentOS-7-x86_64-DVD-1810.iso


# 安装配置

> 4U4G 100GB 这个是模板，后期可以调整。
> 最小化安装

# 安装后设置

## 1、关闭防火墙

```shell
systemctl stop firewalld
systemctl disable firewalld
firewall-cmd --state

not running
```

## 2、selinux关闭

```shell
vim /etc/selinux/config

SELINUX=disabled
```

## 3、内核升级

```shell
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
yum -y install https://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm

yum --enablerepo="elrepo-kernel" -y install kernel-lt.x86_64
```

## 1、安装必要的软件包

```shell
yum -y install wget vim net-tools lsrsz
```
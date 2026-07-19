############################################################
# K8S 环境搭建时，Docker配置
############################################################

# 所有集群主机均需操作。

# 1、获取YUM源
# 使用阿里云开源软件镜像站。这里使用的系统非主流，不需要配置，直接使用下面的yum命令安装docker就可以了。
# wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo

yum install -y docker

# 2、修改cgroup方式
# 在/etc/docker/daemon.json添加如下内容

# cat /etc/docker/daemon.json
{
        "exec-opts": ["native.cgroupdriver=systemd"]
}

# 3、重启docker
systemctl restart docker


# 4、cri-dockerd安装
# 安装go
wget https://golang.google.cn/dl/go1.24.2.linux-amd64.tar.gz
tar -xzf go1.24.2.linux-amd64.tar.gz -C /usr/local
添加环境变量
# cat /etc/profile
......
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# 加载/etc/profile文件
# source /etc/profile

# 创建gopath目录
# mkdir -p ~/go/bin ~/go/src ~/go/pkg

# 构建并安装cri-dockerd
wget https://github.com/Mirantis/cri-dockerd/archive/refs/tags/v0.3.17.tar.gz
tar -xzf v0.3.17.tar.gz
cd cri-dockerd-0.3.17
mkdir bin

# 配置代理
go env -w GOPROXY=https://goproxy.cn,direct

go get && go build -o ./bin/cri-dockerd

创建/usr/local/bin,默认存在时，可不用创建
# mkdir -p /usr/local/bin

安装cri-dockerd
# install -o root -g root -m 0755 bin/cri-dockerd /usr/local/bin/cri-dockerd

复制服务管理文件至/etc/systemd/system目录中
# cp -a packaging/systemd/* /etc/systemd/system

指定cri-dockerd运行位置
#sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service

启动服务
# systemctl daemon-reload
# systemctl enable cri-docker.service
# systemctl enable --now cri-docker.socket


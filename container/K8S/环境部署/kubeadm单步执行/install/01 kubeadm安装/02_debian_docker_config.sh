############################################################
# K8S 环境搭建时，Docker配置
############################################################

# 所有集群主机均需操作。
# https://docker.github.net.cn/engine/install/debian/#uninstall-docker-engine

# 1、获取配置
# https://developer.aliyun.com/mirror/docker-ce?spm=a2c6h.13651102.0.0.57e31b11LDVOCk
# step 1: 安装必要的一些系统工具
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg

# step 2: 信任 Docker 的 GPG 公钥
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Step 3: 写入软件源信息
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Step 4: 安装Docker
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 安装指定版本的Docker-CE:
# Step 1: 查找Docker-CE的版本:
# apt-cache madison docker-ce
#   docker-ce | 17.03.1~ce-0~ubuntu-xenial | https://mirrors.aliyun.com/docker-ce/linux/ubuntu xenial/stable amd64 Packages
#   docker-ce | 17.03.0~ce-0~ubuntu-xenial | https://mirrors.aliyun.com/docker-ce/linux/ubuntu xenial/stable amd64 Packages
# Step 2: 安装指定版本的Docker-CE: (VERSION例如上面的17.03.1~ce-0~ubuntu-xenial)
# sudo apt-get -y install docker-ce=[VERSION]


# 2、修改cgroup方式
# 在/etc/docker/daemon.json添加如下内容

# cat /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"]
}

# 3、重启docker
systemctl restart docker


# 4、cri-dockerd安装，不需要源码安装了，直接看下面第5步，使用包安装。
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

# 5、使用包进行安装 cri-dockerd
#
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.17/cri-dockerd_0.3.17.3-0.debian-bookworm_amd64.deb

dpkg -i cri-dockerd_0.3.17.3-0.debian-bookworm_amd64.deb

dpkg -l | grep cri-docker

sudo systemctl start cri-docker
sudo systemctl enable cri-docker

sudo systemctl status cri-docker

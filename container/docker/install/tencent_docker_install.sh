#!/usr/bin/env bash

#########################################
#
#
# https://docs.docker.com/engine/install/debian/
# https://cloud.tencent.com/document/product/213/46000#3urWMKkP_Vo0r04aD_bbX
#########################################

# 安装前先卸载历史安装
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-doc docker-buildx podman-docker containerd runc | cut -f1)

# 参考腾讯云安装步骤
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://mirrors.cloud.tencent.com/docker-ce/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://mirrors.cloud.tencent.com/docker-ce/linux/debian/ \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# 安装并查看docker信息
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl start docker
sudo docker info

# 加速器
# https://cloud.tencent.com/document/product/213/8623?ls=portal-generate&streamId=fd65788e-b9e0-4f06-92b1-2cb13ff788ad#.E4.BD.BF.E7.94.A8.E8.85.BE.E8.AE.AF.E4.BA.91.E9.95.9C.E5.83.8F.E6.BA.90.E5.8A.A0.E9.80.9F-docker

# 这个方法已经过时了，不生效
#sudo tee -a /etc/default/docker <<END
#DOCKER_OPTS="--registry-mirror=https://mirror.ccs.tencentyun.com"
#END

sudo tee /etc/docker/daemon.json <<END
{
   "registry-mirrors": [
   "https://mirror.ccs.tencentyun.com"
  ]
}
END

# 重新加载 Docker 守护进程配置
sudo systemctl reload docker

# 或者重启 Docker 服务（更彻底）
sudo systemctl restart docker


# 卸载完全步骤
#sudo apt purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
#sudo rm -rf /var/lib/docker
#sudo rm -rf /var/lib/containerd
#sudo rm /etc/apt/sources.list.d/docker.list
#sudo rm /etc/apt/keyrings/docker.asc
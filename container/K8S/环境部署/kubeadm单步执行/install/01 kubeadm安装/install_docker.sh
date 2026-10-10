#!/usr/bin/env bash

############################################################
# 安装 Docker
############################################################


print() {
    echo '
    马上开始 Docker 的安装，请确认是否开始安装。
    '
    read -p "请输入 [y/n]（默认不安装）: " choice

    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        echo "退出安装。"
        exit 0
    fi
}

unistall_docker() {
    sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras

    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
}

install_docker() {
    # step 1: 安装必要的一些系统工具
    sudo apt-get update
    sudo apt-get -y install ca-certificates curl gnupg

    # step 2: 信任 Docker 的 GPG 公钥
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Step 3: 写入软件源信息
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Step 4: 安装Docker
    sudo apt-get update
    sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

set_docker() {
    cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

    systemctl enable docker
    systemctl restart docker

    docker info | grep -i "Cgroup Driver"
}

install_cri_dockerd() {
    dpkg -i cri-dockerd_0.3.17.3-0.debian-bookworm_amd64.deb

    sed -i 's|/usr/bin/cri-dockerd |/usr/bin/cri-dockerd --pod-infra-container-image=registry.k8s.io/pause:3.9 |' /lib/systemd/system/cri-docker.service
    systemctl daemon-reload
    systemctl enable cri-docker
    systemctl restart cri-docker
}

main() {
    print

    unistall_docker
    install_docker
    set_docker
    install_cri_dockerd

    exit 0
}

main

#!/bin/bash
# harbor-install.sh - Harbor 快速安装脚本

set -e

HARBOR_VERSION="2.15.2"
HARBOR_HOSTNAME="harbor.example.com"
HARBOR_PASSWORD="Harbor12345"
INSTALL_DIR="/opt/harbor"

echo "=========================================="
echo "Harbor 快速安装脚本"
echo "版本: $HARBOR_VERSION"
echo "=========================================="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "错误: 请先安装 Docker"
    exit 1
fi

# 检查 Docker Compose
if ! docker compose version &> /dev/null; then
    echo "安装 Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# 检查 Harbor 是否已安装
if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/harbor.yml" ]; then
    echo ""
    echo "检测到 Harbor 已安装在 $INSTALL_DIR"
    echo "=========================================="

    # 检查是否有运行中的容器
    cd $INSTALL_DIR
    if sudo docker compose ps 2>/dev/null | grep -q "Up"; then
        echo "Harbor 容器正在运行"
        echo ""
        read -p "是否停止现有容器并重新安装？(y/N): " REINSTALL
        if [ "$REINSTALL" != "y" ] && [ "$REINSTALL" != "Y" ]; then
            echo "取消操作"
            exit 0
        fi

        echo "停止 Harbor 容器..."
        sudo docker compose down -v
    fi

    echo ""
    echo "重新执行 install.sh 进行配置更新..."
    sudo ./install.sh --with-trivy

    echo ""
    echo "=========================================="
    echo "Harbor 重新安装完成！"
    echo "=========================================="
    echo "访问地址: http://$(grep '^hostname:' harbor.yml | awk '{print $2}')"
    echo "用户名: admin"
    echo "密码: $(grep '^harbor_admin_password:' harbor.yml | awk '{print $2}')"
    echo ""
    echo "管理命令:"
    echo "  启动: cd $INSTALL_DIR && sudo docker compose up -d"
    echo "  停止: cd $INSTALL_DIR && sudo docker compose down"
    echo "  日志: cd $INSTALL_DIR && sudo docker compose logs -f"
    echo "=========================================="

    exit 0
fi

# 全新安装流程
echo ""
echo "开始全新安装 Harbor..."
echo ""

# 下载 Harbor
echo "下载 Harbor $HARBOR_VERSION..."
cd /tmp
if [ -f "harbor-offline-installer-v${HARBOR_VERSION}.tgz" ]; then
    echo "安装包已存在，跳过下载"
else
    wget -q --show-progress "https://github.com/goharbor/harbor/releases/download/v${HARBOR_VERSION}/harbor-offline-installer-v${HARBOR_VERSION}.tgz"
fi

# 解压
echo "解压安装包..."
sudo mkdir -p /opt
sudo tar xzf "harbor-offline-installer-v${HARBOR_VERSION}.tgz" -C /opt

# 配置
echo "配置 Harbor..."
cd $INSTALL_DIR
sudo cp harbor.yml.tmpl harbor.yml

sudo sed -i "s/hostname: .*/hostname: $HARBOR_HOSTNAME/" harbor.yml
sudo sed -i "s/harbor_admin_password: .*/harbor_admin_password: $HARBOR_PASSWORD/" harbor.yml
sudo sed -i 's/^https:/#https:/' harbor.yml
sudo sed -i 's/^  port: 443/#  port: 443/' harbor.yml
sudo sed -i 's/^  certificate:/#  certificate:/' harbor.yml
sudo sed -i 's/^  private_key:/#  private_key:/' harbor.yml

# 安装
echo "安装 Harbor..."
sudo ./install.sh --with-trivy

echo ""
echo "=========================================="
echo "Harbor 安装完成！"
echo "=========================================="
echo "访问地址: http://$HARBOR_HOSTNAME"
echo "用户名: admin"
echo "密码: $HARBOR_PASSWORD"
echo ""
echo "管理命令:"
echo "  启动: cd $INSTALL_DIR && sudo docker compose up -d"
echo "  停止: cd $INSTALL_DIR && sudo docker compose down"
echo "  日志: cd $INSTALL_DIR && sudo docker compose logs -f"
echo "  重装: cd $INSTALL_DIR && sudo ./install.sh --with-trivy"
echo "=========================================="

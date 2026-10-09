#!/bin/bash
# harbor-uninstall.sh - 根据 harbor-install.sh 编写的卸载脚本
# 注意：该脚本会删除 Harbor 的所有数据，请谨慎操作！

set -e

INSTALL_DIR="/opt/harbor"
HARBOR_TGZ_PATTERN="/tmp/harbor-online-installer-*.tgz"

echo "=========================================="
echo "Harbor 卸载脚本"
echo "=========================================="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "警告: Docker 未安装，请确认 Harbor 是否仍在运行。"
fi

# 检查 Harbor 安装目录
if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/harbor.yml" ]; then
    echo "未检测到 Harbor 安装（$INSTALL_DIR 下没有 harbor.yml）"
    echo "可能已经删除或未安装。"
    exit 0
fi

echo "检测到 Harbor 安装在 $INSTALL_DIR"
echo ""
read -p "确认卸载 Harbor？此操作将停止所有容器并永久删除数据卷！(y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "取消卸载"
    exit 0
fi

# 进入 Harbor 目录
cd "$INSTALL_DIR"

# 停止并删除 Harbor 容器、网络、数据卷
echo "- 停止 Harbor 容器并删除数据卷..."
if sudo docker compose down -v 2>/dev/null; then
    :
elif sudo docker-compose down -v 2>/dev/null; then
    :
else
    echo "  (无运行中的容器或 compose 异常，忽略)"
fi

# 删除 Harbor 安装目录
echo "- 删除安装目录 $INSTALL_DIR ..."
sudo rm -rf "$INSTALL_DIR"

# 删除下载的安装包
if ls $HARBOR_TGZ_PATTERN >/dev/null 2>&1; then
    read -p "是否删除已下载的 Harbor 安装包？(y/N): " DEL_TGZ
    if [ "$DEL_TGZ" = "y" ] || [ "$DEL_TGZ" = "Y" ]; then
        sudo rm -f $HARBOR_TGZ_PATTERN
        echo "  已删除安装包"
    fi
fi

# 可选删除 Docker 镜像
echo ""
read -p "是否同时删除 Harbor 相关 Docker 镜像（释放空间）？(y/N): " DEL_IMAGES
if [ "$DEL_IMAGES" = "y" ] || [ "$DEL_IMAGES" = "Y" ]; then
    echo "- 删除 Harbor 镜像..."
    IMAGES=$(sudo docker images -q goharbor/* 2>/dev/null || true)
    if [ -n "$IMAGES" ]; then
        sudo docker rmi -f $IMAGES
    else
        echo "  未找到 goharbor 镜像"
    fi
fi

echo ""
echo "=========================================="
echo "Harbor 卸载完成！"
echo "=========================================="
echo "已删除:"
echo "  - Harbor 容器和网络"
echo "  - Harbor 数据卷（包括数据库、证书、镜像数据）"
echo "  - 安装目录 $INSTALL_DIR"
echo ""
echo "如需彻底清理 Docker 资源，可手动执行:"
echo "  sudo docker system prune"
echo "=========================================="

#docker ps -a | grep harbor
#docker volume ls | grep harbor
#docker images | grep goharbor
#
#
## 删除残留容器（如果有）
#docker rm -f $(docker ps -aq | grep harbor)
#
## 删除残留卷
#docker volume rm $(docker volume ls -q | grep harbor)
#
## 删除残留镜像
#docker rmi -f $(docker images -q | grep goharbor)

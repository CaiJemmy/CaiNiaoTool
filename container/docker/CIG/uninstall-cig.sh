#!/bin/bash
# uninstall-cig.sh - CIG 监控栈卸载脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="docker-compose.yml"
echo "=========================================="
echo "CIG 监控栈卸载脚本"
echo "=========================================="

# 检查 Compose 文件
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "错误: 找不到 $COMPOSE_FILE"
    exit 1
fi

# 确认卸载
read -p "确认停止并删除 CIG 容器？(y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "取消卸载"
    exit 0
fi

# 停止并删除容器、网络
echo "- 停止并删除容器、网络..."
docker compose down

# 询问是否删除数据卷
echo ""
read -p "是否同时删除数据卷（influxdb-data、grafana-data）？这将丢失所有监控数据！(y/N): " DEL_VOLUMES
if [ "$DEL_VOLUMES" = "y" ] || [ "$DEL_VOLUMES" = "Y" ]; then
    echo "- 删除数据卷..."
    docker compose down -v
    echo "  数据卷已删除"
fi

# 询问是否删除镜像
echo ""
read -p "是否删除 CIG 相关 Docker 镜像？(y/N): " DEL_IMAGES
if [ "$DEL_IMAGES" = "y" ] || [ "$DEL_IMAGES" = "Y" ]; then
    echo "- 删除 Docker 镜像..."
    docker rmi -f \
        gcr.io/cadvisor/cadvisor:v0.49.1 \
        zcube/cadvisor:v0.49.1 \
        telegraf:latest \
        influxdb:1.8 \
        grafana/grafana:latest 2>/dev/null || true
    echo "  镜像已删除（或原本不存在）"
fi

# 询问是否删除配置文件
echo ""
read -p "是否删除 ./telegraf 和 ./grafana 配置目录？(y/N): " DEL_CONF
if [ "$DEL_CONF" = "y" ] || [ "$DEL_CONF" = "Y" ]; then
    echo "- 删除配置目录..."
    rm -rf ./telegraf ./grafana
    echo "  配置目录已删除"
fi

echo ""
echo "=========================================="
echo "CIG 监控栈卸载完成！"
echo "=========================================="
echo "如需彻底清理 Docker 资源："
echo "  sudo docker system prune"
echo "=========================================="

#!/bin/bash
# install-cig.sh - CIG 监控栈安装脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="docker-compose.yml"
echo "=========================================="
echo "CIG 监控栈安装脚本"
echo "=========================================="

# 1. 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "错误: 请先安装 Docker"
    exit 1
fi

# 2. 检查 Docker Compose
if ! docker compose version &> /dev/null; then
    echo "错误: 请安装 Docker Compose 插件"
    exit 1
fi

# 3. 检查 Compose 文件
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "错误: 找不到 $COMPOSE_FILE"
    exit 1
fi

# 4. 检查/生成 Telegraf 配置
if [ ! -f "./telegraf/telegraf.conf" ]; then
    echo "未找到 Telegraf 配置，正在生成默认配置..."
    mkdir -p ./telegraf
    cat > ./telegraf/telegraf.conf <<'EOF'
[agent]
  interval = "10s"
  flush_interval = "5s"

[[inputs.prometheus]]
  urls = ["http://cadvisor:8080/metrics"]
  name_prefix = "cadvisor_"

[[outputs.influxdb]]
  urls = ["http://influxdb:8086"]
  database = "cadvisor"
  username = "grafana"
  password = "grafana123"
EOF
    echo "已生成 ./telegraf/telegraf.conf"
fi

# 5. 检查/生成 Grafana provisioning
if [ ! -d "./grafana/provisioning" ]; then
    echo "未找到 Grafana provisioning，正在生成默认数据源配置..."
    mkdir -p ./grafana/provisioning/datasources
    cat > ./grafana/provisioning/datasources/influxdb.yaml <<'EOF'
apiVersion: 1
datasources:
  - name: InfluxDB
    type: influxdb
    access: proxy
    database: cadvisor
    user: grafana
    url: http://influxdb:8086
    secureJsonData:
      password: grafana123
EOF
    echo "已生成 ./grafana/provisioning/datasources/influxdb.yaml"
fi

# 6. 拉取镜像（失败时提示替换 gcr.io）
echo "正在拉取 Docker 镜像..."
if ! docker compose pull; then
    echo ""
    echo "⚠️  镜像拉取失败！"
    echo "如果 gcr.io 无法访问，请编辑 $COMPOSE_FILE"
    echo "将 cAdvisor 镜像:"
    echo "  image: gcr.io/cadvisor/cadvisor:v0.49.1"
    echo "替换为:"
    echo "  image: zcube/cadvisor:v0.49.1"
    echo ""
    read -p "替换后是否继续启动？(y/N): " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        echo "取消安装"
        exit 1
    fi
fi

# 7. 启动服务
echo "启动 CIG 服务..."
docker compose up -d

# 8. 等待启动并检查状态
echo "等待服务初始化..."
sleep 8
echo ""
echo "=========================================="
echo "CIG 监控栈启动完成！"
echo "=========================================="
docker compose ps
echo "=========================================="
echo "访问地址:"
echo "  Grafana : http://<服务器IP>:3000   账号: admin / admin"
echo "  cAdvisor: http://<服务器IP>:8080/metrics"
echo "  InfluxDB: http://<服务器IP>:8086"
echo "=========================================="

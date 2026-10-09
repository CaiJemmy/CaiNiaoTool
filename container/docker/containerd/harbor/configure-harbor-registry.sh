#!/bin/bash
# configure-harbor-registry.sh - 配置 Harbor 镜像仓库

set -e

HARBOR_HOST="harbor.example.com"
HARBOR_PROTOCOL="http"  # 或 https
SKIP_VERIFY="true"      # 如果是 https 自签名证书设为 true
CA_CERT_PATH=""         # CA 证书路径（https 时需要）

echo "=========================================="
echo "配置 containerd Harbor 镜像仓库"
echo "Harbor 地址: ${HARBOR_PROTOCOL}://${HARBOR_HOST}"
echo "=========================================="

# 创建配置目录
echo "创建配置目录..."
sudo mkdir -p /etc/containerd/certs.d/${HARBOR_HOST}

# 生成 hosts.toml
echo "生成 hosts.toml 配置..."
if [ "$HARBOR_PROTOCOL" = "http" ]; then
    # HTTP 配置
    sudo tee /etc/containerd/certs.d/${HARBOR_HOST}/hosts.toml > /dev/null <<EOF
server = "http://${HARBOR_HOST}"

[host."http://${HARBOR_HOST}"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF
else
    # HTTPS 配置
    if [ "$SKIP_VERIFY" = "true" ]; then
        sudo tee /etc/containerd/certs.d/${HARBOR_HOST}/hosts.toml > /dev/null <<EOF
server = "https://${HARBOR_HOST}"

[host."https://${HARBOR_HOST}"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF
    else
        if [ -z "$CA_CERT_PATH" ]; then
            echo "错误: HTTPS 模式需要提供 CA 证书路径"
            exit 1
        fi

        # 复制 CA 证书
        sudo cp "$CA_CERT_PATH" /etc/containerd/certs.d/${HARBOR_HOST}/ca.crt
        sudo chmod 644 /etc/containerd/certs.d/${HARBOR_HOST}/ca.crt

        sudo tee /etc/containerd/certs.d/${HARBOR_HOST}/hosts.toml > /dev/null <<EOF
server = "https://${HARBOR_HOST}"

[host."https://${HARBOR_HOST}"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = false
  ca = "/etc/containerd/certs.d/${HARBOR_HOST}/ca.crt"
EOF
    fi
fi

# 显示配置
echo ""
echo "配置文件内容:"
echo "=========================================="
cat /etc/containerd/certs.d/${HARBOR_HOST}/hosts.toml
echo "=========================================="

# 重启 containerd
echo ""
read -p "是否重启 containerd？(y/N): " RESTART
if [ "$RESTART" = "y" ] || [ "$RESTART" = "Y" ]; then
    echo "重启 containerd..."
    sudo systemctl restart containerd
    sudo systemctl status containerd --no-pager
    echo ""
    echo "containerd 已重启"
fi

echo ""
echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "测试命令:"
echo "  # 拉取镜像"
echo "  sudo ctr image pull ${HARBOR_HOST}/library/nginx:alpine"
echo ""
echo "  # 推送镜像"
echo "  sudo ctr image tag docker.io/library/nginx:alpine ${HARBOR_HOST}/library/nginx:alpine"
echo "  sudo ctr image push ${HARBOR_HOST}/library/nginx:alpine"
echo ""
echo "查看配置:"
echo "  cat /etc/containerd/certs.d/${HARBOR_HOST}/hosts.toml"
echo "=========================================="

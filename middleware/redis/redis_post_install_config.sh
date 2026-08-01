#!/usr/bin/env bash

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Redis 安装后配置脚本${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 检查是否为 root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}此脚本需要 root 权限${NC}"
    exit 1
fi

# 检查 Redis 是否安装
if ! command -v redis-server &> /dev/null; then
    echo -e "${RED}Redis 未安装${NC}"
    exit 1
fi

# 配置文件路径
REDIS_CONF="/etc/redis/redis.conf"
REDIS_CONF_BACKUP="${REDIS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"

# 备份原配置
echo -e "${YELLOW}备份原配置文件...${NC}"
cp $REDIS_CONF $REDIS_CONF_BACKUP
echo -e "${GREEN}✓ 已备份到: $REDIS_CONF_BACKUP${NC}"
echo ""

# ============================================
# 1. 设置密码
# ============================================
echo -e "${BLUE}【1/12】设置 Redis 密码${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 生成强密码
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# 设置密码
sed -i "s/^# requirepass .*/requirepass $REDIS_PASSWORD/" $REDIS_CONF
if ! grep -q "^requirepass" $REDIS_CONF; then
    echo "requirepass $REDIS_PASSWORD" >> $REDIS_CONF
fi

# 保存密码到文件
echo "$REDIS_PASSWORD" > /etc/redis/redis_password.txt
chmod 600 /etc/redis/redis_password.txt

echo -e "${GREEN}✓ 密码已设置${NC}"
echo -e "  密码: ${YELLOW}$REDIS_PASSWORD${NC}"
echo -e "  已保存到: /etc/redis/redis_password.txt"
echo ""

# ============================================
# 2. 配置绑定地址
# ============================================
echo -e "${BLUE}【2/12】配置绑定地址${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "选择绑定模式:"
echo "1) 仅本地访问 (127.0.0.1) - 最安全"
echo "2) 允许内网访问 (内网IP + 127.0.0.1)"
echo "3) 允许所有访问 (0.0.0.0) - 不推荐"
echo ""
read -p "请选择 [1-3, 默认 1]: " bind_choice
bind_choice=${bind_choice:-1}

case $bind_choice in
    1)
        sed -i "s/^bind .*/bind 127.0.0.1 ::1/" $REDIS_CONF
        echo -e "${GREEN}✓ 设置为仅本地访问${NC}"
        ;;
    2)
        # 获取内网 IP
        INTERNAL_IP=$(ip route get 1 | awk '{print \$7;exit}')
        sed -i "s/^bind .*/bind 127.0.0.1 $INTERNAL_IP/" $REDIS_CONF
        echo -e "${GREEN}✓ 设置为本地和内网访问 ($INTERNAL_IP)${NC}"
        ;;
    3)
        sed -i "s/^bind .*/bind 0.0.0.0/" $REDIS_CONF
        echo -e "${YELLOW}⚠ 设置为允许所有访问（请确保防火墙配置正确）${NC}"
        ;;
esac

# 关闭保护模式（如果设置了密码）
# sed -i "s/^protected-mode yes/protected-mode no/" $REDIS_CONF

echo ""

# ============================================
# 3. 禁用危险命令
# ============================================
echo -e "${BLUE}【3/12】禁用危险命令${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat >> $REDIS_CONF <<'DANGEREOF'

# 禁用危险命令
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command KEYS ""
rename-command CONFIG ""
rename-command SHUTDOWN ""
rename-command DEL ""
rename-command EVAL ""

# 如果需要使用这些命令，重命名为复杂名称
# rename-command FLUSHDB "FLUSHDB_MY_SECRET_NAME"
# rename-command CONFIG "CONFIG_MY_SECRET_NAME"
DANGEREOF

echo -e "${GREEN}✓ 已禁用危险命令: FLUSHDB, FLUSHALL, KEYS, CONFIG 等${NC}"
echo ""

# ============================================
# 4. 配置持久化
# ============================================
echo -e "${BLUE}【4/12】配置持久化${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "选择持久化策略:"
echo "1) RDB 快照 - 性能好，恢复快，可能丢失数据"
echo "2) AOF 日志 - 数据安全，性能稍差"
echo "3) RDB + AOF 混合 - 推荐"
echo ""
read -p "请选择 [1-3, 默认 3]: " persist_choice
persist_choice=${persist_choice:-3}

case $persist_choice in
    1)
        # 启用 RDB，禁用 AOF
        sed -i "s/^appendonly yes/appendonly no/" $REDIS_CONF
        sed -i "s/^# save /save /" $REDIS_CONF
        echo -e "${GREEN}✓ 使用 RDB 持久化${NC}"
        ;;
    2)
        # 禁用 RDB，启用 AOF
        sed -i "s/^save/#save/" $REDIS_CONF
        sed -i "s/^appendonly no/appendonly yes/" $REDIS_CONF
        sed -i "s/^# appendfsync everysec/appendfsync everysec/" $REDIS_CONF
        echo -e "${GREEN}✓ 使用 AOF 持久化${NC}"
        ;;
    3)
        # 启用混合持久化
        sed -i "s/^appendonly no/appendonly yes/" $REDIS_CONF
        sed -i "s/^# appendfsync everysec/appendfsync everysec/" $REDIS_CONF
        sed -i "s/^# aof-use-rdb-preamble no/aof-use-rdb-preamble yes/" $REDIS_CONF
        echo -e "${GREEN}✓ 使用 RDB + AOF 混合持久化（推荐）${NC}"
        ;;
esac

echo ""


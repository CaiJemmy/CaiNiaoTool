#!/bin/bash
# ==================================================
# MySQL 集群健康检查脚本
# ==================================================

set -e

MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-Root@123456}"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_mysql() {
    local host=\$1
    local role=\$2

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}检查 $host ($role)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 检查容器状态
    if ! docker ps | grep -q "$host"; then
        echo -e "${RED}❌ 容器未运行${NC}"
        return 1
    fi
    echo -e "${GREEN}✓${NC} 容器运行中"

    # 检查 MySQL 连接
    if ! docker exec $host mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent &> /dev/null; then
        echo -e "${RED}❌ MySQL 无法连接${NC}"
        return 1
    fi
    echo -e "${GREEN}✓${NC} MySQL 连接正常"

    # 检查复制状态
    if [ "$role" = "slave" ]; then
        local slave_status=$(docker exec $host mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G" 2>/dev/null)

        if [ -z "$slave_status" ]; then
            echo -e "${RED}❌ Slave 未配置${NC}"
            return 1
        fi

        local io_running=$(echo "$slave_status" | grep "Slave_IO_Running:" | awk '{print \$2}')
        local sql_running=$(echo "$slave_status" | grep "Slave_SQL_Running:" | awk '{print \$2}')
        local seconds_behind=$(echo "$slave_status" | grep "Seconds_Behind_Master:" | awk '{print \$2}')

        if [ "$io_running" = "Yes" ]; then
            echo -e "${GREEN}✓${NC} IO Thread 运行中"
        else
            echo -e "${RED}❌ IO Thread 未运行${NC}"
        fi

        if [ "$sql_running" = "Yes" ]; then
            echo -e "${GREEN}✓${NC} SQL Thread 运行中"
        else
            echo -e "${RED}❌ SQL Thread 未运行${NC}"
        fi

        if [ "$seconds_behind" != "NULL" ]; then
            if [ "$seconds_behind" -lt 10 ]; then
                echo -e "${GREEN}✓${NC} 复制延迟: ${seconds_behind}s"
            else
                echo -e "${YELLOW}⚠${NC} 复制延迟: ${seconds_behind}s (较高)"
            fi
        else
            echo -e "${RED}❌ 复制延迟: NULL (复制中断)${NC}"
        fi
    fi

    # 检查连接数
    local connections=$(docker exec $host mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -sN -e "SHOW STATUS LIKE 'Threads_connected';" | awk '{print \$2}')
    local max_connections=$(docker exec $host mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -sN -e "SHOW VARIABLES LIKE 'max_connections';" | awk '{print \$2}')
    local usage=$(( connections * 100 / max_connections ))

    echo -e "  连接数: $connections / $max_connections (${usage}%)"

    # 检查磁盘空间
    local disk_usage=$(docker exec $host df -h /var/lib/mysql | tail -1 | awk '{print \$5}')
    echo -e "  磁盘使用: $disk_usage"

    echo ""
}

# 主函数
main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}MySQL 集群健康检查${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    check_mysql "mysql-master" "master"
    check_mysql "mysql-slave1" "slave"
    check_mysql "mysql-slave2" "slave"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}健康检查完成${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"

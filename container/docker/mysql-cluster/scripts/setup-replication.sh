#!/bin/bash
# ==================================================
# MySQL 主从复制自动配置脚本
# ==================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-Root@123456}"
REPL_USER="repl"
REPL_PASSWORD="${REPL_PASSWORD:-Repl@123456}"
MASTER_HOST="mysql-master"
SLAVE1_HOST="mysql-slave1"
SLAVE2_HOST="mysql-slave2"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} \$1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} \$1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} \$1"
}

# 等待 MySQL 启动
wait_for_mysql() {
    local host=\$1
    local max_tries=30
    local count=0

    log_info "等待 $host MySQL 启动..."

    while [ $count -lt $max_tries ]; do
        if docker exec $(docker ps -qf "name=$host") mysqladmin ping -h localhost -uroot -p"$MYSQL_ROOT_PASSWORD" --silent &> /dev/null; then
            log_info "$host MySQL 已启动"
            return 0
        fi
        count=$((count + 1))
        sleep 2
    done

    log_error "$host MySQL 启动超时"
    return 1
}

# 在 Master 上创建复制用户
setup_master() {
    log_info "=== 配置 Master ==="

    docker exec mysql-master mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
        -- 创建复制用户
        CREATE USER IF NOT EXISTS '$REPL_USER'@'%' IDENTIFIED WITH mysql_native_password BY '$REPL_PASSWORD';
        GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%';

        -- 创建监控用户 (for ProxySQL/HAProxy)
        CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED WITH mysql_native_password BY 'Monitor@123456';
        GRANT REPLICATION CLIENT, PROCESS ON *.* TO 'monitor'@'%';

        -- 创建健康检查用户 (for HAProxy)
        CREATE USER IF NOT EXISTS 'haproxy_check'@'%';

        -- 刷新权限
        FLUSH PRIVILEGES;

        -- 重置 Master
        RESET MASTER;
EOSQL

    log_info "Master 配置完成"
}

# 配置 Slave
setup_slave() {
    local slave_host=\$1
    local slave_name=\$2

    log_info "=== 配置 $slave_name ==="

    # 获取 Master 状态
    log_info "获取 Master binlog 位置..."
    local master_status=$(docker exec mysql-master mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW MASTER STATUS\G")
    local binlog_file=$(echo "$master_status" | grep "File:" | awk '{print \$2}')
    local binlog_pos=$(echo "$master_status" | grep "Position:" | awk '{print \$2}')

    if [ -z "$binlog_file" ] || [ -z "$binlog_pos" ]; then
        log_error "无法获取 Master binlog 信息"
        return 1
    fi

    log_info "Master binlog: $binlog_file, Position: $binlog_pos"

    # 配置 Slave
    docker exec $slave_host mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
        -- 停止 Slave (如果正在运行)
        STOP SLAVE;

        -- 重置 Slave
        RESET SLAVE ALL;

        -- 配置 Master 信息 (传统方式)
        CHANGE MASTER TO
            MASTER_HOST='$MASTER_HOST',
            MASTER_PORT=3306,
            MASTER_USER='$REPL_USER',
            MASTER_PASSWORD='$REPL_PASSWORD',
            MASTER_LOG_FILE='$binlog_file',
            MASTER_LOG_POS=$binlog_pos,
            MASTER_CONNECT_RETRY=10,
            MASTER_RETRY_COUNT=3,
            GET_MASTER_PUBLIC_KEY=1;

        -- 启动 Slave
        START SLAVE;
EOSQL

    # 检查 Slave 状态
    sleep 3
    log_info "检查 $slave_name 复制状态..."

    local slave_status=$(docker exec $slave_host mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G")
    local io_running=$(echo "$slave_status" | grep "Slave_IO_Running:" | awk '{print \$2}')
    local sql_running=$(echo "$slave_status" | grep "Slave_SQL_Running:" | awk '{print \$2}')

    if [ "$io_running" = "Yes" ] && [ "$sql_running" = "Yes" ]; then
        log_info "$slave_name 复制配置成功！"
        return 0
    else
        log_error "$slave_name 复制配置失败"
        echo "$slave_status"
        return 1
    fi
}

# 使用 GTID 方式配置 Slave
setup_slave_gtid() {
    local slave_host=\$1
    local slave_name=\$2

    log_info "=== 使用 GTID 配置 $slave_name ==="

    docker exec $slave_host mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
        -- 停止 Slave
        STOP SLAVE;

        -- 重置 Slave
        RESET SLAVE ALL;

        -- 配置 Master 信息 (GTID 方式)
        CHANGE MASTER TO
            MASTER_HOST='$MASTER_HOST',
            MASTER_PORT=3306,
            MASTER_USER='$REPL_USER',
            MASTER_PASSWORD='$REPL_PASSWORD',
            MASTER_AUTO_POSITION=1,
            MASTER_CONNECT_RETRY=10,
            GET_MASTER_PUBLIC_KEY=1;

        -- 启动 Slave
        START SLAVE;
EOSQL

    # 检查状态
    sleep 3
    local slave_status=$(docker exec $slave_host mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G")
    local io_running=$(echo "$slave_status" | grep "Slave_IO_Running:" | awk '{print \$2}')
    local sql_running=$(echo "$slave_status" | grep "Slave_SQL_Running:" | awk '{print \$2}')

    if [ "$io_running" = "Yes" ] && [ "$sql_running" = "Yes" ]; then
        log_info "$slave_name GTID 复制配置成功！"
        echo "$slave_status" | grep -E "Retrieved_Gtid_Set|Executed_Gtid_Set"
        return 0
    else
        log_error "$slave_name GTID 复制配置失败"
        echo "$slave_status"
        return 1
    fi
}

# 验证复制
verify_replication() {
    log_info "=== 验证复制功能 ==="

    # 在 Master 创建测试表
    log_info "在 Master 创建测试数据..."
    docker exec mysql-master mysql -uroot -p"$MYSQL_ROOT_PASSWORD" testdb <<-EOSQL
        CREATE TABLE IF NOT EXISTS replication_test (
            id INT AUTO_INCREMENT PRIMARY KEY,
            data VARCHAR(100),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB;

        INSERT INTO replication_test (data) VALUES
            ('Test data 1'),
            ('Test data 2'),
            ('Test data 3');
EOSQL

    # 等待复制
    log_info "等待数据复制..."
    sleep 5

    # 在 Slave 检查数据
    log_info "检查 Slave1 数据..."
    local slave1_count=$(docker exec mysql-slave1 mysql -uroot -p"$MYSQL_ROOT_PASSWORD" testdb -sN -e "SELECT COUNT(*) FROM replication_test;")

    log_info "检查 Slave2 数据..."
    local slave2_count=$(docker exec mysql-slave2 mysql -uroot -p"$MYSQL_ROOT_PASSWORD" testdb -sN -e "SELECT COUNT(*) FROM replication_test;")

    if [ "$slave1_count" = "3" ] && [ "$slave2_count" = "3" ]; then
        log_info "✅ 复制验证成功！所有 Slave 数据一致"
        return 0
    else
        log_error "❌ 复制验证失败"
        log_error "Slave1 记录数: $slave1_count"
        log_error "Slave2 记录数: $slave2_count"
        return 1
    fi
}

# 显示复制状态
show_replication_status() {
    log_info "=== 复制状态摘要 ==="

    echo ""
    echo "=== Master Status ==="
    docker exec mysql-master mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW MASTER STATUS\G"

    echo ""
    echo "=== Slave1 Status ==="
    docker exec mysql-slave1 mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_Error"

    echo ""
    echo "=== Slave2 Status ==="
    docker exec mysql-slave2 mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_Error"
}

# 主函数
main() {
    log_info "开始配置 MySQL 主从复制..."

    # 等待所有 MySQL 实例启动
    wait_for_mysql "mysql-master" || exit 1
    wait_for_mysql "mysql-slave1" || exit 1
    wait_for_mysql "mysql-slave2" || exit 1

    # 配置 Master
    setup_master || exit 1

    # 选择复制方式
    if [ "${USE_GTID:-yes}" = "yes" ]; then
        log_info "使用 GTID 复制方式"
        setup_slave_gtid "mysql-slave1" "Slave1" || exit 1
        setup_slave_gtid "mysql-slave2" "Slave2" || exit 1
    else
        log_info "使用传统 binlog 复制方式"
        setup_slave "mysql-slave1" "Slave1" || exit 1
        setup_slave "mysql-slave2" "Slave2" || exit 1
    fi

    # 验证复制
    verify_replication || exit 1

    # 显示状态
    show_replication_status

    log_info "✅ MySQL 主从复制配置完成！"
}

# 执行主函数
main "$@"

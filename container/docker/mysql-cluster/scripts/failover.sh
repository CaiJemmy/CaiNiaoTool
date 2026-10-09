#!/bin/bash
# ==================================================
# MySQL 主从故障转移脚本
# 自动检测 Master 故障并提升 Slave 为新 Master
# ==================================================

set -e

# ============================================
# 配置变量
# ============================================
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-Root@123456}"
REPL_USER="repl"
REPL_PASSWORD="${REPL_PASSWORD:-Repl@123456}"

# 集群节点
MASTER_HOST="${MASTER_HOST:-mysql-master}"
SLAVE1_HOST="${SLAVE1_HOST:-mysql-slave1}"
SLAVE2_HOST="${SLAVE2_HOST:-mysql-slave2}"

# 检查参数
MAX_RETRIES="${MAX_RETRIES:-3}"
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"

# 日志文件
LOG_FILE="/var/log/mysql-failover.log"

# ============================================
# 颜色输出
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================
# 日志函数
# ============================================
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} [$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} [$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} [$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# ============================================
# 发送告警
# ============================================
send_alert() {
    local level="\$1"
    local message="\$2"

    log_info "发送 $level 级别告警: $message"

    # 钉钉告警
    if [ -n "$DINGTALK_WEBHOOK" ]; then
        local color="info"
        [ "$level" = "CRITICAL" ] && color="warning"

        curl -s "$DINGTALK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{
                \"msgtype\": \"markdown\",
                \"markdown\": {
                    \"title\": \"MySQL 故障转移告警\",
                    \"text\": \"### MySQL 故障转移告警\\n\\n**级别**: $level\\n\\n**消息**: $message\\n\\n**时间**: $(date)\\n\\n**集群**: Production\"
                }
            }" > /dev/null 2>&1
    fi

    # 邮件告警
    if [ -n "$ALERT_EMAIL" ]; then
        echo -e "MySQL Failover Alert\n\nLevel: $level\nMessage: $message\nTime: $(date)" | \
            mail -s "[MySQL Failover] $level: $message" "$ALERT_EMAIL"
    fi
}

# ============================================
# 检查 MySQL 是否存活
# ============================================
check_mysql_alive() {
    local host="\$1"
    local container_name="\$2"

    # 检查容器是否运行
    if ! docker ps | grep -q "$container_name"; then
        return 1
    fi

    # 检查 MySQL 是否响应
    if docker exec "$container_name" mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# ============================================
# 检查 Master 状态
# ============================================
check_master_status() {
    log_info "检查 Master 状态..."

    local retry=0
    while [ $retry -lt $MAX_RETRIES ]; do
        if check_mysql_alive "$MASTER_HOST" "mysql-master"; then
            log_info "Master 存活 (尝试 $((retry + 1))/$MAX_RETRIES)"
            return 0
        fi

        retry=$((retry + 1))
        log_warn "Master 无响应 (尝试 $retry/$MAX_RETRIES)"
        sleep "$CHECK_INTERVAL"
    done

    log_error "Master 确认故障"
    return 1
}

# ============================================
# 获取 Slave 复制延迟
# ============================================
get_slave_lag() {
    local slave_host="\$1"

    local slave_status=$(docker exec "$slave_host" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G" 2>/dev/null)

    if [ -z "$slave_status" ]; then
        echo "NULL"
        return
    fi

    local seconds_behind=$(echo "$slave_status" | grep "Seconds_Behind_Master:" | awk '{print \$2}')

    if [ -z "$seconds_behind" ] || [ "$seconds_behind" = "NULL" ]; then
        echo "NULL"
    else
        echo "$seconds_behind"
    fi
}

# ============================================
# 获取 Slave 的 GTID 执行位置
# ============================================
get_slave_executed_gtid() {
    local slave_host="\$1"

    docker exec "$slave_host" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -sN -e \
        "SELECT @@GLOBAL.gtid_executed;" 2>/dev/null || echo ""
}

# ============================================
# 选择最合适的 Slave 作为新 Master
# ============================================
select_new_master() {
    log_info "选择新的 Master..."

    # 检查 Slave1
    local slave1_alive=false
    local slave1_lag="NULL"
    local slave1_gtid=""

    if check_mysql_alive "$SLAVE1_HOST" "mysql-slave1"; then
        slave1_alive=true
        slave1_lag=$(get_slave_lag "mysql-slave1")
        slave1_gtid=$(get_slave_executed_gtid "mysql-slave1")
        log_info "Slave1: 存活=true, 延迟=${slave1_lag}s, GTID=$slave1_gtid"
    else
        log_warn "Slave1: 不可用"
    fi

    # 检查 Slave2
    local slave2_alive=false
    local slave2_lag="NULL"
    local slave2_gtid=""

    if check_mysql_alive "$SLAVE2_HOST" "mysql-slave2"; then
        slave2_alive=true
        slave2_lag=$(get_slave_lag "mysql-slave2")
        slave2_gtid=$(get_slave_executed_gtid "mysql-slave2")
        log_info "Slave2: 存活=true, 延迟=${slave2_lag}s, GTID=$slave2_gtid"
    else
        log_warn "Slave2: 不可用"
    fi

    # 决策逻辑
    if [ "$slave1_alive" = false ] && [ "$slave2_alive" = false ]; then
        log_error "所有 Slave 都不可用，无法进行故障转移"
        return 1
    fi

    # 选择延迟最小的 Slave
    local new_master=""
    local new_master_container=""

    if [ "$slave1_alive" = true ] && [ "$slave2_alive" = false ]; then
        new_master="$SLAVE1_HOST"
        new_master_container="mysql-slave1"
    elif [ "$slave1_alive" = false ] && [ "$slave2_alive" = true ]; then
        new_master="$SLAVE2_HOST"
        new_master_container="mysql-slave2"
    else
        # 两个都存活，比较延迟
        if [ "$slave1_lag" != "NULL" ] && [ "$slave2_lag" != "NULL" ]; then
            if [ "$slave1_lag" -le "$slave2_lag" ]; then
                new_master="$SLAVE1_HOST"
                new_master_container="mysql-slave1"
            else
                new_master="$SLAVE2_HOST"
                new_master_container="mysql-slave2"
            fi
        elif [ "$slave1_lag" != "NULL" ]; then
            new_master="$SLAVE1_HOST"
            new_master_container="mysql-slave1"
        else
            new_master="$SLAVE2_HOST"
            new_master_container="mysql-slave2"
        fi
    fi

    log_info "选定新 Master: $new_master ($new_master_container)"

    echo "$new_master_container"
}

# ============================================
# 提升 Slave 为 Master
# ============================================
promote_slave_to_master() {
    local new_master_container="\$1"

    log_info "========== 提升 $new_master_container 为新 Master =========="

    # 1. 停止复制
    log_info "停止 Slave 复制..."
    docker exec "$new_master_container" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "STOP SLAVE;" 2>/dev/null

    # 2. 重置 Slave 配置
    log_info "重置 Slave 配置..."
    docker exec "$new_master_container" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "RESET SLAVE ALL;" 2>/dev/null

    # 3. 禁用只读模式
    log_info "禁用只读模式..."
    docker exec "$new_master_container" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e \
        "SET GLOBAL read_only = OFF; SET GLOBAL super_read_only = OFF;" 2>/dev/null

    # 4. 重置 Master
    log_info "重置 Master binlog..."
    docker exec "$new_master_container" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "RESET MASTER;" 2>/dev/null

    # 5. 确认复制用户存在
    log_info "确认复制用户..."
    docker exec "$new_master_container" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
        CREATE USER IF NOT EXISTS '$REPL_USER'@'%' IDENTIFIED WITH mysql_native_password BY '$REPL_PASSWORD';
        GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%';
        FLUSH PRIVILEGES;
EOSQL

    log_info "✅ $new_master_container 已成功提升为新 Master"
}

# ============================================
# 重新配置其他 Slave
# ============================================
reconfigure_other_slaves() {
    local new_master="\$1"
    local new_master_container="\$2"

    log_info "========== 重新配置其他 Slave =========="

    # 获取新 Master 的 binlog 信息
    local master_status=$(docker exec "$new_master_container" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW MASTER STATUS\G" 2>/dev/null)
    local binlog_file=$(echo "$master_status" | grep "File:" | awk '{print \$2}')
    local binlog_pos=$(echo "$master_status" | grep "Position:" | awk '{print \$2}')

    log_info "新 Master binlog: $binlog_file, Position: $binlog_pos"

    # 重新配置每个 Slave
    for slave in "mysql-slave1" "mysql-slave2"; do
        if [ "$slave" = "$new_master_container" ]; then
            continue
        fi

        if ! check_mysql_alive "" "$slave"; then
            log_warn "$slave 不可用，跳过"
            continue
        fi

        log_info "重新配置 $slave..."

        docker exec "$slave" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
            STOP SLAVE;
            RESET SLAVE ALL;
            CHANGE MASTER TO
                MASTER_HOST='$new_master',
                MASTER_PORT=3306,
                MASTER_USER='$REPL_USER',
                MASTER_PASSWORD='$REPL_PASSWORD',
                MASTER_AUTO_POSITION=1,
                MASTER_CONNECT_RETRY=10,
                GET_MASTER_PUBLIC_KEY=1;
            START SLAVE;
EOSQL

        sleep 2

        # 检查复制状态
        local slave_status=$(docker exec "$slave" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G" 2>/dev/null)
        local io_running=$(echo "$slave_status" | grep "Slave_IO_Running:" | awk '{print \$2}')
        local sql_running=$(echo "$slave_status" | grep "Slave_SQL_Running:" | awk '{print \$2}')

        if [ "$io_running" = "Yes" ] && [ "$sql_running" = "Yes" ]; then
            log_info "✅ $slave 重新配置成功"
        else
            log_error "❌ $slave 重新配置失败"
            echo "$slave_status" | grep -E "Slave_IO_Running|Slave_SQL_Running|Last_Error"
        fi
    done
}

# ============================================
# 更新应用配置（可选）
# ============================================
update_application_config() {
    local new_master="\$1"

    log_info "========== 更新应用配置 =========="
    log_info "新 Master: $new_master"

    # 示例：更新 DNS 记录
    # 示例：更新配置中心
    # 示例：更新 HAProxy/ProxySQL 配置

    # 更新 ProxySQL 配置
    if docker ps | grep -q "proxysql"; then
        log_info "更新 ProxySQL 配置..."

        docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin <<-EOSQL
            UPDATE mysql_servers SET status='OFFLINE_HARD' WHERE hostname='$MASTER_HOST';
            UPDATE mysql_servers SET hostgroup_id=10 WHERE hostname='$new_master';
            LOAD MYSQL SERVERS TO RUNTIME;
            SAVE MYSQL SERVERS TO DISK;
EOSQL

        log_info "ProxySQL 配置已更新"
    fi

    log_info "应用配置更新完成（需要人工验证）"
}

# ============================================
# 执行故障转移
# ============================================
perform_failover() {
    log_info "=========================================="
    log_info "开始执行 MySQL 故障转移"
    log_info "=========================================="

    # 1. 确认 Master 故障
    if check_master_status; then
        log_info "Master 正常，无需故障转移"
        return 0
    fi

    log_error "Master 故障确认，开始故障转移..."
    send_alert "CRITICAL" "MySQL Master ($MASTER_HOST) 故障，开始自动故障转移"

    # 2. 选择新 Master
    local new_master_container=$(select_new_master)

    if [ -z "$new_master_container" ]; then
        log_error "无法选择新 Master，故障转移失败"
        send_alert "CRITICAL" "故障转移失败：无可用的 Slave"
        return 1
    fi

    local new_master_host=$(echo "$new_master_container" | sed 's/mysql-//')

    # 3. 提升 Slave 为 Master
    if ! promote_slave_to_master "$new_master_container"; then
        log_error "提升 Slave 失败"
        send_alert "CRITICAL" "故障转移失败：无法提升 $new_master_container 为 Master"
        return 1
    fi

    # 4. 重新配置其他 Slave
    reconfigure_other_slaves "$new_master_host" "$new_master_container"

    # 5. 更新应用配置
    update_application_config "$new_master_host"

    log_info "=========================================="
    log_info "故障转移完成"
    log_info "新 Master: $new_master_container"
    log_info "=========================================="

    send_alert "WARNING" "故障转移成功完成，新 Master: $new_master_container"

    return 0
}

# ============================================
# 手动故障转移（用于测试或计划内切换）
# ============================================
manual_failover() {
    local target_slave="\$1"

    if [ -z "$target_slave" ]; then
        log_error "请指定目标 Slave (slave1 或 slave2)"
        return 1
    fi

    local target_container="mysql-$target_slave"

    log_info "========== 手动故障转移到 $target_container =========="

    # 确认目标 Slave 可用
    if ! check_mysql_alive "" "$target_container"; then
        log_error "$target_container 不可用"
        return 1
    fi

    # 等待 Slave 同步完成
    log_info "等待 $target_container 同步完成..."

    local max_wait=60
    local waited=0

    while [ $waited -lt $max_wait ]; do
        local lag=$(get_slave_lag "$target_container")

        if [ "$lag" = "0" ]; then
            log_info "同步完成"
            break
        fi

        log_info "当前延迟: ${lag}s，等待中..."
        sleep 2
        waited=$((waited + 2))
    done

    # 执行切换
    promote_slave_to_master "$target_container"
    reconfigure_other_slaves "$target_slave" "$target_container"
    update_application_config "$target_slave"

    log_info "手动故障转移完成"
}

# ============================================
# 主函数
# ============================================
main() {
    case "${1:-auto}" in
        auto)
            perform_failover
            ;;
        manual)
            manual_failover "\$2"
            ;;
        check)
            check_master_status
            if [ $? -eq 0 ]; then
                echo "Master 正常"
            else
                echo "Master 故障"
            fi
            ;;
        *)
            echo "用法: \$0 {auto|manual <slave1|slave2>|check}"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"

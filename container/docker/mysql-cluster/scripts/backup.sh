#!/bin/bash
# ==================================================
# MySQL 自动备份脚本
# 支持全量备份、增量备份、定时备份
# ==================================================

set -e

# ============================================
# 配置变量
# ============================================
MYSQL_HOST="${MYSQL_HOST:-mysql-master}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_ROOT_PASSWORD:-Root@123456}"
BACKUP_DIR="${BACKUP_DIR:-/backup}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
BACKUP_TYPE="${BACKUP_TYPE:-full}"  # full, incremental, binlog

# 时间戳
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE=$(date +%Y%m%d)

# 备份目录结构
FULL_BACKUP_DIR="$BACKUP_DIR/full"
INCREMENTAL_BACKUP_DIR="$BACKUP_DIR/incremental"
BINLOG_BACKUP_DIR="$BACKUP_DIR/binlog"
LOG_DIR="$BACKUP_DIR/logs"

# 创建目录
mkdir -p "$FULL_BACKUP_DIR" "$INCREMENTAL_BACKUP_DIR" "$BINLOG_BACKUP_DIR" "$LOG_DIR"

# 日志文件
LOG_FILE="$LOG_DIR/backup_${DATE}.log"

# ============================================
# 日志函数
# ============================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" | tee -a "$LOG_FILE" >&2
}

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" | tee -a "$LOG_FILE"
}

# ============================================
# 错误处理
# ============================================
error_exit() {
    log_error "\$1"
    send_alert "备份失败: \$1"
    exit 1
}

# ============================================
# 发送告警（可集成钉钉、邮件等）
# ============================================
send_alert() {
    local message="\$1"
    log_info "发送告警: $message"

    # 示例：发送到钉钉
    if [ -n "$DINGTALK_WEBHOOK" ]; then
        curl -s "$DINGTALK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{
                \"msgtype\": \"text\",
                \"text\": {
                    \"content\": \"MySQL备份告警\\n$message\\n时间: $(date)\"
                }
            }" > /dev/null 2>&1
    fi

    # 示例：发送邮件
    if [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "MySQL Backup Alert" "$ALERT_EMAIL"
    fi
}

# ============================================
# 检查 MySQL 连接
# ============================================
check_mysql_connection() {
    log_info "检查 MySQL 连接..."

    if ! mysqladmin ping -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent; then
        error_exit "无法连接到 MySQL"
    fi

    log_info "MySQL 连接正常"
}

# ============================================
# 全量备份（使用 mysqldump）
# ============================================
full_backup_mysqldump() {
    log_info "========== 开始全量备份 (mysqldump) =========="

    local backup_file="$FULL_BACKUP_DIR/full_backup_${TIMESTAMP}.sql"
    local compressed_file="${backup_file}.gz"

    log_info "备份文件: $compressed_file"

    # 执行备份
    mysqldump \
        -h"$MYSQL_HOST" \
        -P"$MYSQL_PORT" \
        -u"$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --quick \
        --lock-tables=false \
        --master-data=2 \
        --flush-logs \
        --triggers \
        --routines \
        --events \
        --all-databases \
        2>> "$LOG_FILE" | gzip > "$compressed_file"

    if [ $? -eq 0 ]; then
        local backup_size=$(du -h "$compressed_file" | awk '{print \$1}')
        log_info "全量备份完成，文件大小: $backup_size"

        # 创建校验和
        md5sum "$compressed_file" > "${compressed_file}.md5"

        # 记录备份信息
        cat > "${compressed_file}.info" <<EOF
Backup Type: Full (mysqldump)
Backup Time: $(date)
MySQL Host: $MYSQL_HOST
Backup Size: $backup_size
Databases: ALL
EOF

        return 0
    else
        error_exit "全量备份失败"
    fi
}

# ============================================
# 全量备份（使用 XtraBackup）
# ============================================
full_backup_xtrabackup() {
    log_info "========== 开始全量备份 (XtraBackup) =========="

    # 检查 xtrabackup 是否安装
    if ! command -v xtrabackup &> /dev/null; then
        log_error "xtrabackup 未安装，降级使用 mysqldump"
        full_backup_mysqldump
        return $?
    fi

    local backup_dir="$FULL_BACKUP_DIR/xtrabackup_${TIMESTAMP}"
    mkdir -p "$backup_dir"

    log_info "备份目录: $backup_dir"

    # 执行 XtraBackup
    xtrabackup \
        --backup \
        --host="$MYSQL_HOST" \
        --port="$MYSQL_PORT" \
        --user="$MYSQL_USER" \
        --password="$MYSQL_PASSWORD" \
        --target-dir="$backup_dir" \
        --parallel=4 \
        2>> "$LOG_FILE"

    if [ $? -eq 0 ]; then
        # 压缩备份
        log_info "压缩备份文件..."
        tar -czf "${backup_dir}.tar.gz" -C "$FULL_BACKUP_DIR" "$(basename $backup_dir)"
        rm -rf "$backup_dir"

        local backup_size=$(du -h "${backup_dir}.tar.gz" | awk '{print \$1}')
        log_info "全量备份完成，文件大小: $backup_size"

        # 创建校验和
        md5sum "${backup_dir}.tar.gz" > "${backup_dir}.tar.gz.md5"

        return 0
    else
        error_exit "XtraBackup 全量备份失败"
    fi
}

# ============================================
# 增量备份（基于 binlog）
# ============================================
incremental_backup() {
    log_info "========== 开始增量备份 (binlog) =========="

    # 查找最新的全量备份
    local latest_full_backup=$(ls -t "$FULL_BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1)

    if [ -z "$latest_full_backup" ]; then
        log_info "未找到全量备份，执行全量备份"
        full_backup_mysqldump
        return $?
    fi

    log_info "基于全量备份: $(basename $latest_full_backup)"

    # 获取当前 binlog 信息
    local binlog_info=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW MASTER STATUS\G" 2>/dev/null)
    local current_binlog=$(echo "$binlog_info" | grep "File:" | awk '{print \$2}')
    local current_pos=$(echo "$binlog_info" | grep "Position:" | awk '{print \$2}')

    if [ -z "$current_binlog" ]; then
        error_exit "无法获取 binlog 信息"
    fi

    log_info "当前 binlog: $current_binlog, Position: $current_pos"

    # 备份增量目录
    local incr_backup_dir="$INCREMENTAL_BACKUP_DIR/${DATE}"
    mkdir -p "$incr_backup_dir"

    # 复制 binlog 文件
    local binlog_dir="/var/lib/mysql"  # MySQL binlog 目录

    # 获取所有 binlog 文件
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW BINARY LOGS" | tail -n +2 | awk '{print \$1}' | while read binlog_file; do
        if [ -f "$binlog_dir/$binlog_file" ]; then
            cp "$binlog_dir/$binlog_file" "$incr_backup_dir/"
            log_info "已备份 binlog: $binlog_file"
        fi
    done

    # 压缩增量备份
    tar -czf "${incr_backup_dir}.tar.gz" -C "$INCREMENTAL_BACKUP_DIR" "$(basename $incr_backup_dir)"
    rm -rf "$incr_backup_dir"

    log_info "增量备份完成"
}

# ============================================
# 备份单个数据库
# ============================================
backup_single_database() {
    local database="\$1"

    log_info "========== 备份数据库: $database =========="

    local backup_file="$FULL_BACKUP_DIR/${database}_${TIMESTAMP}.sql.gz"

    mysqldump \
        -h"$MYSQL_HOST" \
        -P"$MYSQL_PORT" \
        -u"$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --quick \
        --lock-tables=false \
        --triggers \
        --routines \
        --events \
        "$database" \
        2>> "$LOG_FILE" | gzip > "$backup_file"

    if [ $? -eq 0 ]; then
        log_info "数据库 $database 备份完成"
        return 0
    else
        error_exit "数据库 $database 备份失败"
    fi
}

# ============================================
# 备份表结构（schema only）
# ============================================
backup_schema_only() {
    log_info "========== 备份表结构 =========="

    local schema_file="$FULL_BACKUP_DIR/schema_${TIMESTAMP}.sql.gz"

    mysqldump \
        -h"$MYSQL_HOST" \
        -P"$MYSQL_PORT" \
        -u"$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --no-data \
        --triggers \
        --routines \
        --events \
        --all-databases \
        2>> "$LOG_FILE" | gzip > "$schema_file"

    if [ $? -eq 0 ]; then
        log_info "表结构备份完成"
        return 0
    else
        error_exit "表结构备份失败"
    fi
}

# ============================================
# 清理过期备份
# ============================================
cleanup_old_backups() {
    log_info "========== 清理过期备份 =========="

    log_info "清理 $RETENTION_DAYS 天前的备份文件"

    # 清理全量备份
    find "$FULL_BACKUP_DIR" -type f -name "*.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \;
    find "$FULL_BACKUP_DIR" -type f -name "*.md5" -mtime +$RETENTION_DAYS -exec rm -f {} \;
    find "$FULL_BACKUP_DIR" -type f -name "*.info" -mtime +$RETENTION_DAYS -exec rm -f {} \;

    # 清理增量备份
    find "$INCREMENTAL_BACKUP_DIR" -type f -name "*.tar.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \;

    # 清理日志
    find "$LOG_DIR" -type f -name "*.log" -mtime +$RETENTION_DAYS -exec rm -f {} \;

    log_info "清理完成"
}

# ============================================
# 验证备份完整性
# ============================================
verify_backup() {
    local backup_file="\$1"

    log_info "验证备份文件: $(basename $backup_file)"

    # 检查文件是否存在
    if [ ! -f "$backup_file" ]; then
        log_error "备份文件不存在"
        return 1
    fi

    # 检查文件大小
    local file_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null)
    if [ "$file_size" -lt 1000 ]; then
        log_error "备份文件太小 ($file_size bytes)，可能不完整"
        return 1
    fi

    # 验证 gzip 文件完整性
    if [[ "$backup_file" == *.gz ]]; then
        if ! gzip -t "$backup_file" 2>> "$LOG_FILE"; then
            log_error "gzip 文件损坏"
            return 1
        fi
    fi

    # 验证 MD5
    if [ -f "${backup_file}.md5" ]; then
        if md5sum -c "${backup_file}.md5" > /dev/null 2>&1; then
            log_info "MD5 校验通过"
        else
            log_error "MD5 校验失败"
            return 1
        fi
    fi

    log_info "备份文件验证通过"
    return 0
}

# ============================================
# 上传备份到远程存储（可选）
# ============================================
upload_to_remote() {
    local backup_file="\$1"

    log_info "========== 上传备份到远程存储 =========="

    # AWS S3 示例
    if [ -n "$AWS_S3_BUCKET" ]; then
        log_info "上传到 S3: $AWS_S3_BUCKET"

        if command -v aws &> /dev/null; then
            aws s3 cp "$backup_file" "s3://$AWS_S3_BUCKET/mysql-backups/$(basename $backup_file)" \
                --storage-class STANDARD_IA \
                >> "$LOG_FILE" 2>&1

            if [ $? -eq 0 ]; then
                log_info "上传到 S3 成功"
            else
                log_error "上传到 S3 失败"
            fi
        else
            log_error "aws cli 未安装"
        fi
    fi

    # 阿里云 OSS 示例
    if [ -n "$ALIYUN_OSS_BUCKET" ]; then
        log_info "上传到 OSS: $ALIYUN_OSS_BUCKET"

        if command -v ossutil &> /dev/null; then
            ossutil cp "$backup_file" "oss://$ALIYUN_OSS_BUCKET/mysql-backups/$(basename $backup_file)" \
                >> "$LOG_FILE" 2>&1

            if [ $? -eq 0 ]; then
                log_info "上传到 OSS 成功"
            else
                log_error "上传到 OSS 失败"
            fi
        else
            log_error "ossutil 未安装"
        fi
    fi

    # SFTP 示例
    if [ -n "$SFTP_HOST" ] && [ -n "$SFTP_USER" ]; then
        log_info "上传到 SFTP: $SFTP_HOST"

        scp "$backup_file" "${SFTP_USER}@${SFTP_HOST}:/backups/mysql/" >> "$LOG_FILE" 2>&1

        if [ $? -eq 0 ]; then
            log_info "上传到 SFTP 成功"
        else
            log_error "上传到 SFTP 失败"
        fi
    fi
}

# ============================================
# 生成备份报告
# ============================================
generate_backup_report() {
    log_info "========== 生成备份报告 =========="

    local report_file="$BACKUP_DIR/backup_report_${DATE}.txt"

    cat > "$report_file" <<EOF
========================================
MySQL 备份报告
========================================
备份时间: $(date)
MySQL 主机: $MYSQL_HOST:$MYSQL_PORT
备份类型: $BACKUP_TYPE

========================================
全量备份列表
========================================
$(ls -lh "$FULL_BACKUP_DIR"/*.gz 2>/dev/null | tail -10 || echo "无")

========================================
增量备份列表
========================================
$(ls -lh "$INCREMENTAL_BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -10 || echo "无")

========================================
磁盘使用情况
========================================
$(df -h "$BACKUP_DIR")

========================================
备份目录大小
========================================
全量备份: $(du -sh "$FULL_BACKUP_DIR" 2>/dev/null | awk '{print \$1}')
增量备份: $(du -sh "$INCREMENTAL_BACKUP_DIR" 2>/dev/null | awk '{print \$1}')
总大小: $(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print \$1}')

========================================
最新备份文件
========================================
$(ls -lt "$FULL_BACKUP_DIR"/*.gz 2>/dev/null | head -1)

========================================
EOF

    cat "$report_file"
    log_info "备份报告已生成: $report_file"
}

# ============================================
# 主函数
# ============================================
main() {
    log_info "=========================================="
    log_info "MySQL 备份开始"
    log_info "=========================================="
    log_info "备份类型: $BACKUP_TYPE"
    log_info "备份目录: $BACKUP_DIR"
    log_info "保留天数: $RETENTION_DAYS"
    log_info ""

    # 检查 MySQL 连接
    check_mysql_connection

    # 根据备份类型执行相应操作
    case "$BACKUP_TYPE" in
        full)
            if command -v xtrabackup &> /dev/null && [ "${USE_XTRABACKUP:-no}" = "yes" ]; then
                full_backup_xtrabackup
            else
                full_backup_mysqldump
            fi
            BACKUP_FILE=$(ls -t "$FULL_BACKUP_DIR"/*.gz 2>/dev/null | head -1)
            ;;
        incremental)
            incremental_backup
            BACKUP_FILE=$(ls -t "$INCREMENTAL_BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
            ;;
        schema)
            backup_schema_only
            BACKUP_FILE=$(ls -t "$FULL_BACKUP_DIR"/schema_*.gz 2>/dev/null | head -1)
            ;;
        database)
            if [ -z "$DATABASE_NAME" ]; then
                error_exit "未指定数据库名称 (DATABASE_NAME)"
            fi
            backup_single_database "$DATABASE_NAME"
            BACKUP_FILE=$(ls -t "$FULL_BACKUP_DIR"/${DATABASE_NAME}_*.gz 2>/dev/null | head -1)
            ;;
        *)
            error_exit "未知的备份类型: $BACKUP_TYPE"
            ;;
    esac

    # 验证备份
    if [ -n "$BACKUP_FILE" ]; then
        verify_backup "$BACKUP_FILE" || error_exit "备份验证失败"

        # 上传到远程存储
        if [ "${UPLOAD_REMOTE:-no}" = "yes" ]; then
            upload_to_remote "$BACKUP_FILE"
        fi
    fi

    # 清理过期备份
    cleanup_old_backups

    # 生成备份报告
    generate_backup_report

    log_info ""
    log_info "=========================================="
    log_info "MySQL 备份完成"
    log_info "=========================================="

    # 发送成功通知
    send_alert "MySQL 备份成功完成 (类型: $BACKUP_TYPE)"
}

# 执行主函数
main "$@"

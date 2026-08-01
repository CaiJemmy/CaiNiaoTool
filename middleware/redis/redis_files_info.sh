#!/bin/bash

#######################################################################################
#
#
#
#
#
#
#
#######################################################################################

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Redis Server 完整文件清单${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 检查是否安装
if ! dpkg -l | grep -q redis-server; then
    echo -e "${YELLOW}Redis Server 未安装${NC}"
    exit 1
fi

# 1. 可执行文件
echo -e "${BLUE}【1】可执行文件${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for bin in redis-server redis-sentinel redis-cli redis-benchmark redis-check-aof redis-check-rdb; do
    if [ -f "/usr/bin/$bin" ]; then
        size=$(ls -lh /usr/bin/$bin | awk '{print $5}')
        version=$(/usr/bin/$bin --version 2>/dev/null | head -1 || echo "N/A")
        printf "%-25s %8s  %s\n" "/usr/bin/$bin" "$size" "$version"
    fi
done
echo ""

# 2. 配置文件
echo -e "${BLUE}【2】配置文件${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for conf in /etc/redis/redis.conf /etc/redis/sentinel.conf /etc/default/redis-server; do
    if [ -f "$conf" ]; then
        size=$(ls -lh "$conf" | awk '{print $5}')
        lines=$(wc -l < "$conf")
        printf "%-35s %8s  %5s 行\n" "$conf" "$size" "$lines"
    fi
done
echo ""

# 3. Systemd 服务
echo -e "${BLUE}【3】Systemd 服务文件${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for service in /lib/systemd/system/redis*.service; do
    if [ -f "$service" ]; then
        status=$(systemctl is-active $(basename $service) 2>/dev/null || echo "inactive")
        enabled=$(systemctl is-enabled $(basename $service) 2>/dev/null || echo "disabled")
        printf "%-50s [%s] [%s]\n" "$service" "$status" "$enabled"
    fi
done
echo ""

# 4. 数据目录
echo -e "${BLUE}【4】数据目录${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "/var/lib/redis" ]; then
    echo "/var/lib/redis/"
    ls -lhA /var/lib/redis/ 2>/dev/null | tail -n +2 | while read line; do
        echo "  $line"
    done
    echo ""
    du -sh /var/lib/redis/ 2>/dev/null
else
    echo "数据目录不存在"
fi
echo ""

# 5. 日志目录
echo -e "${BLUE}【5】日志目录${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "/var/log/redis" ]; then
    echo "/var/log/redis/"
    ls -lhA /var/log/redis/ 2>/dev/null | tail -n +2 | while read line; do
        echo "  $line"
    done
    echo ""
    if [ -f "/var/log/redis/redis-server.log" ]; then
        lines=$(wc -l < /var/log/redis/redis-server.log 2>/dev/null)
        echo "日志行数: $lines"
    fi
else
    echo "日志目录不存在"
fi
echo ""

# 6. 运行时文件
echo -e "${BLUE}【6】运行时文件${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for runfile in /run/redis/redis-server.pid /run/redis/redis.sock /var/run/redis/redis-server.pid; do
    if [ -e "$runfile" ]; then
        ls -lh "$runfile"
    fi
done
if systemctl is-active --quiet redis-server; then
    pid=$(cat /run/redis/redis-server.pid 2>/dev/null || pgrep redis-server)
    echo ""
    echo "Redis Server PID: $pid"
    if [ -n "$pid" ]; then
        echo "进程信息:"
        ps aux | grep -E "PID|$pid" | grep -v grep
    fi
fi
echo ""

# 7. 用户和组
echo -e "${BLUE}【7】用户和组${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
id redis 2>/dev/null || echo "redis 用户不存在"
echo ""

# 8. 权限信息
echo -e "${BLUE}【8】关键目录权限${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for dir in /etc/redis /var/lib/redis /var/log/redis /run/redis; do
    if [ -d "$dir" ]; then
        ls -ld "$dir"
    fi
done
echo ""

# 9. 配置摘要
echo -e "${BLUE}【9】配置文件关键参数${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f /etc/redis/redis.conf ]; then
    echo "端口: $(grep -E '^port ' /etc/redis/redis.conf | awk '{print $2}')"
    echo "绑定: $(grep -E '^bind ' /etc/redis/redis.conf | awk '{print $2}')"
    echo "数据目录: $(grep -E '^dir ' /etc/redis/redis.conf | awk '{print $2}')"
    echo "日志文件: $(grep -E '^logfile ' /etc/redis/redis.conf | awk '{print $2}')"
    echo "RDB 文件: $(grep -E '^dbfilename ' /etc/redis/redis.conf | awk '{print $2}')"
    echo "后台运行: $(grep -E '^daemonize ' /etc/redis/redis.conf | awk '{print $2}')"
    echo "保护模式: $(grep -E '^protected-mode ' /etc/redis/redis.conf | awk '{print $2}')"

    if grep -q "^requirepass" /etc/redis/redis.conf; then
        echo "密码: 已设置"
    else
        echo "密码: 未设置"
    fi
fi
echo ""

# 10. 磁盘使用
echo -e "${BLUE}【10】磁盘使用情况${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "数据目录:"
du -sh /var/lib/redis 2>/dev/null || echo "  不存在"
echo "日志目录:"
du -sh /var/log/redis 2>/dev/null || echo "  不存在"
echo "安装大小:"
dpkg-query -W -f='${Installed-Size}\n' redis-server 2>/dev/null | awk '{print $1/1024 " MB"}'
echo ""

# 11. 包信息
echo -e "${BLUE}【11】包信息${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
dpkg -l | grep redis | awk '{printf "%-20s %-15s %s\n", $2, $3, $4}'
echo ""

# 12. 完整文件列表
echo -e "${BLUE}【12】完整文件列表（前 50 个）${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
dpkg -L redis-server | head -50
echo ""
echo "总文件数: $(dpkg -L redis-server | wc -l)"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  查看完整列表: dpkg -L redis-server${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

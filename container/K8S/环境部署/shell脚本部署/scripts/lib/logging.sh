#!/usr/bin/env bash
#
# lib/logging.sh - 生产级日志框架
#

[[ -n "${_LOGGING_SH:-}" ]] && return
readonly _LOGGING_SH=1

LOG_DIR="$(dirname "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")")"
LOG_FILE="${LOG_DIR}/logs/shell.log"
mkdir -p "${LOG_DIR}/logs"

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INCLUDE_DIR="$(dirname "${CURRENT_DIR}")"
source "${INCLUDE_DIR}/include/color.sh"

# 日志配置
declare -g LOG_FILE="${LOG_FILE:-}"
declare -g LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}" # 10MB
declare -g LOG_BACKUP_COUNT="${LOG_BACKUP_COUNT:-5}"
declare -gi LOG_LEVEL=1  # 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR

# 颜色（仅终端）
#if [[ -t 2 ]]; then
#    readonly _C_RED=$'\033[31m'
#    readonly _C_YELLOW=$'\033[33m'
#    readonly _C_GREEN=$'\033[32m'
#    readonly _C_BLUE=$'\033[34m'
#    readonly _C_GRAY=$'\033[90m'
#    readonly _C_RESET=$'\033[0m'
#    readonly _C_BOLD=$'\033[1m'
#else
#    readonly _C_RED='' _C_YELLOW='' _C_GREEN='' _C_BLUE=''
#    readonly _C_GRAY='' _C_RESET='' _C_BOLD=''
#fi

# 日志级别设置
log_set_level() {
    case "${1,,}" in
        debug|0) LOG_LEVEL=0 ;;
        info|1)  LOG_LEVEL=1 ;;
        warn|2)  LOG_LEVEL=2 ;;
        error|3) LOG_LEVEL=3 ;;
        *) echo "Unknown log level: $1" >&2 ;;
    esac
}

# 设置日志文件
log_set_file() {
    local file="$1"
    local dir
    dir="$(dirname "$file")"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            echo"Failed to create log directory: $dir" >&2
            return 1
        }
    fi

    LOG_FILE="$file"
}

# 日志轮转
_log_rotate() {
    [[ -z "$LOG_FILE" ]] && return
    [[ ! -f "$LOG_FILE" ]] && return

    local size
    size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)

    if (( size > LOG_MAX_SIZE )); then
        # 轮转旧文件
        for ((i = LOG_BACKUP_COUNT - 1; i >= 1; i--)); do
            [[ -f "${LOG_FILE}.$i" ]] && mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i + 1))"
        done
        mv "$LOG_FILE" "${LOG_FILE}.1"
        touch "$LOG_FILE"
    fi
}

# 核心日志函数
_log() {
    local level=$1 level_name=$2 color=$3
    shift 3

    (( level < LOG_LEVEL )) && return 0

    local timestamp caller_info
    timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')

    # 获取调用位置（跳过内部函数）
    local frame=1
    while [[ "${FUNCNAME[$frame]:-}" == _log* ]] || [[ "${FUNCNAME[$frame]:-}" == log_* ]]; do
        ((frame++))
    done
    local func="${FUNCNAME[$frame]:-main}"
    local line="${BASH_LINENO[$((frame - 1))]:-0}"
    caller_info="${func}:${line}"

    local message="$*"
    local log_line="[${timestamp}] [${level_name}] [${caller_info}] ${message}"

    # 输出到终端（带颜色）
    # echo -e "${color}${log_line}${_C_RESET}" >&2
    echo -e "${color}${log_line}${_C_RESET}" >&2

    # 输出到文件（无颜色）
    if [[ -n "$LOG_FILE" ]]; then
        echo "$log_line" >> "$LOG_FILE"
        _log_rotate
    fi
}

# 公共日志函数
log_debug() { _log 0 "DEBUG" "$_C_GRAY"   "$@"; }
log_info()  { _log 1 "INFO " "$_C_GREEN"  "$@"; }
log_warn()  { _log 2 "WARN " "$_C_YELLOW" "$@"; }
log_error() { _log 3 "ERROR" "$_C_RED"    "$@"; }

# 结构化日志（JSON格式）
log_json() {
    local level="${1:-info}"
    local message="${2:-}"
    shift 2

    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    local extra=""
    while [[ $# -gt 0 ]]; do
        local key="${1%%=*}"
        local value="${1#*=}"
        extra+=", \"${key}\": \"${value}\""
        shift
    done

    log_info "{\"timestamp\": \"${timestamp}\", \"level\": \"${level}\", \"message\": \"${message}\"${extra}}"
}

# 执行命令并记录
#log_exec() {
#    local cmd="$*"
#    log_debug "Executing: $cmd"
#
#    local output exit_code
#    output=$("$@" 2>&1) && exit_code=$? || exit_code=$?
#
#    if (( exit_code == 0 )); then
#        log_debug "Command succeeded"
#        [[ -n "$output" ]] && log_debug "Output: $output"
#    else
#        log_error "Command failed with exit code $exit_code"
#        [[ -n "$output" ]] && log_error "Output: $output"
#    fi
#
#    return $exit_code
#}

# 执行命令并记录（增强版）
log_exec() {
    local cmd="$*"
    local capture_all="${LOG_EXEC_CAPTURE_ALL:-1}"

    log_debug "Executing: $cmd"

    local output exit_code
    local temp_file

    # 创建临时文件
    temp_file=$(mktemp)

    if [[ "$capture_all" == "1" ]]; then
        # 完全捕获所有输出
        if [[ -n "$LOG_FILE" ]]; then
            # 使用 tee 同时输出到终端、日志文件和临时文件
            {
                eval "$cmd" 2>&1 | tee -a "$LOG_FILE" "$temp_file"
                exit_code=${PIPESTATUS[0]}
            }
        else
            # 没有日志文件，只捕获到临时文件
            eval "$cmd" 2>&1 > "$temp_file"
            exit_code=$?
            # 同时显示到终端
            cat "$temp_file"
        fi
    else
        # 仅捕获错误输出
        output=$(eval "$cmd" 2>&1) && exit_code=$? || exit_code=$?
        echo "$output" > "$temp_file"
    fi

    # 从临时文件读取完整输出
    output=$(cat "$temp_file")

    # 清理临时文件
    rm -f "$temp_file"

    # 记录结果
    if (( exit_code == 0 )); then
        [[ "$LOG_LEVEL" -le 1 ]] && log_info "Command $cmd succeeded"
    else
        log_error "Command failed with exit code $exit_code"
    fi

    return $exit_code
}

log_exec_git() {
    local cmd="$*"
    local capture_all="${LOG_EXEC_CAPTURE_ALL:-1}"

    log_debug "Executing: $cmd"

    local output exit_code
    local script_file

    if [[ "$capture_all" == "1" ]]; then
        script_file=$(mktemp)

        # 执行命令
        script -q -c "$cmd" "$script_file" > /dev/null 2>&1
        exit_code=$?

        # 处理输出 - 去除多余空行
        output=$(cat "$script_file" | \
            # 将回车符替换为换行符
            tr '\r' '\n' | \
            # 移除 ANSI 转义序列
            sed 's/\x1b\[[0-9;]*[a-zA-Z]//g;s/\x1b\[[0-9;]*m//g' | \
            # 移除退格符
            tr -d '\b' | \
            # 移除 script 标记行
            sed '/^Script/d' | \
            # 处理空行：删除连续的空行，只保留一个
            sed '/^$/N;/\n$/D' | \
            # 处理 git 输出
            awk '
            # 定义进度类型
            BEGIN {
                types["enumerating"] = "remote: Enumerating objects"
                types["counting"] = "remote: Counting objects"
                types["compressing"] = "remote: Compressing objects"
                types["receiving"] = "Receiving objects"
                types["resolving"] = "Resolving deltas"

                for (t in types) {
                    last_line[t] = ""
                    last_percent[t] = 0
                }
            }

            {
                line = $0

                # 跳过空行
                if (line == "") next

                # 检查是否是进度行
                is_progress = 0
                current_type = ""

                for (t in types) {
                    if (index(line, types[t]) == 1) {
                        is_progress = 1
                        current_type = t
                        break
                    }
                }

                if (is_progress) {
                    # 提取百分比
                    if (match(line, /[0-9]+%/)) {
                        percent = substr(line, RSTART, RLENGTH-1) + 0
                        if (percent > last_percent[current_type]) {
                            last_percent[current_type] = percent
                            last_line[current_type] = line
                        }
                    } else {
                        # 没有百分比的行（如 Enumerating）
                        last_line[current_type] = line
                    }

                    # 如果已经是完成状态，立即输出
                    if (line ~ /, done\.?$/) {
                        print line
                        last_line[current_type] = ""
                        last_percent[current_type] = 0
                    }
                } else {
                    # 输出非进度行之前，先输出缓存的进度行
                    for (t in types) {
                        if (last_line[t] != "" && last_line[t] !~ /, done\.?$/) {
                            print last_line[t] ", done."
                            last_line[t] = ""
                            last_percent[t] = 0
                        }
                    }
                    print line
                }
            }

            END {
                # 输出所有缓存的进度行
                order[1] = "enumerating"
                order[2] = "counting"
                order[3] = "compressing"
                order[4] = "receiving"
                order[5] = "resolving"

                for (i = 1; i <= 5; i++) {
                    t = order[i]
                    if (last_line[t] != "" && last_line[t] !~ /, done\.?$/) {
                        line = last_line[t]
                        # 添加 done 标记
                        if (line ~ /[0-9]+%/) {
                            # 对于百分比行，替换为 100%
                            if (match(line, /[0-9]+% \([0-9]+\/[0-9]+\)/)) {
                                matched = substr(line, RSTART, RLENGTH)
                                split(matched, parts, "/")
                                total = parts[2]
                                gsub(/[^0-9]/, "", total)
                                # 构建新的行
                                prefix = substr(line, 1, RSTART-1)
                                suffix = substr(line, RSTART+RLENGTH)
                                line = prefix "100% (" total "/" total ")" suffix
                            }
                        }
                        print line ", done."
                    }
                }
            }' | \
            # 再次清理空行
            sed '/^$/d'
        )

        # 输出到终端
        echo "$output"

        # 记录到日志文件
        if [[ -n "$LOG_FILE" ]] && [[ -n "$output" ]]; then
            echo "$output" >> "$LOG_FILE"
        fi

        rm -f "$script_file"
                rm -f "$script_file"

        # 检查 git 命令是否真的成功
        # 如果输出中包含 "fatal:" 或 "error:"，即使 script 命令返回 0，git 也失败了
        if echo "$output" | grep -q -E '^(fatal:|error:|FATAL:|ERROR:)'; then
            exit_code=1
        fi
    else
        output=$(eval "$cmd" 2>&1) && exit_code=$? || exit_code=$?
    fi

    # 记录结果
    if (( exit_code == 0 )); then
        [[ "$LOG_LEVEL" -le 1 ]] && log_info "Command succeeded"
    else
        log_error "Command failed with exit code $exit_code"
    fi

    return $exit_code
}

# 计时日志
log_timer_start() {
    local name="${1:-default}"
    declare -g "_timer_${name}=$(date +%s%N)"
}

log_timer_end() {
    local name="${1:-default}"
    local start_var="_timer_${name}"
    local start="${!start_var:-}"

    if [[ -z "$start" ]]; then
        log_warn "Timer '$name' was not started"
        return
    fi

    local end duration_ms
    end=$(date +%s%N)
    duration_ms=$(( (end - start) / 1000000 ))

    log_info "Timer '$name': ${duration_ms}ms"
    unset "$start_var"
}
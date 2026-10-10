#!/usr/bin/env bash

[[ -n "${_UTILS_SH:-}" ]] && return
readonly _UTILS_SH=1

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INCLUDE_DIR="$(dirname "${CURRENT_DIR}")"
source "${INCLUDE_DIR}/include/color.sh"

CONF_DIR="$(dirname "${INCLUDE_DIR}")"
source "${CONF_DIR}/conf/config"

# 高级函数：支持多种格式
# 支持格式：
#   - 单个数字：12
#   - 范围：15..17
#   - 逗号分隔：12,15,20
#   - 混合：12,15..17,20
expand_ip_list() {
    local ip_prefix="${underlay_network:-192.168.52}"
    local num_spec="$1"
    local result=()

    # 去掉花括号（如果有）
    num_spec="${num_spec#\{}"
    num_spec="${num_spec%\}}"

    # 按逗号分割
    IFS=', ' read -ra segments <<< "$num_spec"

    for segment in "${segments[@]}"; do
        # 去除空格
        segment=$(echo "$segment" | tr -d ' ')

        if [[ $segment =~ ^([0-9]+)\.\.([0-9]+)$ ]]; then
            # 范围：15..17
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            for ((i=start; i<=end; i++)); do
                result+=("${ip_prefix}.${i}")
            done
        elif [[ $segment =~ ^[0-9]+$ ]]; then
            # 单个数字：12
            result+=("${ip_prefix}.${segment}")
        else
            echo "Warning: Invalid format '$segment'" >&2
            exit 1
        fi
    done

    # 输出结果
    echo "${result[@]}"
}

## 测试用例
#echo "=== Test 1: 基本格式 ==="
#ip_list=$(expand_ip_list "12,15..17,20")
#echo "${ip_list}"
## 输出：10.0.0.12 10.0.0.15 10.0.0.16 10.0.0.17 10.0.0.20
#
#echo ""
#echo "=== Test 2: 带花括号 ==="
#ip_list=$(expand_ip_list "{12,15..17,20}")
#echo "${ip_list}"
## 输出：10.0.0.12 10.0.0.15 10.0.0.16 10.0.0.17 10.0.0.20
#
#echo ""
#echo "=== Test 3: 空格分隔 ==="
#ip_list=$(expand_ip_list "12 15..17 20")
#echo "${ip_list}"
## 输出：10.0.0.12 10.0.0.15 10.0.0.16 10.0.0.17 10.0.0.20
#
#echo ""
#echo "=== Test 4: 复杂范围 ==="
#ip_list=$(expand_ip_list "10,20..25,30,100..102")
#echo "${ip_list}"
## 输出：192.168.1.10 192.168.1.20 192.168.1.21 ... 192.168.1.102
#!/bin/bash
# run_tests.sh

set -eo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/src/lib/logging.sh"
log_set_file "${CURRENT_DIR}/logs/tests.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

export GIT_SSL_NO_VERIFY=1
# 检查 bats 是否安装
if ! command -v bats &> /dev/null ; then
    log_warn "BATS 未安装，正在安装..."
    log_exec_git git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
    # log_exec git clone https://hub.fastgit.org/bats-core/bats-core.git /tmp/bats-core
    log_exec sudo /tmp/bats-core/install.sh /usr/local
    log_info "BATS 安装完成"
    rm -fr /tmp/bats-core
fi

# 安装测试辅助库
if [[ ! -d "tests/test_helper/bats-support" ]]; then
    log_warn "安装 bats-support..."
    log_exec_git git clone https://github.com/bats-core/bats-support.git tests/test_helper/bats-support
    log_info "bats-support 安装完成"
fi

if [[ ! -d "tests/test_helper/bats-assert" ]]; then
    log_warn "安装 bats-assert..."
    log_exec_git git clone https://github.com/bats-core/bats-assert.git tests/test_helper/bats-assert
    log_info "bats-support 安装完成"
fi

if [[ ! -d "tests/test_helper/bats-file" ]]; then
    log_warn "安装 bats-file..."
    log_exec_git git clone https://github.com/bats-core/bats-file.git tests/test_helper/bats-file
    log_info "bats-file 安装完成"
fi

if [[ ! -f "/usr/local/bin/kcov" ]]; then
    apt update
    apt install -y kcov
fi

log_info "运行测试..."

run_coverage() {
    local output_dir="coverage"
    local test_dir="tests"

    rm -rf "$output_dir"
    mkdir -p "$output_dir"

    # 方法1：使用 find 查找所有测试文件，排除 test_helper 目录
    log_info "正在查找测试文件..."

    # 获取所有测试文件（排除 test_helper 目录）
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$test_dir" -name "*.bats" -type f ! -path "*/test_helper/*" -print0)

    # 检查是否找到测试文件
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_info "错误: 未找到测试文件"
        log_info "在 $test_dir 目录中查找 .bats 文件（排除 test_helper 目录）"
        find "$test_dir" -name "*.bats" -type f
        return 1
    fi

    log_info "找到 ${#test_files[@]} 个测试文件:"
    log_info '%s\n' "${test_files[@]}"

    # 方法2：使用 kcov 运行所有测试文件
    log_info "正在使用 kcov 运行测试..."
    if command -v kcov >/dev/null 2>&1; then
        # 运行 kcov
        kcov --include-pattern=".sh" \
             --exclude-pattern="tests/test_helper/,$output_dir/,/tmp/" \
             "$output_dir" \
             bats "${test_files[@]}"

        # 检查是否成功
        if [[ $? -eq 0 ]] && [[ -f "$output_dir/index.html" ]]; then
            log_info ""
            log_info "✅ 覆盖率测试完成!"
            log_info "📊 覆盖率报告: $(pwd)/$output_dir/index.html"
            log_info ""

            # 显示简单的覆盖率统计
            if [[ -f "$output_dir/coverage.json" ]] && command -v jq >/dev/null 2>&1; then
                log_info "📈 覆盖率统计:"
                jq -r '
                    "总行数: " + (.summary.lines_total | tostring) +
                    ", 覆盖行数: " + (.summary.lines_covered | tostring) +
                    ", 覆盖率: " + (.summary.percent_covered | tostring) + "%"
                ' "$output_dir/coverage.json" 2>/dev/null || true
            fi
        else
            log_warn "⚠️  kcov 可能未正确生成报告"
            log_warn "尝试直接运行测试..."

            # 如果 kcov 失败，直接运行测试
            bats "${test_files[@]}"
            return $?
        fi
    else
        log_warn "错误: kcov 未安装"
        log_warn "请安装 kcov:"
        log_warn "  Ubuntu/Debian: sudo apt-get install kcov"
        log_warn "  macOS: brew install kcov"
        log_warn ""
        log_warn "将直接运行测试（无覆盖率）..."
        bats "${test_files[@]}"
        return $?
    fi
}

copy_html_to_nginx() {
    rm -fr /var/www/static/*
    cd /var/www/static
    cp -R /root/cainiaotool/shell/coverage/* .
}

run_coverage
copy_html_to_nginx
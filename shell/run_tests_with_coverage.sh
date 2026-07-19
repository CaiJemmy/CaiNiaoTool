#!/bin/bash
# run_tests_with_coverage.sh

set -eo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/src/lib/logging.sh"

# 颜色输出
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
NC=$'\033[0m'

# 配置
LOG_FILE="${CURRENT_DIR}/logs/tests.log"
COVERAGE_DIR="${CURRENT_DIR}/coverage"
HTML_COVERAGE_DIR="${COVERAGE_DIR}/html"
REPORT_FILE="${COVERAGE_DIR}/coverage.txt"
MIN_COVERAGE=80  # 最小覆盖率要求（百分比）

# 确保目录存在
mkdir -p "${CURRENT_DIR}/logs"
rm -fr "${COVERAGE_DIR}"
mkdir -p "${COVERAGE_DIR}"
mkdir -p "${HTML_COVERAGE_DIR}"

# 设置日志文件
log_set_file "${LOG_FILE}"

export GIT_SSL_NO_VERIFY=1

# 检查并安装覆盖率工具
check_coverage_tools() {
    local missing_tools=()

    # 检查 Ruby
    if ! command -v ruby &> /dev/null; then
        log_error "Ruby 未安装，bashcov 需要 Ruby 运行"
        log_info "安装方法:"

        if [[ -f /etc/debian_version ]]; then
            log_info "  sudo apt-get install -y ruby ruby-dev"
        elif [[ -f /etc/redhat-release ]]; then
            log_info "  sudo yum install -y ruby ruby-devel"
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            log_info "  brew install ruby"
        fi
        exit 1
    fi

    # 检查 gem
    if ! command -v gem &> /dev/null; then
        log_error "RubyGems 未安装"
        exit 1
    fi

    # 检查并安装 bashcov
    if ! gem list -i bashcov &> /dev/null; then
        log_warn "bashcov 未安装，正在安装..."

        # 尝试不使用 sudo 安装（用户级）
        if gem install bashcov simplecov --user-install 2>/dev/null; then
            log_info "bashcov 安装成功（用户级）"
        elif sudo gem install bashcov simplecov 2>/dev/null; then
            log_info "bashcov 安装成功（系统级）"
        else
            log_error "bashcov 安装失败"
            log_info "请手动安装: gem install bashcov simplecov"
            exit 1
        fi
    else
        log_info "bashcov 已安装"
    fi

    # 确保 bashcov 在 PATH 中
    if ! command -v bashcov &> /dev/null; then
        # 尝试添加 Ruby 用户级 gem 路径
        local ruby_user_dir=$(ruby -e 'puts Gem.user_dir' 2>/dev/null)
        if [[ -n "$ruby_user_dir" && -d "$ruby_user_dir/bin" ]]; then
            export PATH="$ruby_user_dir/bin:$PATH"
            log_info "已添加 Ruby gem 路径: $ruby_user_dir/bin"
        fi

        # 再次检查
        if ! command -v bashcov &> /dev/null; then
            log_error "bashcov 命令未找到"
            log_info "请确保 Ruby gem bin 目录在 PATH 中"
            exit 1
        fi
    fi
}

# 检查并安装 BATS
install_bats() {
    if ! command -v bats &> /dev/null; then
        log_warn "BATS 未安装，正在安装..."
        log_exec_git git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
        log_exec sudo /tmp/bats-core/install.sh /usr/local
        log_info "BATS 安装完成"
        rm -fr /tmp/bats-core
    fi
}

# 安装测试辅助库
install_test_helpers() {
    local helpers=(
        "bats-support:https://github.com/bats-core/bats-support.git"
        "bats-assert:https://github.com/bats-core/bats-assert.git"
        "bats-file:https://github.com/bats-core/bats-file.git"
    )

    for helper in "${helpers[@]}"; do
        local name="${helper%%:*}"
        local url="${helper#*:}"
        local dir="tests/test_helper/${name}"

        if [ ! -d "$dir" ]; then
            log_warn "安装 ${name}..."
            log_exec_git git clone "$url" "$dir"
            log_info "${name} 安装完成"
        fi
    done
}

# 运行测试并收集覆盖率
run_tests_with_coverage() {
    local test_files=()
    local exit_code=0

    log_info "查找测试文件..."

    # 收集所有测试文件（排除 test_helper 目录）
    while IFS= read -r -d $'\0' file; do
        test_files+=("$file")
        log_debug "找到测试文件: $file"
    done < <(find tests/ -name "*.bats" -type f -not -path "*/test_helper/*" -print0)

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_error "没有找到测试文件"
        return 1
    fi

    log_info "找到 ${#test_files[@]} 个测试文件"

    # 清理旧的覆盖率数据
    log_info "清理旧的覆盖率数据..."
    rm -rf "${COVERAGE_DIR}/"*

    # 检查是否以 root 运行
    if [[ $EUID -eq 0 ]]; then
        log_warn "检测到以 root 用户运行，这可能导致覆盖率收集问题"
        log_info "建议使用普通用户运行测试"
    fi

    # 设置 bashcov 环境变量
    export BASHCOV_ROOT="${CURRENT_DIR}"
    export BASHCOV_SKIP_UNCOVERED=true

    # 运行所有测试并收集覆盖率
    log_info "运行所有测试..."

    # 使用单次 bashcov 调用运行所有测试
    local all_test_files="${test_files[*]}"

    if bashcov \
        --root "${CURRENT_DIR}" \
        --skip-uncovered \
        -- \
        bats ${test_files[@]} > "${COVERAGE_DIR}/all_tests.log" 2>&1; then

        log_info "✓ 所有测试通过"
        cat "${COVERAGE_DIR}/all_tests.log"
    else
        log_error "✗ 测试失败"
        cat "${COVERAGE_DIR}/all_tests.log"
        exit_code=1
    fi

    return $exit_code
}


# 合并覆盖率报告
merge_coverage_reports() {
    log_info "合并覆盖率报告..."

    # 查找 bashcov 生成的覆盖率文件
    local coverage_files=()
    while IFS= read -r -d $'\0' file; do
        coverage_files+=("$file")
    done < <(find "${COVERAGE_DIR}" -name ".resultset.json" -type f -print0)

    if [[ ${#coverage_files[@]} -eq 0 ]]; then
        log_error "没有找到覆盖率数据"
        return 1
    fi

    log_info "找到 ${#coverage_files[@]} 个覆盖率数据文件"

    # 生成文本报告
    generate_text_report

    # 生成 HTML 报告
    generate_html_report

    return 0
}

# 生成文本覆盖率报告
generate_text_report() {
    log_info "生成文本覆盖率报告..."

    # 查找 SimpleCov 生成的 index.html
    local index_file="${COVERAGE_DIR}/index.html"

    if [[ ! -f "$index_file" ]]; then
        log_warn "没有找到覆盖率 HTML 文件"
        return 1
    fi

    # 从 HTML 中提取覆盖率数据
    local coverage_percent=0

    # SimpleCov HTML 中的覆盖率通常在 class="covered_percent" 的元素中
    if command -v grep &> /dev/null && command -v sed &> /dev/null; then
        # 方法1: 查找 covered_percent
        coverage_percent=$(grep -oP 'covered_percent[^>]*>\s*\K[\d.]+' "$index_file" 2>/dev/null | head -1 || echo "")

        if [[ -z "$coverage_percent" ]]; then
            # 方法2: 查找百分比模式 XX.XX%
            coverage_percent=$(grep -oP '\d+\.\d+(?=\s*%\s*covered)' "$index_file" 2>/dev/null | head -1 || echo "")
        fi

        if [[ -z "$coverage_percent" ]]; then
            # 方法3: 从日志文件中提取
            local log_file="${COVERAGE_DIR}/all_tests.log"
            if [[ -f "$log_file" ]]; then
                coverage_percent=$(grep -oP 'Line Coverage:\s*\K[\d.]+' "$log_file" 2>/dev/null | head -1 || echo "")
            fi
        fi

        if [[ -z "$coverage_percent" ]]; then
            # 方法4: 使用更宽松的模式匹配
            coverage_percent=$(grep -oP '[\d.]+(?=%|percent)' "$index_file" 2>/dev/null | head -1 || echo "0")
        fi

        # 转换为整数
        if [[ -n "$coverage_percent" ]]; then
            coverage_percent=$(printf "%.0f" "$coverage_percent" 2>/dev/null || echo "0")
        else
            coverage_percent=0
        fi
    fi

    log_debug "提取到的覆盖率: ${coverage_percent}%"

    # 生成文本报告
    {
        echo "========================================"
        echo "测试覆盖率报告"
        echo "生成时间: $(date)"
        echo "========================================"
        echo ""
        echo "总体覆盖率: ${coverage_percent}%"
        echo "覆盖率要求: ${MIN_COVERAGE}%"
        echo ""

        if [[ $coverage_percent -ge $MIN_COVERAGE ]]; then
            echo "✅ 通过覆盖率检查 (${coverage_percent}% >= ${MIN_COVERAGE}%)"
        else
            echo "❌ 未达到覆盖率要求 (${coverage_percent}% < ${MIN_COVERAGE}%)"
        fi

        echo ""
        echo "详细报告请查看 HTML 文件:"
        echo "  file://${COVERAGE_DIR}/index.html"
        echo ""

        # 如果有日志文件，附加原始输出
        local log_file="${COVERAGE_DIR}/all_tests.log"
        if [[ -f "$log_file" ]]; then
            echo "----------------------------------------"
            echo "原始 bashcov 输出:"
            echo "----------------------------------------"
            grep "Line Coverage:" "$log_file" || true
            echo ""
        fi

    } > "$REPORT_FILE"

    # 输出到控制台
    cat "$REPORT_FILE"

    # 返回覆盖率百分比
    echo "$coverage_percent"
}


# 生成 HTML 覆盖率报告
generate_html_report() {
    log_info "生成 HTML 覆盖率报告..."

    # bashcov 会自动生成 HTML 报告到 coverage 目录
    if [[ -f "${COVERAGE_DIR}/index.html" ]]; then
        log_info "HTML 报告已生成: ${COVERAGE_DIR}/index.html"
        return 0
    else
        log_warn "未找到 HTML 覆盖率报告"
        return 1
    fi
}

# 主函数
main() {
    log_info "开始运行测试..."
    log_info "项目目录: $CURRENT_DIR"
    log_info "日志文件: $LOG_FILE"
    log_info "覆盖率目录: $COVERAGE_DIR"

    # 检查工具
    check_coverage_tools
    install_bats
    install_test_helpers

    # 运行测试并收集覆盖率
    if run_tests_with_coverage; then
        log_info "所有测试通过，正在生成覆盖率报告..."
    else
        log_error "部分测试失败"
    fi

    # 合并覆盖率报告
    if merge_coverage_reports; then
        log_info "覆盖率报告生成成功"
    else
        log_warn "覆盖率报告生成失败或数据不完整"
    fi

    # 读取覆盖率结果
    local coverage_percent=0
    if [[ -f "$REPORT_FILE" ]]; then
        # 从报告中提取覆盖率百分比
        coverage_percent=$(grep -oP "总体覆盖率: \K[0-9]+" "$REPORT_FILE" | tail -1 || echo "0")

        if [[ -n "$coverage_percent" && "$coverage_percent" =~ ^[0-9]+$ ]]; then
            log_info "总体覆盖率: ${coverage_percent}%"

            # 检查是否满足最低覆盖率要求
            if [[ $coverage_percent -ge $MIN_COVERAGE ]]; then
                log_info "✅ 覆盖率要求满足 (${coverage_percent}% >= ${MIN_COVERAGE}%)"
            else
                log_warn "⚠️  覆盖率未达标 (${coverage_percent}% < ${MIN_COVERAGE}%)"
            fi
        else
            log_warn "无法解析覆盖率百分比"
            coverage_percent=0
        fi
    fi

    # 显示报告位置
    echo ""
    echo "========================================"
    echo "测试执行完成"
    echo "========================================"
    echo ""
    echo "📊 覆盖率报告:"
    echo "  文本报告: file://${REPORT_FILE}"
    echo "  HTML报告: file://${COVERAGE_DIR}/index.html"
    echo "  详细日志: file://${LOG_FILE}"
    echo ""

    # 如果覆盖率不达标，显示警告
    if [[ $coverage_percent -lt $MIN_COVERAGE ]]; then
        echo "⚠️  ${YELLOW}警告: 代码覆盖率未达到要求${NC}"
        echo "   当前覆盖率: ${coverage_percent}%"
        echo "   要求覆盖率: ${MIN_COVERAGE}%"
        echo "   请补充测试用例以提高覆盖率"
        echo ""
    fi

    # 如果测试失败，显示错误
    if [[ $? -ne 0 ]]; then
        echo "❌  ${RED}测试执行失败${NC}"
        echo "   请检查测试日志: ${LOG_FILE}"
        echo ""
        return 1
    else
        echo "✅  ${GREEN}测试执行完成${NC}"
        echo ""

        # 如果覆盖率也达标，显示完整通过
        if [[ $coverage_percent -ge $MIN_COVERAGE ]]; then
            echo "🎉  ${GREEN}所有测试通过且覆盖率达标！${NC}"
            return 0
        else
            # 测试通过但覆盖率不达标
            return 2
        fi
    fi
}

# 清理函数
cleanup() {
    local exit_code=$?

    log_info "清理临时文件..."

    # 清理 /tmp 中的测试文件
    if [[ -d /tmp && -n "$(find /tmp -maxdepth 1 -name "bats_test_*" 2>/dev/null)" ]]; then
        find /tmp -maxdepth 1 -name "bats_test_*" -type f -delete 2>/dev/null || true
    fi

    # 清理 /tmp 中的 bats-core
    if [[ -d /tmp/bats-core ]]; then
        rm -rf /tmp/bats-core 2>/dev/null || true
    fi

    log_info "清理完成"

    return $exit_code
}

# 设置 trap 确保清理
trap cleanup EXIT INT TERM

# 使用帮助信息
show_help() {
    cat <<EOF
运行测试并生成覆盖率报告

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -c, --coverage <N>  设置最小覆盖率要求 (默认: ${MIN_COVERAGE}%)
  -d, --dir <DIR>     设置项目目录 (默认: ${CURRENT_DIR})
  -o, --output <DIR>  设置覆盖率输出目录 (默认: ${COVERAGE_DIR})
  --no-color          禁用彩色输出
  --no-html           不生成 HTML 报告
  --text-only         只生成文本报告

环境变量:
  MIN_COVERAGE        最小覆盖率要求
  LOG_LEVEL           日志级别 (debug, info, warn, error)
  GIT_SSL_NO_VERIFY   禁用 Git SSL 验证

示例:
  $0                     # 使用默认配置运行
  $0 -c 90               # 设置 90% 的最小覆盖率
  $0 --no-html          # 不生成 HTML 报告
  MIN_COVERAGE=95 $0    # 通过环境变量设置覆盖率要求

报告位置:
  文本报告: ${COVERAGE_DIR}/coverage.txt
  HTML报告: ${COVERAGE_DIR}/index.html
  测试日志: ${LOG_FILE}
EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--coverage)
                if [[ $2 =~ ^[0-9]+$ ]]; then
                    MIN_COVERAGE=$2
                    shift 2
                else
                    log_error "覆盖率必须是数字"
                    exit 1
                fi
                ;;
            -d|--dir)
                if [[ -d $2 ]]; then
                    CURRENT_DIR="$(cd "$2" && pwd)"
                    shift 2
                else
                    log_error "目录不存在: $2"
                    exit 1
                fi
                ;;
            -o|--output)
                COVERAGE_DIR="$2"
                HTML_COVERAGE_DIR="${COVERAGE_DIR}/html"
                mkdir -p "$COVERAGE_DIR" "$HTML_COVERAGE_DIR"
                shift 2
                ;;
            --no-color)
                RED=''
                GREEN=''
                YELLOW=''
                BLUE=''
                NC=''
                shift
                ;;
            --no-html)
                GENERATE_HTML=false
                shift
                ;;
            --text-only)
                GENERATE_HTML=false
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 更新相关路径
    LOG_FILE="${CURRENT_DIR}/logs/tests.log"
    COVERAGE_DIR="${CURRENT_DIR}/coverage"
    HTML_COVERAGE_DIR="${COVERAGE_DIR}/html"
    REPORT_FILE="${COVERAGE_DIR}/coverage.txt"

    # 确保目录存在
    mkdir -p "${CURRENT_DIR}/logs"
    mkdir -p "${COVERAGE_DIR}"
    mkdir -p "${HTML_COVERAGE_DIR}"
}

# 检查环境
check_environment() {
    log_info "检查环境..."

    # 检查是否在项目根目录
    if [[ ! -d "${CURRENT_DIR}/src" ]]; then
        log_warn "未找到 src 目录，可能不在项目根目录"
        log_info "当前目录: $CURRENT_DIR"

        # 尝试向上查找
        local parent_dir=$(dirname "$CURRENT_DIR")
        if [[ -d "${parent_dir}/src" ]]; then
            log_info "在父目录找到 src，使用: $parent_dir"
            CURRENT_DIR="$parent_dir"
        fi
    fi

    # 检查 shell 版本
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        log_warn "Bash 版本较低 (${BASH_VERSION})，建议升级到 4.0+"
    fi

    # 检查磁盘空间
    local available_space=$(df -k "$CURRENT_DIR" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 100000 ]]; then  # 小于 100MB
        log_warn "磁盘空间不足 (可用: $((available_space/1024))MB)"
    fi
}

# 显示欢迎信息
show_welcome() {
    echo ""
    echo "🚀 ${BLUE}Shell 测试覆盖率工具 (bashcov)${NC}"
    echo "================================"
    echo "项目: ${CURRENT_DIR}"
    echo "时间: $(date)"
    echo "最小覆盖率: ${MIN_COVERAGE}%"
    echo ""
}

# 显示结束信息
show_footer() {
    local exit_code=$?
    local status_color=$GREEN
    local status_text="成功"

    if [[ $exit_code -eq 1 ]]; then
        status_color=$RED
        status_text="测试失败"
    elif [[ $exit_code -eq 2 ]]; then
        status_color=$YELLOW
        status_text="测试通过但覆盖率不达标"
    elif [[ $exit_code -ne 0 ]]; then
        status_color=$RED
        status_text="错误 (代码: $exit_code)"
    fi

    echo ""
    echo "================================"
    echo "🏁 ${status_color}执行完成: ${status_text}${NC}"
    echo "================================"
    echo ""

    return $exit_code
}

# 主执行流程
{
    # 解析命令行参数
    parse_args "$@"

    # 显示欢迎信息
    show_welcome

    # 检查环境
    check_environment

    # 运行主函数
    main "$@"

    # 捕获退出代码
    exit_code=$?

    # 显示结束信息
    show_footer

    exit $exit_code
}

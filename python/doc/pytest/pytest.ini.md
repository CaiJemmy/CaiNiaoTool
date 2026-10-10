# pytest.ini 常用配置详解

## 一、pytest.ini 配置文件基础

### 1. **配置文件位置和优先级**
```
# 配置文件搜索顺序（从高到低）：
1. pytest.ini             # 当前目录或父目录
2. pyproject.toml         # 当前目录或父目录（需要 [tool.pytest.ini_options] 节）
3. tox.ini                # 当前目录或父目录（需要 [pytest] 节）
4. setup.cfg              # 当前目录或父目录（需要 [tool:pytest] 节）
```

### 2. **基本结构**
```ini
[pytest]
# 所有配置都在 [pytest] 节下
# 配置项 = 值
```

## 二、常用配置项详解

### 1. **测试发现配置**

```ini
[pytest]
# 测试文件模式（默认：test_*.py 和 *_test.py）
python_files = 
    test_*.py
    *_test.py
    check_*.py
    
# 测试函数模式（默认：test_*）
python_functions = 
    test_*
    should_*
    check_*
    
# 测试类模式（默认：Test*）
python_classes = 
    Test*
    Spec*
    Check*
    
# 测试目录（默认：当前目录）
testpaths = 
    tests
    integration_tests
    unit_tests
    
# 忽略的目录（默认：.*, _darcs, {arch}, CVS, _build, dist, {egg-info}）
norecursedirs = 
    .git
    .venv
    node_modules
    build
    dist
    __pycache__
    .pytest_cache
    
# Python路径（添加导入路径）
pythonpath = 
    .
    src
    tests
```

### 2. **命令行参数配置**

```ini
[pytest]
# 默认命令行参数（每次运行pytest都会自动添加这些参数）
addopts = 
    -v                  # 详细输出
    --tb=short          # 简短回溯信息
    --strict-markers    # 严格检查marker
    --strict-config     # 严格检查配置
    -q                  # 安静模式（与-v互斥）
    --color=yes         # 彩色输出
    
# 标记配置
markers =
    slow: marks tests as slow (deselect with '-m "not slow"')
    integration: marks tests as integration tests
    smoke: marks tests as smoke tests
    regression: marks tests as regression tests
    performance: marks tests as performance tests
    unit: marks tests as unit tests
    database: tests that require database
    network: tests that require network
    
# Fixture作用域配置
# 默认：function, class, module, package, session
```

### 3. **日志配置**

```ini
[pytest]
# 日志配置
log_cli = true          # 在控制台显示日志
log_cli_level = INFO    # 控制台日志级别
log_cli_format = %(asctime)s [%(levelname)s] %(message)s
log_cli_date_format = %Y-%m-%d %H:%M:%S

# 文件日志
log_file = logs/pytest.log
log_file_level = DEBUG
log_file_format = %(asctime)s [%(levelname)s] %(name)s: %(message)s
log_file_date_format = %Y-%m-%d %H:%M:%S

# 自动捕获日志
log_auto_indent = true
log_format = %(levelname)s %(message)s
log_date_format = %Y-%m-%d %H:%M:%S
```

### 4. **测试运行配置**

```ini
[pytest]
# 执行失败时停止
xfail_strict = true     # 将@xfail测试标记为失败（如果它们意外通过）
maxfail = 5             # 达到指定失败数量后停止测试
tbstyle = auto          # 回溯样式：auto/long/short/line/native/no

# 超时配置
timeout = 300           # 单个测试超时时间（秒）
timeout_method = thread # thread/signal

# 测试顺序
random_order_seed = 42  # 随机排序种子
```

### 5. **覆盖率配置**

```ini
[pytest]
# 覆盖率配置（需要pytest-cov插件）
addopts =
    --cov=src
    --cov-report=html:reports/coverage
    --cov-report=xml:reports/coverage.xml
    --cov-report=term-missing
    --cov-fail-under=80  # 覆盖率低于80%时失败
    
# 覆盖率高级配置
cov_source = src
cov_report = 
    html:reports/coverage
    xml:reports/coverage.xml
    term-missing
cov_fail_under = 80
cov_omit = 
    */test*
    */__pycache__/*
    */migrations/*
    */tests/*
```

### 6. **报告配置**

```ini
[pytest]
# HTML报告（需要pytest-html插件）
addopts =
    --html=reports/test-report.html
    --self-contained-html  # 生成独立的HTML文件
    
# JUnit报告（CI/CD集成）
addopts =
    --junitxml=reports/junit-report.xml
    
# JSON报告（需要pytest-json-report插件）
addopts =
    --json-report
    --json-report-file=reports/pytest-report.json
    
# 报告额外信息
addopts =
    --html=reports/test-report.html
    --self-contained-html
    --report-log=reports/report-log.json
```

### 7. **异步测试配置**

```ini
[pytest]
# 异步支持（需要pytest-asyncio插件）
asyncio_mode = auto     # auto/strict/legacy
```

### 8. **并行测试配置**

```ini
[pytest]
# 并行测试（需要pytest-xdist插件）
addopts =
    -n auto             # 自动使用所有CPU
    
# 或者指定数量
numprocesses = 4
max-worker-restart = 2
dist = loadfile        # load/loadfile/loadscope
```

## 三、完整的配置示例

### 1. **基础开发配置**

```ini
# pytest.ini - 基础配置
[pytest]

# Python路径
pythonpath = 
    .
    src

# 测试发现
testpaths = tests
python_files = test_*.py *_test.py
python_functions = test_*
python_classes = Test*

# 默认命令行参数
addopts = 
    -v
    --tb=short
    --strict-markers
    --color=yes
    --disable-warnings

# 忽略的目录
norecursedirs = 
    .git
    .venv
    node_modules
    build
    dist
    __pycache__
    .pytest_cache

# 标记定义
markers = 
    slow: marks tests as slow
    integration: marks tests as integration tests
    smoke: marks tests as smoke tests
    database: tests that require database
    network: tests that require network
```

### 2. **CI/CD 配置**

```ini
# pytest.ini - CI/CD配置
[pytest]

# Python路径
pythonpath = src

# 测试发现
testpaths = tests
python_files = test_*.py

# CI/CD专用配置
addopts = 
    -v
    --tb=line
    --disable-warnings
    --junitxml=test-results/junit.xml
    --cov=src
    --cov-report=xml:test-results/coverage.xml
    --cov-report=term-missing
    --cov-fail-under=80
    -p no:warnings

# 标记
markers = 
    integration: integration tests
    smoke: smoke tests

# 失败时停止
maxfail = 1

# 日志
log_cli = true
log_cli_level = WARNING
log_file = test-results/pytest.log
log_file_level = INFO
```

### 3. **完整项目配置**

```ini
# pytest.ini - 完整项目配置
[pytest]

# ===== 路径配置 =====
pythonpath = 
    .
    src
    tests

testpaths = 
    tests/unit
    tests/integration
    tests/e2e

norecursedirs = 
    .*
    _*
    build
    dist
    node_modules
    venv
    .venv
    __pycache__
    .pytest_cache
    .mypy_cache

# ===== 测试发现 =====
python_files = 
    test_*.py
    *_test.py
    *_spec.py

python_functions = 
    test_*
    should_*
    check_*
    spec_*

python_classes = 
    Test*
    Spec*
    Check*

# ===== 默认参数 =====
addopts = 
    -v
    --tb=short
    --strict-markers
    --strict-config
    --color=yes
    --disable-warnings
    --durations=10
    --html=reports/test-report.html
    --self-contained-html
    --junitxml=reports/junit-report.xml
    --cov=src
    --cov-report=html:reports/coverage
    --cov-report=xml:reports/coverage.xml
    --cov-report=term-missing
    --cov-fail-under=85
    -p no:warnings

# ===== 覆盖率详细配置 =====
cov_source = src
cov_report = 
    html:reports/coverage
    xml:reports/coverage.xml
    term-missing:skip-covered
cov_fail_under = 85
cov_omit = 
    */tests/*
    */migrations/*
    */__pycache__/*
    */test_*.py
    */*test.py
    */setup.py
    */conftest.py

# ===== 标记系统 =====
markers = 
    # 测试类型
    unit: unit tests (fast, no external dependencies)
    integration: integration tests
    e2e: end-to-end tests
    smoke: smoke tests
    
    # 特性标记
    database: tests that require database
    api: tests that involve API calls
    ui: tests that involve UI interaction
    network: tests that require network access
    fileio: tests that involve file I/O
    
    # 性能标记
    slow: tests that take longer than 2 seconds
    performance: performance tests
    benchmark: benchmark tests
    
    # 状态标记
    flaky: tests that are known to be flaky
    broken: tests that are currently broken
    todo: tests that need to be implemented
    
    # 环境标记
    windows: tests that only run on Windows
    linux: tests that only run on Linux
    macos: tests that only run on macOS
    ci: tests that should only run in CI
    dev: tests that should only run in development

# ===== 日志配置 =====
log_cli = false
log_cli_level = INFO
log_cli_format = %(asctime)s [%(levelname)8s] %(message)s (%(filename)s:%(lineno)s)
log_cli_date_format = %Y-%m-%d %H:%M:%S

log_file = reports/pytest.log
log_file_level = DEBUG
log_file_format = %(asctime)s [%(levelname)8s] %(name)s: %(message)s
log_file_date_format = %Y-%m-%d %H:%M:%S

# ===== 测试执行配置 =====
xfail_strict = true
maxfail = 10
tbstyle = short
timeout = 30
timeout_method = thread

# ===== 插件配置 =====
# 异步支持
asyncio_mode = auto

# 并行测试（使用时添加 -n auto）
# numprocesses = auto
# dist = loadscope

# ===== 自定义配置 =====
# 项目特定配置
project_name = my_project
test_timeout = 30
allowed_failures = 5
```

### 4. **多环境配置示例**

```ini
# pytest.ini - 多环境配置
[pytest]

# 公共配置
pythonpath = src
testpaths = tests
python_files = test_*.py

# 环境特定配置（通过环境变量控制）
# 设置环境变量：export TEST_ENV=ci

[dev]
addopts = 
    -v
    --tb=short
    --color=yes
    --cov=src
    --cov-report=html:reports/coverage
    --cov-report=term-missing

[ci]
addopts = 
    -v
    --tb=line
    --junitxml=test-results/junit.xml
    --cov=src
    --cov-report=xml:test-results/coverage.xml
    --cov-report=term-missing
    --cov-fail-under=80
    -p no:warnings

[prod]
addopts = 
    -q
    --tb=no
    --disable-warnings
    --junitxml=test-results/junit.xml
```

## 四、特殊配置技巧

### 1. **条件配置**

```ini
# pytest.ini - 条件配置
[pytest]

# 根据环境变量配置
env = MYAPP_TEST_ENV

# 根据Python版本配置
minversion = 6.0
requires = 
    pytest>=6.0
    pytest-cov>=3.0
    pytest-html>=3.0

# 根据操作系统配置
[windows]
addopts = --ignore=tests/unix

[linux]
addopts = --ignore=tests/windows
```

### 2. **配置文件继承**

```ini
# base-pytest.ini
[pytest]
pythonpath = src
testpaths = tests
python_files = test_*.py

# local-pytest.ini（本地开发）
[pytest]
# 继承基础配置
; 这里可以覆盖或添加配置
addopts = 
    -v
    --tb=short
    --cov=src
    --cov-report=html
```

### 3. **使用变量**

```ini
# pytest.ini - 使用变量
[pytest]

# 定义变量
project_name = my_project
report_dir = reports
coverage_threshold = 80

# 使用变量
addopts = 
    --html={report_dir}/test-report.html
    --junitxml={report_dir}/junit.xml
    --cov-fail-under={coverage_threshold}
```

## 五、常见问题解决

### 1. **配置不生效**

```ini
# 检查点：
# 1. 确保文件名为 pytest.ini（不是 pytest.in）
# 2. 确保在项目根目录
# 3. 确保有 [pytest] 节
# 4. 使用 pytest --version 查看加载的配置
```

### 2. **调试配置**

```bash
# 查看加载的配置
pytest --version

# 查看所有配置选项
pytest --help

# 调试模式
pytest --debug

# 只收集不运行（检查配置）
pytest --collect-only
```

### 3. **配置冲突解决**

```ini
# 如果多个配置文件冲突，优先级：
# pytest.ini > pyproject.toml > tox.ini > setup.cfg

# 建议只使用一个配置文件
# 使用 filterwarnings 处理警告
filterwarnings = 
    error
    ignore::DeprecationWarning
    ignore::UserWarning
```

## 六、pytest.ini 配置速查表

### 配置项速查表
| 配置项 | 默认值 | 描述 | 示例 |
|--------|--------|------|------|
| `pythonpath` | `.` | Python模块搜索路径 | `pythonpath = src` |
| `testpaths` | `.` | 测试文件搜索路径 | `testpaths = tests` |
| `python_files` | `test_*.py *_test.py` | 测试文件模式 | `python_files = test_*.py` |
| `python_functions` | `test_*` | 测试函数模式 | `python_functions = test_* should_*` |
| `python_classes` | `Test*` | 测试类模式 | `python_classes = Test* Spec*` |
| `norecursedirs` | `.* _darcs ...` | 忽略目录 | `norecursedirs = .git __pycache__` |
| `addopts` | 无 | 默认命令行参数 | `addopts = -v --tb=short` |
| `markers` | 无 | 测试标记定义 | `markers = slow: slow tests` |
| `log_cli` | `false` | 控制台日志开关 | `log_cli = true` |
| `log_cli_level` | `WARNING` | 控制台日志级别 | `log_cli_level = INFO` |
| `log_file` | 无 | 日志文件路径 | `log_file = logs/pytest.log` |
| `log_file_level` | `WARNING` | 文件日志级别 | `log_file_level = DEBUG` |
| `xfail_strict` | `false` | XFAIL严格模式 | `xfail_strict = true` |
| `maxfail` | `0` | 最大失败数 | `maxfail = 5` |
| `tbstyle` | `auto` | 回溯样式 | `tbstyle = short` |
| `timeout` | `0` | 测试超时(秒) | `timeout = 30` |
| `minversion` | 无 | 最低pytest版本 | `minversion = 6.0` |

### 常用 addopts 参数
```ini
addopts = 
    -v                  # 详细输出
    -q                  # 安静模式（与-v互斥）
    --tb=short          # 简短回溯
    --tb=no             # 不显示回溯
    --color=yes         # 彩色输出
    --disable-warnings  # 禁用警告
    --durations=10      # 显示最慢的10个测试
    --strict-markers    # 严格标记检查
    --lf                # 只运行上次失败的测试
    --ff                # 先运行失败的测试
    -x                  # 遇到失败就停止
    --maxfail=5         # 达到5个失败就停止
    -k "test_name"      # 只运行名称包含test_name的测试
    -m "marker"         # 只运行特定标记的测试
```

### 覆盖率相关配置
```ini
addopts = 
    --cov=src                   # 测量覆盖率
    --cov-report=html           # HTML报告
    --cov-report=xml            # XML报告
    --cov-report=term-missing   # 终端显示未覆盖
    --cov-fail-under=80         # 覆盖率低于80%时失败
    --cov-append               # 追加覆盖率数据
```

### 报告相关配置
```ini
addopts = 
    --html=report.html         # HTML报告
    --self-contained-html      # 独立的HTML文件
    --junitxml=report.xml      # JUnit XML报告
    --json=report.json         # JSON报告
    --resultlog=report.log     # 结果日志
```


<!-- TOC -->
  * [执行结果](#执行结果)
  * [详细输出选项](#详细输出选项)
    * [1. -v 模式](#1--v-模式)
    * [2. -s 显示打印输出](#2--s-显示打印输出)
    * [3. -q 安静模式](#3--q-安静模式)
    * [4. --tb 回溯控制](#4---tb-回溯控制)
  * [测试分类和标记](#测试分类和标记)
    * [1. 使用 -m 过滤器](#1-使用--m-过滤器)
  * [测试报告](#测试报告)
    * [1. 生成 HTML 报告](#1-生成-html-报告)
    * [2. 生成 JUnit XML 报告](#2-生成-junit-xml-报告)
  * [测试覆盖率报告](#测试覆盖率报告)
<!-- TOC -->

## 执行结果

| 回显符号 | 含义      | 说明                  |
|------|---------|---------------------|
| .    | Passed  | 测试通过                |
| F    | Failed  | 测试失败（AssertionError |
| E    | Error   | 测试出错（其他异常）          |
| s    | Skipped | 跳过测试（skip）          |
| X    | XPASS   | 预期失败但实际通过了（xfail）   |
| x    | XFAIL   | 预期失败且确实失败了（xfail）   |

## 详细输出选项

### 1. -v 模式

```shell
pytest -v

============================= test session starts =============================
collected 3 items

test_sample.py::test_one PASSED                                          [ 33%]
test_sample.py::test_two PASSED                                          [ 66%]
test_sample.py::test_three PASSED                                        [100%]

============================== 3 passed in 0.02s ==============================
```

**特点：**

- 显示每个测试用例的名称
- 显示执行进度百分比
- 更容易定位具体测试

### 2. -s 显示打印输出

```python
def test_with_print():
    print("测试开始")
    result = 2 + 2
    print(f"计算结果: {result}")
    assert result == 4
```

```shell
pytest -s test_print.py

test_print.py 测试开始
计算结果: 4
.
============================== 1 passed in 0.01s ==============================
```

### 3. -q 安静模式

```shell
pytest -q

...
1 passed in 0.02s
```

### 4. --tb 回溯控制

```shell
# 不同回溯级别
pytest --tb=short     # 简短回溯
pytest --tb=no        # 无回溯
pytest --tb=line      # 一行显示错误
pytest --tb=native    # Python标准格式
pytest --tb=long      # 详细回溯（默认）

pytest --tb=short

FAILURES
test_failures.py:2: in test_addition
    assert 1 + 1 == 3
E   assert (1 + 1) == 3
```

## 测试分类和标记

### 1. 使用 -m 过滤器

```python
# test_marks.py
import pytest

@pytest.mark.slow
def test_slow_operation():
    import time
    time.sleep(1)
    assert True

@pytest.mark.fast
def test_fast_operation():
    assert 1 == 1
```

```shell
# 只运行标记为fast的测试
pytest -m fast

# 排除标记为slow的测试
pytest -m "not slow"

# 运行多个标记
pytest -m "fast or slow"
```

## 测试报告

### 1. 生成 HTML 报告

```shell
pip install pytest-html

pytest --html=report.html
```

### 2. 生成 JUnit XML 报告

用于 CI/CD 集成，Jenkins 等工具可以解析

```shell
pytest --junitxml=report.xml
```

## 测试覆盖率报告

```shell
# 安装覆盖率插件
pip install pytest-cov

# 基本覆盖率
pytest --cov=my_module

# 详细覆盖率报告
pytest --cov=my_module --cov-report=html

# 终端显示详细覆盖率
pytest --cov=my_module --cov-report=term-missing
```

### `--cov` 的具体含义

```shell
project/
├── src/                    # 源代码目录
│   ├── module1/
│   │   ├── __init__.py
│   │   └── core.py
│   └── module2/
│       ├── __init__.py
│       └── utils.py
├── tests/
│   ├── test_module1.py
│   └── test_module2.py
└── setup.py
```

```shell
# 对整个项目（当前目录）
pytest --cov

# 对整个src目录进行覆盖率统计
pytest --cov=src

# 或者对特定模块
pytest --cov=src.module1 --cov=src.module2

# 包含测试覆盖率报告
pytest --cov --cov-report=term-missing

# 生成HTML报告
pytest --cov --cov-report=html

# 生成多种格式的报告
pytest --cov \
    --cov-report=term-missing \
    --cov-report=html \
    --cov-report=xml

# 指定覆盖率阈值
pytest --cov --cov-fail-under=80
```

### 覆盖率检查

## 并行执行结果

```shell
pip install pytest-xdist

pytest -n 4  # 使用4个worker并行

```


## 自定义输出格式

### 使用 -r 标志

```shell
# 显示所有测试结果
pytest -ra

# 显示失败和错误
pytest -rf

# 显示通过
pytest -rp

# 显示跳过
pytest -rs

# 显示预期失败
pytest -rx

# 显示预期失败但实际通过
pytest -rX

# 组合使用
pytest -rfEsx

```

**解释 -r 标志**

- f：failed（失败）
- e：error（错误）
- s：skipped（跳过）
- x：xfailed（预期失败）
- X：xpassed（预期失败但实际通过）
- p：passed（通过）
- P：passed with output（有输出的通过测试）
- a：all except passed (p/P)（除了通过的所有结果）
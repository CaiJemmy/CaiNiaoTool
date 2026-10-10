## linux 环境下项目安装

### 配置python环境变量

```shell
export PYTHONPATH=/root/fake:$PYTHONPATH
```

### 安装依赖

* 依赖文件 requirements.txt
* 依赖安装步骤

```shell
# 1. 安装python3-venv
sudo apt update
sudo apt install python3-venv python3-full

# 2. 创建虚拟环境
cd /root/fake
python3 -m venv venv

# 3. 激活虚拟环境
source venv/bin/activate  # Linux/Mac
# 或者
# .\venv\Scripts\activate  # Windows

# 4. 现在可以安装依赖了
pip install -r requirements.txt

# 5. 运行你的程序
python src/email_sender/email_main.py

# 6. 退出虚拟环境
deactivate
```

## 测试用例执行方式

```shell
# 方式1：直接运行脚本（你的方式）
python main.py

# 方式2：使用 pytest 模块运行（可以正常执行）
python -m pytest
```

**关键区别：**

- python main.py：以脚本方式执行，Python 解释器把 main.py 的目录作为当前工作目录
- python -m pytest：以模块方式执行，会把项目根目录加入到 sys.path 中


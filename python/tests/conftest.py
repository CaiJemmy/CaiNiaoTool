import atexit
import shutil
import sys


def post_test_function():
    """在所有测试后执行的函数"""
    print("\n" + "=" * 50)
    print("atexit: 测试执行完成，执行清理...")

    # 执行清理操作
    cleanup()

    print("清理完成")


def cleanup():
    """清理函数"""
    import os
    import glob

    # 获取项目根目录
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    logs_dir = os.path.join(project_root, "logs")

    # 使用 shutil.rmtree 删除非空目录
    if os.path.exists(logs_dir):
        try:
            print(f"删除日志目录: {logs_dir}")
            shutil.rmtree(logs_dir)  # 删除目录及其所有内容
            print("日志目录删除成功")
        except Exception as e:
            print(f"删除日志目录失败: {e}")

    # 清理其他临时文件
    temp_files = glob.glob(os.path.join(project_root, "temp_*.log")) + \
                 glob.glob(os.path.join(project_root, "test_*.tmp"))

    for file in temp_files:
        try:
            os.remove(file)
            print(f"清理文件: {file}")
        except Exception as e:
            print(f"删除文件 {file} 失败: {e}")

    # 删除非根目录下的
    current_path = os.path.dirname(os.path.abspath(__file__))
    if current_path != project_root:
        current_report = os.path.join(current_path, "reports")
        if os.path.exists(current_report):
            try:
                shutil.rmtree(current_report)
                print(f"非根目录的测试报告删除成功：{current_report}")
            except Exception as e:
                print(f"删除非根目录的测试报告失败: {e}")
        coverage_file = os.path.join(current_path, ".coverage")
        if os.path.exists(coverage_file):
            try:
                os.remove(coverage_file)
                print(f"非根目录的覆盖率文件删除成功：{coverage_file}")
            except Exception as e:
                print(f"删除非根目录的覆盖率文件失败: {e}")

# 注册退出函数
atexit.register(post_test_function)

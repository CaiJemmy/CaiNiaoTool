#!/usr/bin/env python3
"""
简单测试脚本
"""
import sys
import os
import time
import pytest

# 添加路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


# 测试夹具，确保每个测试后清理日志系统
@pytest.fixture(autouse=True)
def cleanup_logging():
    """在每个测试后清理日志系统"""
    yield
    # 测试完成后清理日志系统
    try:
        from src.utils.complete_logger.core import shutdown_logging
        shutdown_logging()
        # 给时间清理线程
        time.sleep(0.05)
    except Exception:
        pass


def test_simple():
    """简单测试"""
    print("=== 简单测试开始 ===")

    # 导入并立即使用
    from src.utils.complete_logger import get_logger

    # 获取logger
    logger = get_logger("test_simple")

    # 记录日志
    logger.info("这是一条测试日志")
    logger.debug("调试信息")
    logger.warning("警告信息")

    print("=== 简单测试完成 ===")


def test_multiple():
    """测试多个logger"""
    print("=== 测试多个logger ===")

    from src.utils.complete_logger import get_logger

    # 创建多个不同配置的logger
    logger1 = get_logger("test1", level="DEBUG", console=True, file=False)
    logger2 = get_logger("test2", level="INFO", console=False, file=True)
    logger3 = get_logger("test3", level="WARNING", console=True, file=True)

    logger1.debug("Logger1 调试信息")
    logger2.info("Logger2 普通信息")
    logger3.warning("Logger3 警告信息")

    print("=== 多个logger测试完成 ===")


def test_decorator():
    """测试装饰器"""
    from src.utils.complete_logger import log_function_call

    @log_function_call(logger_name="test_decorator")
    def add(a, b):
        return a + b

    @log_function_call(logger_name="test_decorator", log_args=False)
    def multiply(a, b):
        return a * b

    add(2, 3)
    multiply(4, 5)


def test_context():
    """测试上下文管理器"""
    from src.utils.complete_logger import LogBlock

    with LogBlock("测试代码块", logger_name="test_context"):
        data = list(range(10))
        var = [x * 2 for x in data]


def test_log_block_with_exception():
    """测试带异常的上下文管理器"""
    from src.utils.complete_logger import LogBlock

    try:
        with LogBlock("测试异常代码块", logger_name="test_exception"):
            raise ValueError("测试异常")
    except ValueError as e:
        print(f"捕获到预期异常: {e}")


def test_safe_shutdown():
    """测试安全关闭"""
    print("=== 测试安全关闭 ===")

    from src.utils.complete_logger import get_logger

    # 先获取一个logger并记录一些日志
    logger = get_logger("test_shutdown")
    logger.info("测试安全关闭 - 第一条日志")
    logger.warning("测试安全关闭 - 警告日志")

    # 手动关闭
    from src.utils.complete_logger.core import shutdown_logging
    shutdown_logging()

    # 给时间让线程关闭
    time.sleep(0.1)

    # 再次获取logger（应该能正常工作）
    logger2 = get_logger("test_shutdown_restart")
    logger2.info("重新启动后的日志")

    print("=== 安全关闭测试完成 ===")


def test_thread_safe_logging():
    """测试线程安全"""
    print("=== 测试线程安全 ===")

    import threading
    from src.utils.complete_logger import get_logger

    logger = get_logger("test_thread")

    # 记录线程安全的日志
    def worker(worker_id):
        for i in range(3):
            logger.info(f"线程 {worker_id} - 消息 {i}")
            time.sleep(0.01)

    threads = []
    for i in range(3):
        t = threading.Thread(target=worker, args=(i,))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    print("=== 线程安全测试完成 ===")


def test_file_logging():
    """测试文件日志"""
    print("=== 测试文件日志 ===")

    from src.utils.complete_logger import get_logger

    # 创建一个只写文件的logger
    logger = get_logger("test_file",
                        level="INFO",
                        console=True,
                        file=True,
                        log_dir="logs/test",
                        max_bytes=1024,  # 1KB，便于测试轮转
                        backup_count=2)

    # 写入一些日志
    for i in range(10):
        logger.info(f"测试文件日志 {i}")

    print("=== 文件日志测试完成 ===")
    print("请检查 logs/test/test_file.log 文件")


def test_different_formats():
    """测试不同的日志格式"""
    print("=== 测试不同的日志格式 ===")

    from src.utils.complete_logger import get_logger

    # 简单格式
    logger1 = get_logger("simple_format",
                         format_str='%(asctime)s - %(levelname)s - %(message)s',
                         datefmt='%H:%M:%S')

    # 详细格式
    logger2 = get_logger("detailed_format",
                         format_str='[%(asctime)s] [%(name)s] [%(levelname)s] %(message)s',
                         datefmt='%Y-%m-%d %H:%M:%S')

    logger1.info("简单格式的日志")
    logger2.info("详细格式的日志")

    print("=== 格式测试完成 ===")

#
# # Pytest兼容的测试函数
# def test_all():
#     """运行所有测试"""
#     print("\n" + "=" * 50)
#     print("开始运行所有测试")
#     print("=" * 50 + "\n")
#
#     tests = [
#         test_simple,
#         test_multiple,
#         test_decorator,
#         test_context,
#         test_log_block_with_exception,
#         test_safe_shutdown,
#         test_thread_safe_logging,
#         test_file_logging,
#         test_different_formats,
#     ]
#
#     results = []
#     for i, test_func in enumerate(tests, 1):
#         print(f"\n[{i}/{len(tests)}] 运行测试: {test_func.__name__}")
#         print("-" * 40)
#
#         try:
#             test_func()
#             results.append(True)
#             print(f"✓ {test_func.__name__} 通过")
#         except Exception as e:
#             results.append(False)
#             print(f"✗ {test_func.__name__} 失败: {e}")
#             import traceback
#             traceback.print_exc()
#
#         # 测试间短暂暂停
#         time.sleep(0.05)
#
#     # 清理日志系统
#     try:
#         from src.utils.complete_logger import shutdown_logging
#         shutdown_logging()
#         time.sleep(0.1)
#     except Exception:
#         pass
#
#     # 输出结果
#     print("\n" + "=" * 50)
#     print("测试结果汇总")
#     print("=" * 50)
#     passed = sum(results)
#     total = len(results)
#     print(f"总测试数: {total}")
#     print(f"通过数: {passed}")
#     print(f"失败数: {total - passed}")
#
#     if passed == total:
#         print("\n🎉 所有测试通过！")
#         return 0
#     else:
#         print(f"\n⚠  {total - passed} 个测试失败")
#         return 1
#
#
# # Pytest会自动发现test_开头的函数
# # 以下是兼容直接运行的main函数
# def main():
#     """主函数"""
#     print("开始测试...\n")
#
#     try:
#         return test_all()
#     except KeyboardInterrupt:
#         print("\n\n测试被用户中断")
#         # 确保清理
#         try:
#             from src.utils.complete_logger import shutdown_logging
#             shutdown_logging()
#             time.sleep(0.1)
#         except Exception:
#             pass
#         return 1
#     except Exception as e:
#         print(f"测试失败: {e}")
#         import traceback
#         traceback.print_exc()
#
#         # 确保清理
#         try:
#             from src.utils.complete_logger import shutdown_logging
#             shutdown_logging()
#             time.sleep(0.1)
#         except Exception:
#             pass
#
#         return 1
#
#
# if __name__ == "__main__":
#     sys.exit(main())

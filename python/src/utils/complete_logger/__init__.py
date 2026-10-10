"""
Complete Logger - 一个功能完整的Python日志工具包
"""

# 导入基础功能
from .core import (
    LogLevel,
    LoggerConfig,
    ColoredFormatter,
    log_function_call,
    LogBlock,
    log_performance,
    get_logger,
    setup_logging
)

# 可选的高级功能
try:
    from .utils import (
        log_json_data,
        log_dict_as_table,
        analyze_log_file,
        get_log_statistics,
        LogMonitor,
        PerformanceProfiler,
        compress_log_files
    )
except ImportError:
    # 提供简单的兼容实现
    import json

    def log_json_data(logger, data, prefix="", level="INFO"):
        """记录JSON数据"""
        import json
        log_method = getattr(logger, level.lower())
        log_method(f"{prefix}{json.dumps(data, ensure_ascii=False, indent=2)}")

    def log_dict_as_table(logger, data, title="", level="INFO"):
        """记录字典为表格"""
        log_method = getattr(logger, level.lower())
        if title:
            log_method(title)

        max_key_len = max(len(str(k)) for k in data.keys()) if data else 0
        for key, value in data.items():
            log_method(f"  {str(key):<{max_key_len}} : {value}")

__version__ = "1.0.0"
__author__ = "Your Name"

# 动态构建 __all__
__all__ = [
    'LogLevel',
    'LoggerConfig',
    'ColoredFormatter',
    'log_function_call',
    'LogBlock',
    'log_performance',
    'get_logger',
    'setup_logging',
]

# 添加可选功能到 __all__
_optional = [
    'log_json_data',
    'log_dict_as_table',
    'analyze_log_file',
    'get_log_statistics',
    'LogMonitor',
    'PerformanceProfiler',
    'compress_log_files',
]

for func in _optional:
    if func in globals():
        __all__.append(func)

# 重要：不要在模块级别创建任何logger实例
# 这会导致死锁问题

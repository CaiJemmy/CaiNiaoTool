"""日志工具函数"""
import logging
import json
import re
import time
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Callable, Union
from pathlib import Path
from collections import defaultdict, Counter


def log_json_data(logger: logging.Logger, data: Dict[str, Any], prefix: str = "", level: str = "DEBUG"):
    """以JSON格式记录数据"""
    try:
        json_str = json.dumps(data, ensure_ascii=False, indent=2)
        log_level = getattr(logger, level.lower())
        log_level(f"{prefix}JSON数据:\n{json_str}")
    except Exception as e:
        logger.error(f"{prefix}记录JSON数据失败: {e}")


def log_dict_as_table(logger: logging.Logger, data: Dict[str, Any], title: str = "", level: str = "DEBUG"):
    """以表格形式记录字典数据"""
    if not data:
        log_func = getattr(logger, level.lower())
        log_func(f"{title}空数据")
        return

    try:
        max_key_len = max(len(str(k)) for k in data.keys())
        max_val_len = max(len(str(v)) for v in data.values())

        # 限制最大宽度
        max_key_len = min(max_key_len, 50)
        max_val_len = min(max_val_len, 100)

        border = "+" + "-" * (max_key_len + 2) + "+" + "-" * (max_val_len + 2) + "+"

        lines = []
        if title:
            lines.append(f"\n{title}")
        lines.append(border)

        for key, value in data.items():
            key_str = str(key)[:max_key_len].ljust(max_key_len)
            val_str = str(value)[:max_val_len].ljust(max_val_len)
            lines.append(f"| {key_str} | {val_str} |")

        lines.append(border)

        log_func = getattr(logger, level.lower())
        log_func("\n".join(lines))

    except Exception as e:
        logger.error(f"记录表格数据失败: {e}")


def log_list_as_table(logger: logging.Logger, data: List[Dict[str, Any]], title: str = "", level: str = "DEBUG"):
    """以表格形式记录列表数据"""
    if not data:
        log_func = getattr(logger, level.lower())
        log_func(f"{title}空数据")
        return

    try:
        # 获取所有键
        all_keys = set()
        for item in data:
            all_keys.update(item.keys())

        # 计算每列的最大宽度
        col_widths = {}
        for key in all_keys:
            max_len = len(str(key))
            for item in data:
                if key in item:
                    max_len = max(max_len, len(str(item[key])))
            col_widths[key] = min(max_len, 50)  # 限制最大宽度

        # 构建表格
        lines = []
        if title:
            lines.append(f"\n{title}")

        # 表头
        header = "| " + " | ".join(str(key).ljust(col_widths[key]) for key in all_keys) + " |"
        separator = "+" + "+".join("-" * (col_widths[key] + 2) for key in all_keys) + "+"

        lines.append(separator)
        lines.append(header)
        lines.append(separator)

        # 数据行
        for item in data:
            row = "| " + " | ".join(str(item.get(key, "")).ljust(col_widths[key]) for key in all_keys) + " |"
            lines.append(row)

        lines.append(separator)

        log_func = getattr(logger, level.lower())
        log_func("\n".join(lines))

    except Exception as e:
        logger.error(f"记录列表表格失败: {e}")


def analyze_log_file(
        log_file: Union[str, Path],
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        level: Optional[str] = None,
        keyword: Optional[str] = None,
        module: Optional[str] = None,
        max_results: int = 1000
) -> List[Dict[str, Any]]:
    """
    分析日志文件

    Args:
        log_file: 日志文件路径
        start_time: 开始时间
        end_time: 结束时间
        level: 日志级别
        keyword: 关键词
        module: 模块名
        max_results: 最大返回结果数

    Returns:
        匹配的日志记录列表
    """
    results = []

    # 常见的日志格式模式
    patterns = [
        # 标准格式: 2023-01-01 12:00:00 | ThreadName | LEVEL | module | file.py:123 | message
        r'(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \| '
        r'(?P<thread>[\w-]+) \| '
        r'(?P<level>\w+) \| '
        r'(?P<name>\w+) \| '
        r'(?P<file>\w+\.\w+):(?P<line>\d+) \| '
        r'(?P<message>.*)',

        # 简单格式: 2023-01-01 12:00:00 - INFO - module - message
        r'(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) - '
        r'(?P<level>\w+) - '
        r'(?P<name>\w+) - '
        r'(?P<message>.*)'
    ]

    compiled_patterns = [re.compile(pattern) for pattern in patterns]

    try:
        log_path = Path(log_file)
        if not log_path.exists():
            print(f"日志文件不存在: {log_file}")
            return results

        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            line_count = 0
            for line in f:
                line_count += 1
                if len(results) >= max_results:
                    break

                line = line.strip()
                if not line:
                    continue

                record = None
                for pattern in compiled_patterns:
                    match = pattern.match(line)
                    if match:
                        record = match.groupdict()
                        # 添加行号
                        record['line_no'] = line_count
                        break

                if not record:
                    # 无法解析的日志行
                    continue

                # 时间过滤
                if 'timestamp' in record:
                    try:
                        record_time = datetime.strptime(record['timestamp'], '%Y-%m-%d %H:%M:%S')
                        if start_time and record_time < start_time:
                            continue
                        if end_time and record_time > end_time:
                            continue
                    except ValueError:
                        # 时间格式不匹配，跳过时间过滤
                        pass

                # 级别过滤
                if level and 'level' in record:
                    if record['level'].upper() != level.upper():
                        continue

                # 模块过滤
                if module and 'name' in record:
                    if module.lower() not in record['name'].lower():
                        continue

                # 关键词过滤
                if keyword and 'message' in record:
                    if keyword.lower() not in record['message'].lower():
                        continue

                results.append(record)

        return results

    except Exception as e:
        print(f"分析日志文件失败: {e}")
        return results


def get_log_statistics(
        log_file: Union[str, Path],
        time_range: Optional[tuple] = None
) -> Dict[str, Any]:
    """获取日志统计信息"""
    stats = {
        'file_info': {},
        'summary': {
            'total_lines': 0,
            'parsed_lines': 0,
            'empty_lines': 0,
            'error_lines': 0
        },
        'levels': Counter(),
        'modules': Counter(),
        'hourly_distribution': Counter(),
        'daily_distribution': Counter(),
        'top_errors': [],
        'performance': {
            'processing_time': 0
        }
    }

    start_time = time.time()

    try:
        log_path = Path(log_file)
        stats['file_info'] = {
            'path': str(log_path.absolute()),
            'size': log_path.stat().st_size if log_path.exists() else 0,
            'modified': datetime.fromtimestamp(log_path.stat().st_mtime).isoformat()
            if log_path.exists() else None,
            'exists': log_path.exists()
        }

        if not log_path.exists():
            return stats

        pattern = re.compile(
            r'(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \| '
            r'.*? \| '
            r'(?P<level>\w+) \| '
            r'(?P<name>\w+) \| '
            r'.*? \| '
            r'(?P<message>.*)'
        )

        error_messages = []

        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                stats['summary']['total_lines'] += 1

                line = line.strip()
                if not line:
                    stats['summary']['empty_lines'] += 1
                    continue

                match = pattern.match(line)
                if match:
                    stats['summary']['parsed_lines'] += 1
                    record = match.groupdict()

                    # 按级别统计
                    level = record['level']
                    stats['levels'][level] += 1

                    # 按模块统计
                    module = record['name']
                    stats['modules'][module] += 1

                    # 按小时统计
                    if 'timestamp' in record:
                        try:
                            hour = record['timestamp'][11:13]
                            stats['hourly_distribution'][hour] += 1

                            day = record['timestamp'][:10]
                            stats['daily_distribution'][day] += 1
                        except:
                            pass

                    # 收集错误信息
                    if level in ['ERROR', 'CRITICAL']:
                        stats['summary']['error_lines'] += 1
                        error_messages.append({
                            'time': record.get('timestamp', ''),
                            'module': module,
                            'level': level,
                            'message': record['message'][:200]  # 截断长消息
                        })

        # 获取最常见的错误
        stats['top_errors'] = sorted(
            error_messages,
            key=lambda x: x['time'],
            reverse=True
        )[:10]

        # 计算百分比
        if stats['summary']['total_lines'] > 0:
            stats['summary']['parsed_percentage'] = (
                    stats['summary']['parsed_lines'] / stats['summary']['total_lines'] * 100
            )
            stats['summary']['error_percentage'] = (
                    stats['summary']['error_lines'] / stats['summary']['total_lines'] * 100
            )

        # 转换Counter为普通字典
        stats['levels'] = dict(stats['levels'])
        stats['modules'] = dict(stats['modules'])
        stats['hourly_distribution'] = dict(stats['hourly_distribution'])
        stats['daily_distribution'] = dict(stats['daily_distribution'])

    except Exception as e:
        stats['error'] = str(e)

    finally:
        stats['performance']['processing_time'] = time.time() - start_time

    return stats


def export_logs_to_csv(
        log_file: Union[str, Path],
        output_file: Union[str, Path],
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        level: Optional[str] = None
):
    """导出日志到CSV文件"""
    import csv

    try:
        logs = analyze_log_file(log_file, start_time, end_time, level)

        if not logs:
            print("没有找到匹配的日志记录")
            return

        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with open(output_path, 'w', newline='', encoding='utf-8') as f:
            if logs:
                # 获取所有字段
                fieldnames = set()
                for log in logs:
                    fieldnames.update(log.keys())

                writer = csv.DictWriter(f, fieldnames=sorted(fieldnames))
                writer.writeheader()
                writer.writerows(logs)

        print(f"成功导出 {len(logs)} 条日志到 {output_file}")

    except Exception as e:
        print(f"导出日志失败: {e}")


class LogMonitor:
    """日志监控器"""

    def __init__(
            self,
            log_dir: Union[str, Path],
            check_interval: int = 60,
            alert_threshold_mb: float = 100.0
    ):
        """
        Args:
            log_dir: 日志目录
            check_interval: 检查间隔（秒）
            alert_threshold_mb: 告警阈值（MB）
        """
        self.log_dir = Path(log_dir)
        self.check_interval = check_interval
        self.alert_threshold_mb = alert_threshold_mb
        self.running = False
        self.monitor_thread = None
        self.callbacks: List[Callable] = []
        self.alert_callbacks: List[Callable] = []
        self._last_check = {}
        self._lock = threading.Lock()

    def add_callback(self, callback: Callable):
        """添加常规回调函数"""
        self.callbacks.append(callback)

    def add_alert_callback(self, callback: Callable):
        """添加告警回调函数"""
        self.alert_callbacks.append(callback)

    def _check_logs(self):
        """检查日志文件"""
        try:
            # 获取所有日志文件
            log_files = list(self.log_dir.glob("*.log"))

            for log_file in log_files:
                file_stat = log_file.stat()

                # 检查文件大小
                file_size_mb = file_stat.st_size / (1024 * 1024)

                # 检查最后修改时间
                mtime = datetime.fromtimestamp(file_stat.st_mtime)
                time_diff = datetime.now() - mtime

                # 准备检查结果
                check_result = {
                    'file': str(log_file.absolute()),
                    'size_mb': round(file_size_mb, 2),
                    'last_modified': mtime.isoformat(),
                    'time_since_last_modified': str(time_diff),
                    'needs_alert': False,
                    'alert_reason': None
                }

                # 检查是否需要告警
                if file_size_mb > self.alert_threshold_mb:
                    check_result['needs_alert'] = True
                    check_result[
                        'alert_reason'] = f"文件大小超过阈值: {file_size_mb:.2f}MB > {self.alert_threshold_mb}MB"

                # 检查文件是否长时间未更新
                if time_diff > timedelta(hours=24):
                    check_result['needs_alert'] = True
                    check_result['alert_reason'] = f"文件超过24小时未更新: {time_diff}"

                # 触发常规回调
                for callback in self.callbacks:
                    try:
                        callback(check_result)
                    except Exception as e:
                        print(f"回调函数执行失败: {e}")

                # 触发告警回调
                if check_result['needs_alert']:
                    for callback in self.alert_callbacks:
                        try:
                            callback(check_result)
                        except Exception as e:
                            print(f"告警回调函数执行失败: {e}")

                # 记录最后检查时间
                self._last_check[str(log_file)] = datetime.now()

        except Exception as e:
            print(f"检查日志失败: {e}")

    def start(self):
        """启动监控"""
        if not self.running:
            self.running = True
            self.monitor_thread = threading.Thread(
                target=self._monitor,
                daemon=True,
                name="LogMonitor"
            )
            self.monitor_thread.start()
            print(f"日志监控已启动，检查间隔: {self.check_interval}秒")

    def _monitor(self):
        """监控循环"""
        while self.running:
            self._check_logs()
            time.sleep(self.check_interval)

    def stop(self):
        """停止监控"""
        self.running = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=self.check_interval * 2)
        print("日志监控已停止")

    def get_last_check_time(self, log_file: Union[str, Path]) -> Optional[datetime]:
        """获取指定文件的上次检查时间"""
        return self._last_check.get(str(Path(log_file).absolute()))


def create_log_archive(
        log_dir: Union[str, Path],
        output_dir: Union[str, Path],
        days_to_keep: int = 30,
        compress: bool = True
):
    """创建日志归档"""
    import shutil
    from datetime import datetime, timedelta

    try:
        log_path = Path(log_dir)
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        cutoff_date = datetime.now() - timedelta(days=days_to_keep)

        archived_files = []

        for log_file in log_path.glob("*.log"):
            # 检查文件修改时间
            mtime = datetime.fromtimestamp(log_file.stat().st_mtime)

            if mtime < cutoff_date:
                # 创建归档文件名
                archive_name = f"{log_file.stem}_{mtime.strftime('%Y%m%d')}.log"
                if compress:
                    archive_name += ".gz"

                archive_path = output_path / archive_name

                # 复制文件
                if compress:
                    import gzip
                    with open(log_file, 'rb') as f_in:
                        with gzip.open(archive_path, 'wb') as f_out:
                            shutil.copyfileobj(f_in, f_out)
                else:
                    shutil.copy2(log_file, archive_path)

                archived_files.append(str(archive_path))

                # 删除原文件
                log_file.unlink()

        return archived_files

    except Exception as e:
        print(f"创建日志归档失败: {e}")
        return []


# 性能分析装饰器
class PerformanceProfiler:
    """性能分析器"""

    def __init__(self, logger_name: str = "performance"):
        self.logger = logging.getLogger(logger_name)
        self.measurements = {}

    def measure(self, name: str):
        """测量代码块执行时间"""
        return self.MeasurementContext(self, name)

    class MeasurementContext:
        def __init__(self, profiler, name):
            self.profiler = profiler
            self.name = name
            self.start_time = None

        def __enter__(self):
            self.start_time = time.perf_counter()
            return self

        def __exit__(self, exc_type, exc_val, exc_tb):
            elapsed = time.perf_counter() - self.start_time
            self.profiler.measurements[self.name] = elapsed
            self.profiler.logger.info(f"{self.name} 执行耗时: {elapsed:.6f}秒")

    def get_report(self) -> Dict[str, float]:
        """获取性能报告"""
        return self.measurements.copy()

    def clear(self):
        """清除所有测量结果"""
        self.measurements.clear()


# 内存使用监控
def log_memory_usage(logger: logging.Logger, prefix: str = ""):
    """记录内存使用情况"""
    try:
        import psutil
        import os

        process = psutil.Process(os.getpid())
        memory_info = process.memory_info()

        logger.info(
            f"{prefix}内存使用 - "
            f"RSS: {memory_info.rss / 1024 / 1024:.2f}MB, "
            f"VMS: {memory_info.vms / 1024 / 1024:.2f}MB, "
            f"CPU: {process.cpu_percent():.1f}%"
        )

    except ImportError:
        logger.warning(f"{prefix}内存监控需要安装psutil库")
    except Exception as e:
        logger.error(f"{prefix}获取内存使用失败: {e}")

"""
日志模块核心功能 - 带敏感信息过滤的简化版
"""
import inspect
import logging
import logging.handlers
import sys
import os
import re
import json
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any, List, Set, Pattern
from dataclasses import dataclass, asdict, field
import time
import atexit


class LogLevel:
    """日志级别常量"""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


@dataclass
class SensitiveConfig:
    """敏感信息配置"""
    enable_sensitive_filter: bool = True  # 是否启用敏感信息过滤
    keywords: List[str] = field(default_factory=lambda: [
        "password", "passwd", "pwd", "secret", "token",
        "key", "auth", "credential", "api_key", "api_secret",
        "private_key", "secret_key", "access_token", "refresh_token",
        "authorization", "bearer", "jwt", "session",
        "phone", "mobile", "tel", "telephone",
        # "email", "mail", "username", "user",
        "id_card", "identity", "card_no", "card_number",
        "bank_card", "account", "bank_account", "bank_no",
        "credit_card", "debit_card", "cvv", "cvc",
        "address", "location", "ip", "mac",
        "ssn", "social_security", "national_id",
        "passport", "driver_license", "license",
        "birthday", "birth_date", "age",
        "salary", "income", "balance",
        "health", "medical", "disease", "ciphertext"
    ])

    # 需要脱敏的URL参数
    url_params: List[str] = field(default_factory=lambda: [
        "password", "passwd", "pwd", "token", "secret",
        "key", "auth", "api_key", "api_secret", "access_token"
    ])

    # 特殊模式：信用卡号、手机号、身份证号等
    special_patterns: List[str] = field(default_factory=lambda: [
        r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',  # 16位信用卡号
        r'\b\d{3}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{3}\b',  # 15位信用卡号
        r'\b\d{16,19}\b',  # 银行卡号（16-19位）
        r'\b1[3-9]\d{9}\b',  # 手机号
        r'\b\d{17}[\dXx]\b',  # 身份证号
        r'\b\d{6}\b',  # 6位验证码
        r'\b\d{4}\b',  # 4位验证码
    ])

    mask_char: str = '*'  # 脱敏字符
    mask_length: int = 5  # 脱敏长度
    partial_mask: bool = False  # 是否部分脱敏（保留首尾）
    keep_first_last: int = 1  # 保留首尾字符数
    always_mask_keywords: bool = True  # 新增：是否总是脱敏关键词对应的值

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return asdict(self)

    def to_json(self) -> str:
        """转换为JSON字符串"""
        return json.dumps(self.to_dict(), ensure_ascii=False, indent=2)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'SensitiveConfig':
        """从字典创建配置"""
        return cls(**data)

    @classmethod
    def from_json(cls, json_str: str) -> 'SensitiveConfig':
        """从JSON字符串创建配置"""
        data = json.loads(json_str)
        return cls.from_dict(data)


@dataclass
class LoggerConfig:
    """日志配置数据类"""
    name: str = "app"
    level: str = "INFO"
    log_dir: Optional[str] = None
    log_file: Optional[str] = None
    max_bytes: int = 10 * 1024 * 1024  # 10MB
    backup_count: int = 5
    console: bool = True
    file: bool = True
    format_str: str = '%(asctime)s.%(msecs)03d | %(threadName)-12s | %(thread)-8d | %(levelname)-8s | %(filename)s:%(lineno)d | %(message)s'
    datefmt: str = '%Y-%m-%d %H:%M:%S'
    encoding: str = 'utf-8'
    enable_sensitive_filter: bool = True  # 是否启用敏感信息过滤
    sensitive_config: SensitiveConfig = field(default_factory=SensitiveConfig)

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return asdict(self)


# 定义日志级别颜色映射（用于控制台）
COLORS = {
    'DEBUG': '\033[36m',  # 青色
    'INFO': '\033[32m',  # 绿色
    'WARNING': '\033[33m',  # 黄色
    'ERROR': '\033[31m',  # 红色
    'CRITICAL': '\033[35m',  # 洋红色
}
RESET = '\033[0m'


class SensitiveFilter(logging.Filter):
    """敏感信息过滤器 - 修复版"""

    def __init__(self, config: SensitiveConfig):
        super().__init__()
        self.config = config
        self._compiled_patterns = []
        self._compiled_special_patterns = []
        self._processing_ids = set()  # 添加：用于跟踪正在处理的对象
        self._init_patterns()

    def _init_patterns(self):
        """初始化正则表达式模式"""
        # 编译特殊模式
        for pattern in self.config.special_patterns:
            try:
                compiled = re.compile(pattern)
                self._compiled_special_patterns.append(compiled)
            except re.error as e:
                print(f"警告：无效的特殊模式 '{pattern}': {e}")

        # 编译通用模式（用于处理键值对）
        self._compiled_patterns = []
        for keyword in self.config.keywords:
            try:
                # 创建更精确的键值对正则
                # 支持: key=value, key:value, key = value, key: value
                # 支持引号: key="value", key='value'
                pattern_str = rf'(?i)\b{re.escape(keyword)}\b["\']?\s*[:=]\s*["\']?([^"\'\s,&]+)["\']?'
                pattern = re.compile(pattern_str, re.IGNORECASE)
                self._compiled_patterns.append(pattern)
            except re.error as e:
                print(f"警告：无效的正则模式 '{keyword}': {e}")

    def mask_value(self, value: str, key: str = None, force_mask: bool = False) -> str:
        """对值进行脱敏处理

        Args:
            value: 要脱敏的值
            key: 对应的键名（用于判断是否敏感键）
            force_mask: 是否强制脱敏
        """
        if not value:
            return value

        value_str = str(value)

        # 如果强制脱敏，直接应用脱敏
        if force_mask:
            return self._apply_mask(value_str)

        # 如果配置了总是脱敏关键词，且提供了键名且是敏感键，直接脱敏
        if (self.config.always_mask_keywords and key and
                self._is_sensitive_key(key)):
            return self._apply_mask(value_str)

        # 否则进行智能判断
        # 1. 检查是否为常见的安全格式
        if self._is_safe_content(value_str):
            return value_str

        # 2. 检查是否为长数字（可能是敏感信息）
        if self._is_potentially_sensitive_number(value_str):
            return self._apply_mask(value_str)

        # 3. 检查是否包含敏感关键词
        value_lower = value_str.lower()
        for keyword in self.config.keywords:
            if keyword.lower() in value_lower:
                # 包含敏感关键词，需要脱敏
                return self._apply_mask(value_str)

        return value_str

    def _is_sensitive_key(self, key: str) -> bool:
        """判断键名是否为敏感键"""
        if not key:
            return False

        key_lower = key.lower()
        for keyword in self.config.keywords:
            # 精确匹配关键词
            if key_lower == keyword.lower():
                return True
            # 支持变体匹配
            if (key_lower == keyword.lower().replace('_', '-') or
                    key_lower == keyword.lower().replace('-', '_')):
                return True
        return False

    def _is_safe_content(self, value_str: str) -> bool:
        """判断是否为安全内容（不需要脱敏）"""
        # 1. 检查是否为常见的时间、日期、持续时间格式
        # 持续时间模式（如 1.234567）
        if re.match(r'^\d+\.\d+$', value_str):
            return True

        # 时间格式（如 12:34:56）
        if re.match(r'^\d{1,2}:\d{2}(:\d{2})?(\.\d+)?$', value_str):
            return True

        # 日期格式（如 2024-01-01）
        if re.match(r'^\d{4}-\d{1,2}-\d{1,2}', value_str):
            return True

        # 2. 检查是否为网络地址
        # IPv4地址
        if re.match(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$', value_str):
            return True

        # IPv6地址（简化检查）
        if ':' in value_str and re.match(r'^[0-9a-fA-F:]+$', value_str):
            return True

        # MAC地址
        if re.match(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$', value_str):
            return True

        # 3. 检查是否为布尔值或空值
        if value_str.lower() in ['true', 'false', 'null', 'none', '']:
            return True

        # 4. 检查是否为短数字（可能不是敏感信息）
        if re.match(r'^\d{1,6}$', value_str):
            # 6位以下的纯数字通常不是敏感信息
            return True

        return False

    def _is_potentially_sensitive_number(self, value_str: str) -> bool:
        """判断是否为潜在的敏感数字"""
        # 如果是纯数字且长度超过一定阈值，可能是敏感信息
        if re.match(r'^\d+$', value_str):
            length = len(value_str)
            # 身份证号长度：15或18位
            if length in [15, 18]:
                return True
            # 手机号长度：11位
            if length == 11 and value_str.startswith('1'):
                return True
            # 银行卡号长度：16-19位
            if 16 <= length <= 19:
                return True
            # 其他长数字也可能需要脱敏
            # if length >= 10:
            #     return True

        return False

    def _apply_mask(self, value_str: str) -> str:
        """应用脱敏"""
        if not value_str:
            return value_str

        # 如果启用了部分脱敏，保留首尾字符
        if self.config.partial_mask and len(value_str) > 2 * self.config.keep_first_last:
            keep = self.config.keep_first_last
            first_part = value_str[:keep]
            last_part = value_str[-keep:] if keep > 0 else ""
            middle_length = min(self.config.mask_length, len(value_str) - 2 * keep)
            middle_part = self.config.mask_char * middle_length
            return f"{first_part}{middle_part}{last_part}"
        else:
            # 完全脱敏
            mask_len = min(self.config.mask_length, len(value_str))
            return self.config.mask_char * mask_len

    def filter_sensitive_keywords(self, message: str) -> str:
        """过滤敏感关键词 - 修复版"""
        if not self.config.enable_sensitive_filter:
            return message

        result = message

        # 1. 首先处理URL参数（因为URL参数有明确的格式）
        result = self._process_url_parameters(result)

        # 2. 处理通用键值对模式
        result = self._process_key_value_pairs(result)

        # 3. 处理特殊模式（身份证号、手机号等）
        result = self._process_special_patterns(result)

        return result

    def _process_url_parameters(self, message: str) -> str:
        """专门处理URL参数 - 修复版"""
        result = message

        for param in self.config.url_params:
            # 处理 ?param=value 和 &param=value 格式
            patterns = [
                fr'([?&]{re.escape(param)})=([^&]+)',  # URL中的参数
                fr'\b{re.escape(param)}=([^&\s]+)',  # 单独的param=value
            ]

            for pattern_str in patterns:
                try:
                    pattern = re.compile(pattern_str, re.IGNORECASE)

                    def replace_param(match: re.Match) -> str:
                        """替换URL参数"""
                        full_match = match.group(0)
                        groups = match.groups()

                        if len(groups) >= 2:
                            # 模式1: ([?&]param)=([^&]+)
                            prefix = groups[0]  # [?&]param
                            value = groups[1]
                            # URL参数总是脱敏
                            masked_value = self._apply_mask(value)
                            return f"{prefix}={masked_value}"
                        elif len(groups) >= 1:
                            # 模式2: \bparam=([^&\s]+)
                            param_part = full_match[:full_match.find('=') + 1]
                            value = groups[0]
                            masked_value = self._apply_mask(value)
                            return f"{param_part}{masked_value}"

                        return full_match

                    result = pattern.sub(replace_param, result)
                except re.error as e:
                    print(f"警告：URL参数正则编译错误 '{pattern_str}': {e}")

        return result

    def _process_key_value_pairs(self, message: str) -> str:
        """处理键值对格式 - 修复版"""
        result = message

        for pattern in self._compiled_patterns:
            def replace_kv(match: re.Match) -> str:
                """替换键值对"""
                full_match = match.group(0)
                groups = match.groups()

                if len(groups) >= 1:
                    # 找到键名的结束位置
                    key_end = full_match.find('=') if '=' in full_match else full_match.find(':')
                    if key_end > 0:
                        key_part = full_match[:key_end]
                        value = groups[0]

                        # 提取键名（不带引号）
                        key_match = re.search(r'\b([\w-]+)\b', key_part)
                        key_name = key_match.group(1) if key_match else ""

                        # 键值对中的敏感键总是脱敏
                        masked_value = self.mask_value(value, key=key_name, force_mask=True)

                        # 重新构建字符串，保持原始格式
                        separator = '=' if '=' in full_match else ':'
                        # 保持原始的空格和引号格式
                        quote_match = re.search(r'(["\']?)' + re.escape(value) + r'(["\']?)', full_match)
                        if quote_match:
                            open_quote = quote_match.group(1) or ''
                            close_quote = quote_match.group(2) or ''
                            return f"{key_part}{separator}{open_quote}{masked_value}{close_quote}"
                        else:
                            return f"{key_part}{separator}{masked_value}"

                return full_match

            result = pattern.sub(replace_kv, result)

        return result

    def _process_special_patterns(self, message: str) -> str:
        """处理特殊模式（身份证号、手机号等）"""
        result = message

        for pattern in self._compiled_special_patterns:
            def replace_match(match: re.Match) -> str:
                matched_text = match.group(0)
                # 特殊模式匹配的内容强制脱敏
                return self.mask_value(matched_text, force_mask=True)

            result = pattern.sub(replace_match, result)

        return result

    def filter(self, record: logging.LogRecord) -> bool:
        """过滤日志记录"""
        if not self.config.enable_sensitive_filter:
            return True

        try:
            # 对消息进行脱敏
            if hasattr(record, 'msg') and record.msg:
                # 重置处理状态
                self._processing_ids = set()
                record.msg = self.filter_sensitive_keywords(str(record.msg))

            # 对参数进行脱敏
            if hasattr(record, 'args') and record.args:
                # 重置处理状态
                self._processing_ids = set()
                args = list(record.args)
                for i, arg in enumerate(args):
                    if isinstance(arg, (str, int, float)):
                        args[i] = self.filter_sensitive_keywords(str(arg))
                    elif isinstance(arg, dict):
                        args[i] = self.mask_dict(arg)
                    elif isinstance(arg, list):
                        args[i] = self.mask_list(arg)
                record.args = tuple(args)

            return True
        except Exception as e:
            # 脱敏失败时不阻塞日志，但记录错误
            print(f"敏感信息过滤失败: {e}")
            return True

    def mask_dict(self, data: Dict) -> Dict:
        """脱敏字典中的敏感信息 - 添加循环引用处理"""
        if not isinstance(data, dict):
            return data

        # 检查循环引用
        data_id = id(data)
        if data_id in self._processing_ids:
            # 检测到循环引用，返回占位符
            return {"__cycle__": f"<Circular reference to dict at {hex(data_id)}>"}

        try:
            # 添加到处理集合
            self._processing_ids.add(data_id)

            masked_data = {}
            for key, value in data.items():
                key_str = str(key)

                if isinstance(value, dict):
                    masked_data[key] = self.mask_dict(value)
                elif isinstance(value, list):
                    masked_data[key] = self.mask_list(value)
                elif isinstance(value, (str, int, float)):
                    masked_data[key] = self._mask_dict_int_float(key_str, value)
                else:
                    masked_data[key] = value

            return masked_data
        finally:
            # 从处理集合中移除
            self._processing_ids.remove(data_id)

    def _mask_dict_int_float(self, key, value):
        """处理字典中的整数和浮点数（包括布尔值）"""
        # 如果键名是敏感键，总是脱敏值
        if self._is_sensitive_key(key):
            masked_value = self._apply_mask(str(value))
        else:
            # 否则进行智能脱敏
            masked_value = self.filter_sensitive_keywords(str(value))

        # 保持原始类型
        if isinstance(value, bool):
            # 布尔值：尝试转换回布尔
            try:
                return bool(masked_value)
            except:
                # 如果转换失败，返回原始值
                return value
        elif isinstance(value, int):
            # 整数：尝试转换回整数
            try:
                return int(masked_value)
            except ValueError:
                # 如果转换失败，返回原始值
                return value
        elif isinstance(value, float):
            # 浮点数：尝试转换回浮点数
            try:
                return float(masked_value)
            except ValueError:
                # 如果转换失败，返回原始值
                return value
        else:
            # 其他类型：返回字符串
            return masked_value

    def mask_sensitive_data(self, data):
        """包装方法，用于重置处理状态"""
        self._processing_ids = set()  # 重置处理状态
        return self._mask_sensitive_data(data)

    def _mask_sensitive_data(self, data):
        """实际的脱敏方法"""
        # 检查循环引用
        data_id = id(data)
        if data_id in self._processing_ids:
            # 检测到循环引用，返回占位符
            if isinstance(data, dict):
                return {"__cycle__": f"<Circular reference to dict at {hex(data_id)}>"}
            elif isinstance(data, list):
                return [f"<Circular reference to list at {hex(data_id)}>"]
            else:
                return data

        try:
            # 添加到处理集合
            self._processing_ids.add(data_id)

            if isinstance(data, dict):
                return self.mask_dict(data)
            elif isinstance(data, list):
                return self.mask_list(data)
            elif isinstance(data, str):
                return self.filter_sensitive_keywords(data)
            else:
                return data
        finally:
            # 从处理集合中移除
            if data_id in self._processing_ids:
                self._processing_ids.remove(data_id)

    def mask_list(self, data: list) -> list:
        """脱敏列表中的敏感信息 - 添加循环引用处理"""
        if not isinstance(data, list):
            return data

        # 检查循环引用
        data_id = id(data)
        if data_id in self._processing_ids:
            # 检测到循环引用，返回占位符
            return [f"<Circular reference to list at {hex(data_id)}>"]

        try:
            # 添加到处理集合
            self._processing_ids.add(data_id)

            masked_list = []
            for item in data:
                if isinstance(item, dict):
                    masked_list.append(self.mask_dict(item))
                elif isinstance(item, list):
                    masked_list.append(self.mask_list(item))
                elif isinstance(item, (str, int, float)):
                    masked_list.append(self.filter_sensitive_keywords(str(item)))
                else:
                    masked_list.append(item)

            return masked_list
        finally:
            # 从处理集合中移除
            self._processing_ids.remove(data_id)

    def add_keyword(self, keyword: str):
        """添加敏感关键词"""
        if keyword.lower() not in [k.lower() for k in self.config.keywords]:
            self.config.keywords.append(keyword)
            # 重新编译模式
            try:
                pattern_str = rf'(?i)\b{re.escape(keyword)}\b["\']?\s*[:=]\s*["\']?([^"\'\s,&]+)["\']?'
                pattern = re.compile(pattern_str, re.IGNORECASE)
                self._compiled_patterns.append(pattern)
            except re.error as e:
                print(f"警告：添加关键词时正则编译错误 '{keyword}': {e}")

    def remove_keyword(self, keyword: str):
        """移除敏感关键词"""
        keyword_lower = keyword.lower()
        self.config.keywords = [
            k for k in self.config.keywords
            if k.lower() != keyword_lower
        ]
        # 重新编译所有模式
        self._compiled_patterns = []
        for k in self.config.keywords:
            try:
                pattern_str = rf'(?i)\b{re.escape(k)}\b["\']?\s*[:=]\s*["\']?([^"\'\s,&]+)["\']?'
                pattern = re.compile(pattern_str, re.IGNORECASE)
                self._compiled_patterns.append(pattern)
            except re.error as e:
                print(f"警告：重新编译正则错误 '{k}': {e}")

    def get_keywords(self) -> List[str]:
        """获取当前敏感关键词列表"""
        return self.config.keywords.copy()

    def add_special_pattern(self, pattern_str: str):
        """添加特殊模式正则"""
        if pattern_str not in self.config.special_patterns:
            self.config.special_patterns.append(pattern_str)
            try:
                compiled = re.compile(pattern_str)
                self._compiled_special_patterns.append(compiled)
            except re.error as e:
                print(f"警告：无效的特殊模式 '{pattern_str}': {e}")

    def remove_special_pattern(self, pattern_str: str):
        """移除特殊模式正则"""
        if pattern_str in self.config.special_patterns:
            self.config.special_patterns.remove(pattern_str)
            # 重新编译所有特殊模式
            self._compiled_special_patterns = []
            for pattern in self.config.special_patterns:
                try:
                    compiled = re.compile(pattern)
                    self._compiled_special_patterns.append(compiled)
                except re.error as e:
                    print(f"警告：无效的特殊模式 '{pattern}': {e}")

    def get_special_patterns(self) -> List[str]:
        """获取当前特殊模式列表"""
        return self.config.special_patterns.copy()

    def update_config(self, **kwargs):
        """更新配置"""
        for key, value in kwargs.items():
            if hasattr(self.config, key):
                setattr(self.config, key, value)

        # 重新初始化模式
        self._init_patterns()


class SafeStreamHandler(logging.StreamHandler):
    """安全的流处理器，处理Windows终端关闭问题"""

    def __init__(self, stream=None):
        super().__init__(stream)
        self._is_closed = False

    def handleError(self, record):
        """安全地处理处理器中的异常，不传播到调用者"""
        pass

    def emit(self, record):
        """安全地输出日志"""
        if self._is_closed:
            return

        try:
            # 检查流是否有效
            if self.stream is None or self.stream.closed:
                self._is_closed = True
                return

            # 在Windows上额外检查
            if sys.platform.startswith('win'):
                try:
                    # 尝试写入一个空字符来检查流是否有效
                    self.stream.write('')
                    self.stream.flush()
                except (OSError, ValueError, AttributeError):
                    self._is_closed = True
                    return

            super().emit(record)
        except (ValueError, OSError, AttributeError):
            # 忽略流关闭错误
            self._is_closed = True
        except Exception:
            # 其他错误仍然处理
            self.handleError(record)

    def close(self):
        """关闭处理器"""
        self._is_closed = True
        super().close()


class ColoredFormatter(logging.Formatter):
    """带颜色的控制台日志格式化器"""

    def __init__(self, fmt=None, datefmt=None, style='%'):
        super().__init__(fmt, datefmt, style)
        self._use_color = self._should_use_color()

    def _should_use_color(self):
        """判断是否应该使用颜色"""
        # 检查是否是终端
        if not hasattr(sys.stdout, 'isatty') or not sys.stdout.isatty():
            return False

        # Windows平台特殊处理
        if sys.platform.startswith('win'):
            try:
                # Windows上需要colorama支持ANSI颜色
                import colorama
                colorama.init()
                return True
            except ImportError:
                # 没有colorama，不使用颜色
                return False

        # 非Windows平台默认使用颜色
        return True

    def format(self, record):
        """格式化日志记录"""
        # 如果是Windows且没有colorama，不使用颜色
        if not self._use_color:
            return super().format(record)

        # 使用颜色
        levelname = record.levelname
        if levelname in COLORS:
            # 创建格式化后的字符串
            message = super().format(record)
            # 为整个行添加颜色（更简单的方式）
            return f"{COLORS[levelname]}{message}{RESET}"

        return super().format(record)


# 已创建的logger缓存
import threading

_logger_cache = {}
_logger_lock = threading.Lock() if 'threading' in sys.modules else None
_sensitive_filters = {}  # 敏感过滤器缓存


def _get_project_root():
    """获取项目根目录"""
    try:
        # 尝试从当前文件向上查找
        current_file = Path(__file__).resolve()
        # 向上查找4级（假设结构为：project/src/utils/complete_logger/core.py）
        for _ in range(4):
            if current_file.name == 'src':
                return current_file.parent
            current_file = current_file.parent
        # 如果找不到，返回当前目录
        return Path.cwd()
    except:
        return Path.cwd()


def _get_log_dir(config: LoggerConfig) -> Path:
    """获取日志目录"""
    if config.log_dir:
        return Path(config.log_dir)

    if config.log_file:
        log_path = Path(config.log_file)
        return log_path.parent

    # 默认目录：项目根目录下的logs文件夹
    project_root = _get_project_root()
    return project_root / "logs"


def _setup_handler(logger: logging.Logger, config: LoggerConfig):
    """为logger设置处理器"""
    # 首先检查logger是否已经有处理器
    if logger.handlers:
        # 检查是否已经有相同配置的处理器
        existing_configs = []
        for handler in logger.handlers:
            handler_type = type(handler).__name__
            if handler_type == 'SafeStreamHandler' and config.console:
                existing_configs.append('console')
            elif handler_type == 'RotatingFileHandler' and config.file:
                existing_configs.append('file')

        # 如果已经有相同类型的处理器，不重复添加
        if config.console and 'console' in existing_configs:
            config.console = False
        if config.file and 'file' in existing_configs:
            config.file = False

    # 设置日志级别
    level = getattr(logging, config.level.upper(), logging.INFO)
    logger.setLevel(level)

    # 创建格式化器
    formatter = logging.Formatter(config.format_str, config.datefmt)

    # 添加敏感信息过滤器（如果启用）
    if config.enable_sensitive_filter:
        filter_key = f"{config.name}_{hash(str(config.sensitive_config))}"
        if filter_key not in _sensitive_filters:
            _sensitive_filters[filter_key] = SensitiveFilter(config.sensitive_config)

        # 为logger添加过滤器
        logger.addFilter(_sensitive_filters[filter_key])

    # 控制台处理器
    if config.console:
        console_handler = SafeStreamHandler(sys.stdout)
        console_formatter = ColoredFormatter(config.format_str, config.datefmt)
        console_handler.setFormatter(console_formatter)
        console_handler.setLevel(level)
        logger.addHandler(console_handler)

    # 文件处理器
    if config.file:
        try:
            # 获取日志目录
            log_dir = _get_log_dir(config)
            log_dir.mkdir(parents=True, exist_ok=True)

            # 确定日志文件名
            if config.log_file:
                log_path = Path(config.log_file)
            else:
                log_path = log_dir / f"{config.name}.log"

            # 使用轮转文件处理器
            file_handler = logging.handlers.RotatingFileHandler(
                filename=str(log_path),
                maxBytes=config.max_bytes,
                backupCount=config.backup_count,
                encoding=config.encoding
            )
            file_handler.setFormatter(formatter)
            file_handler.setLevel(level)
            logger.addHandler(file_handler)
        except Exception as e:
            # 文件日志失败时，只使用控制台日志
            print(f"警告：无法创建文件日志: {e}", file=sys.stderr)

    # 设置logger不传播到父logger，避免重复记录
    logger.propagate = False


def get_logger(name: str = "app", **kwargs) -> logging.Logger:
    """获取日志器 - 主入口函数"""
    # 创建配置
    config_kwargs = kwargs.copy()
    # sensitive_config = config_kwargs.pop('sensitive_config', SensitiveConfig())
    #
    # config = LoggerConfig(name=name, sensitive_config=sensitive_config, **config_kwargs)
    # 提取所有配置参数
    name = config_kwargs.pop('name', name)
    level = config_kwargs.pop('level', 'INFO')
    log_dir = config_kwargs.pop('log_dir', None)
    log_file = config_kwargs.pop('log_file', None)
    max_bytes = config_kwargs.pop('max_bytes', 10 * 1024 * 1024)
    backup_count = config_kwargs.pop('backup_count', 5)
    console = config_kwargs.pop('console', True)
    file = config_kwargs.pop('file', True)
    format_str = config_kwargs.pop('format_str',
                            '%(asctime)s.%(msecs)03d | %(threadName)-12s | %(thread)-8d | %(levelname)-8s | %(name)-8s | %(filename)s:%(lineno)d | %(message)s')
    datefmt = config_kwargs.pop('datefmt', '%Y-%m-%d %H:%M:%S')
    encoding = config_kwargs.pop('encoding', 'utf-8')
    enable_sensitive_filter = config_kwargs.pop('enable_sensitive_filter', True)

    # 处理敏感配置
    sensitive_config_kwargs = config_kwargs.pop('sensitive_config', {})
    if isinstance(sensitive_config_kwargs, SensitiveConfig):
        sensitive_config = sensitive_config_kwargs
    else:
        sensitive_config = SensitiveConfig(**sensitive_config_kwargs)

    if name == '' or name is None or name == 'None':
        name = 'app'

    # 创建配置对象
    config = LoggerConfig(
        name=name,
        level=level,
        log_dir=log_dir,
        log_file=log_file,
        max_bytes=max_bytes,
        backup_count=backup_count,
        console=console,
        file=file,
        format_str=format_str,
        datefmt=datefmt,
        encoding=encoding,
        enable_sensitive_filter=enable_sensitive_filter,
        sensitive_config=sensitive_config
    )

    # 生成配置的唯一键
    config_key = f"{name}_{hash(str(kwargs))}"

    # 使用锁确保线程安全
    if _logger_lock:
        with _logger_lock:
            # 检查缓存
            if config_key in _logger_cache:
                return _logger_cache[config_key]

            # 创建新的logger
            logger = logging.getLogger(name)

            # 检查是否已有处理器
            if logger.handlers:
                # 如果已有处理器，检查配置是否相同
                if _check_configuration_match(logger, config):
                    # 配置相同，直接使用
                    _logger_cache[config_key] = logger
                    return logger
                else:
                    # 配置不同，创建新的logger名称
                    new_name = f"{config.name}.{hash(str(config.to_dict()))}"
                    logger = logging.getLogger(new_name)
            # 如果logger已经有处理器，检查是否配置相同
            # if logger.handlers:
            #     # 简单检查：如果logger已经有处理器，直接返回
            #     # 避免重复添加处理器
            #     return logger

            # 设置处理器
            _setup_handler(logger, config)

            # 缓存logger
            _logger_cache[config_key] = logger

            return logger
    else:
        # 没有锁的情况（单线程环境）
        if config_key in _logger_cache:
            return _logger_cache[config_key]

        # 创建新的logger
        logger = logging.getLogger(name)

        # 设置处理器
        _setup_handler(logger, config)

        # 缓存logger
        _logger_cache[config_key] = logger

        return logger


def _check_configuration_match(logger: logging.Logger, config: LoggerConfig) -> bool:
    """检查logger的配置是否与给定配置匹配"""
    # 检查级别
    expected_level = getattr(logging, config.level.upper(), logging.INFO)
    if logger.level != expected_level:
        return False

    # 检查处理器类型和数量
    expected_handlers = []
    if config.console:
        expected_handlers.append('SafeStreamHandler')
    if config.file:
        expected_handlers.append('RotatingFileHandler')

    actual_handlers = [type(h).__name__ for h in logger.handlers]

    if sorted(expected_handlers) != sorted(actual_handlers):
        return False

    return True

def setup_logging(**kwargs) -> logging.Logger:
    """设置日志配置"""
    return get_logger(**kwargs)


def add_sensitive_keyword(logger_name: str, keyword: str):
    """为指定logger添加敏感关键词"""
    logger = logging.getLogger(logger_name)

    # 查找logger的敏感过滤器
    for filter_obj in logger.filters:
        if isinstance(filter_obj, SensitiveFilter):
            filter_obj.add_keyword(keyword)
            return True

    # 如果没有找到过滤器，尝试从缓存中查找
    for filter_key, filter_obj in _sensitive_filters.items():
        if logger_name in filter_key:
            filter_obj.add_keyword(keyword)
            return True

    print(f"警告：未找到logger '{logger_name}'的敏感信息过滤器")
    return False


def remove_sensitive_keyword(logger_name: str, keyword: str):
    """从指定logger移除敏感关键词"""
    logger = logging.getLogger(logger_name)

    # 查找logger的敏感过滤器
    for filter_obj in logger.filters:
        if isinstance(filter_obj, SensitiveFilter):
            filter_obj.remove_keyword(keyword)
            return True

    # 如果没有找到过滤器，尝试从缓存中查找
    for filter_key, filter_obj in _sensitive_filters.items():
        if logger_name in filter_key:
            filter_obj.remove_keyword(keyword)
            return True

    print(f"警告：未找到logger '{logger_name}'的敏感信息过滤器")
    return False


def get_sensitive_keywords(logger_name: str) -> List[str]:
    """获取指定logger的敏感关键词列表"""
    logger = logging.getLogger(logger_name)

    # 查找logger的敏感过滤器
    for filter_obj in logger.filters:
        if isinstance(filter_obj, SensitiveFilter):
            return filter_obj.get_keywords()

    # 如果没有找到过滤器，尝试从缓存中查找
    for filter_key, filter_obj in _sensitive_filters.items():
        if logger_name in filter_key:
            return filter_obj.get_keywords()

    print(f"警告：未找到logger '{logger_name}'的敏感信息过滤器")
    return []


def mask_sensitive_data(data: Any, sensitive_config: Optional[SensitiveConfig] = None) -> Any:
    """手动脱敏数据（用于非日志场景）"""
    if sensitive_config is None:
        sensitive_config = SensitiveConfig()

    filter_obj = SensitiveFilter(sensitive_config)

    if isinstance(data, dict):
        return filter_obj.mask_dict(data)
    elif isinstance(data, list):
        return filter_obj.mask_list(data)
    elif isinstance(data, str):
        return filter_obj.filter_sensitive_keywords(data)
    elif isinstance(data, (int, float)):
        return filter_obj.filter_sensitive_keywords(str(data))
    else:
        return data


def shutdown_logging():
    """显式关闭日志系统"""
    global _logger_cache, _sensitive_filters

    # 关闭所有logger的处理器
    for logger in _logger_cache.values():
        handlers = logger.handlers[:]  # 复制列表，因为关闭处理器会修改它
        for handler in handlers:
            try:
                handler.close()
                logger.removeHandler(handler)
            except:
                pass

    # 清空缓存
    _logger_cache.clear()
    _sensitive_filters.clear()

    # 清理logging模块的缓存
    for logger_name in list(logging.Logger.manager.loggerDict.keys()):
        logger = logging.getLogger(logger_name)
        handlers = logger.handlers[:]
        for handler in handlers:
            try:
                handler.close()
                logger.removeHandler(handler)
            except:
                pass


# 装饰器
def log_function_call(logger_name: str = "app", log_args: bool = True, log_return: bool = True,
                      mask_sensitive: bool = True):
    """记录函数调用的装饰器"""

    def decorator(func):
        def wrapper(*args, **kwargs):
            frame = inspect.currentframe()
            caller_frame = frame.f_back
            caller_info = ""
            if caller_frame:
                caller_info = "%s:%d" % (caller_frame.f_code.co_filename, caller_frame.f_lineno)

            logger = get_logger(logger_name)

            # 记录函数调用
            if log_args:
                # 如果需要脱敏，先处理参数
                if mask_sensitive:
                    masked_args = []
                    for arg in args:
                        if isinstance(arg, (str, int, float)):
                            masked_args.append(mask_sensitive_data(str(arg)))
                        elif isinstance(arg, dict):
                            masked_args.append(mask_sensitive_data(arg))
                        elif isinstance(arg, list):
                            masked_args.append(mask_sensitive_data(arg))
                        else:
                            masked_args.append(arg)
                    args_str = ', '.join([repr(arg) for arg in masked_args])

                    masked_kwargs = {}
                    for k, v in kwargs.items():
                        if isinstance(v, (str, int, float)):
                            masked_kwargs[k] = mask_sensitive_data(str(v))
                        elif isinstance(v, dict):
                            masked_kwargs[k] = mask_sensitive_data(v)
                        elif isinstance(v, list):
                            masked_kwargs[k] = mask_sensitive_data(v)
                        else:
                            masked_kwargs[k] = v
                    kwargs_str = ', '.join([f"{k}={repr(v)}" for k, v in masked_kwargs.items()])
                else:
                    args_str = ', '.join([repr(arg) for arg in args])
                    kwargs_str = ', '.join([f"{k}={repr(v)}" for k, v in kwargs.items()])

                all_args = ', '.join(filter(None, [args_str, kwargs_str]))
                logger.info(f"{caller_info} 调用函数: {func.__name__}({all_args})")
            else:
                logger.info(f"{caller_info} 调用函数: {func.__name__}")

            try:
                result = func(*args, **kwargs)

                # 记录返回值
                if log_return:
                    if mask_sensitive:
                        masked_result = mask_sensitive_data(result)
                        logger.info(f"{caller_info} 函数 {func.__name__} 返回: {repr(masked_result)}")
                    else:
                        logger.info(f"{caller_info} 函数 {func.__name__} 返回: {repr(result)}")
                else:
                    logger.info(f"{caller_info} 函数 {func.__name__} 执行成功")

                return result
            except Exception as e:
                logger.error(f"{caller_info} 函数 {func.__name__} 执行失败: {e}", exc_info=True)
                raise

        return wrapper

    return decorator


# 上下文管理器
class LogBlock:
    """记录代码块执行的上下文管理器"""

    def __init__(self, name: str, logger_name: str = "app", level: str = "INFO",
                 mask_sensitive: bool = True):
        self.name = name
        self.logger = get_logger(logger_name)
        self.level = getattr(logging, level.upper())
        self.start_time = None
        self.mask_sensitive = mask_sensitive

    def __enter__(self):
        frame = inspect.currentframe()
        caller_frame = frame.f_back
        caller_info = ""
        if caller_frame:
            caller_info = "%s:%d" % (caller_frame.f_code.co_filename, caller_frame.f_lineno)

        self.start_time = datetime.now()
        entry_message = f"{caller_info} [开始] {self.name}"
        if self.mask_sensitive:
            entry_message = mask_sensitive_data(entry_message)
        self.logger.log(self.level, entry_message)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        elapsed = datetime.now() - self.start_time

        frame = inspect.currentframe()
        caller_frame = frame.f_back
        caller_info = ""
        if caller_frame:
            caller_info = "%s:%d" % (caller_frame.f_code.co_filename, caller_frame.f_lineno)

        if exc_type is None:
            exit_message = f"{caller_info} [完成] {self.name} | 耗时: {elapsed.total_seconds():.3f}秒"
        else:
            error_msg = str(exc_val) if exc_val else str(exc_type)
            if self.mask_sensitive:
                error_msg = mask_sensitive_data(error_msg)
            exit_message = f"{caller_info} [失败] {self.name} | 错误: {error_msg} | 耗时: {elapsed.total_seconds():.3f}秒"

        if self.mask_sensitive:
            exit_message = mask_sensitive_data(exit_message)
        self.logger.log(self.level if exc_type is None else logging.ERROR, exit_message)
        return False  # 不吞异常


# 性能监控装饰器
def log_performance(logger_name: str = "app", threshold: float = 1.0,
                    mask_sensitive: bool = True):
    """记录函数性能的装饰器"""

    def decorator(func):
        def wrapper(*args, **kwargs):
            frame = inspect.currentframe()
            caller_frame = frame.f_back
            caller_info = ""
            if caller_frame:
                caller_info = "%s:%d" % (caller_frame.f_code.co_filename, caller_frame.f_lineno)

            logger = get_logger(logger_name)
            start_time = datetime.now()

            # 记录开始执行
            debug_message = f"{caller_info} 开始执行: {func.__name__}"
            if mask_sensitive:
                debug_message = mask_sensitive_data(debug_message)
            logger.debug(debug_message)

            try:
                result = func(*args, **kwargs)
                elapsed = datetime.now() - start_time

                # 记录执行耗时
                if elapsed.total_seconds() > threshold:
                    warning_message = (f"{caller_info} 函数 {func.__name__} 执行较慢: "
                                     f"{elapsed.total_seconds():.3f}秒 (阈值: {threshold}秒)")
                    if mask_sensitive:
                        warning_message = mask_sensitive_data(warning_message)
                    logger.warning(warning_message)
                else:
                    info_message = (f"{caller_info} 函数 {func.__name__} 执行耗时: "
                                  f"{elapsed.total_seconds():.3f}秒")
                    if mask_sensitive:
                        info_message = mask_sensitive_data(info_message)
                    logger.info(info_message)

                return result
            except Exception as e:
                elapsed = datetime.now() - start_time
                error_message = (f"{caller_info} 函数 {func.__name__} 执行失败，"
                               f"耗时: {elapsed.total_seconds():.3f}秒，错误: {e}")
                if mask_sensitive:
                    error_message = mask_sensitive_data(error_message)
                logger.error(error_message)
                raise

        return wrapper

    return decorator


# 注册退出处理
atexit.register(shutdown_logging)

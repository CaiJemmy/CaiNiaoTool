import json
import os

from src.utils.complete_logger import get_logger

logger = get_logger("common")

def load_json_file(file_path):
    if not os.path.exists(file_path):
        logger.error(f"错误：文件 '{file_path}' 不存在")
        return None

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        logger.error(f"JSON 解析错误: {e}")
        logger.error(f"错误位置: 第{e.lineno}行, 第{e.colno}列")
        return None
    except UnicodeDecodeError:
        logger.error("编码错误，尝试其他编码...")
        try:
            with open(file_path, 'r', encoding='gbk') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"无法解析文件编码: {e}")
            return None
    except Exception as e: # pragma: no cover
        logger.error(f"未知错误: {e}")
        return None

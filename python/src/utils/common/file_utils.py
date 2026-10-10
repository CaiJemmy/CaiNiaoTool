import os
import fnmatch
from pathlib import Path
from typing import List, Union, Generator, Optional
from dataclasses import dataclass
from datetime import datetime


@dataclass
class FileInfo:
    """文件信息类"""
    path: Path
    name: str
    size: int
    modified_time: datetime
    extension: str

    @classmethod
    def from_path(cls, file_path: Path) -> 'FileInfo':
        """从Path对象创建FileInfo"""
        stat = file_path.stat()
        return cls(
            path=file_path,
            name=file_path.name,
            size=stat.st_size,
            modified_time=datetime.fromtimestamp(stat.st_mtime),
            extension=file_path.suffix.lower()
        )


class FileScanner:
    """文件扫描器"""

    def __init__(self, directory: Union[str, Path]):
        self.directory = Path(directory)
        self._validate_directory()

    def _validate_directory(self):
        """验证目录"""
        if not self.directory.exists():
            raise FileNotFoundError(f"目录不存在: {self.directory}")
        if not self.directory.is_dir():
            raise NotADirectoryError(f"路径不是目录: {self.directory}")

    def get_files(self, recursive: bool = True) -> List[Path]:
        """获取所有文件路径"""
        if recursive:
            return [f for f in self.directory.rglob("*") if f.is_file()]
        else:
            return [f for f in self.directory.iterdir() if f.is_file()]

    def get_file_infos(self, recursive: bool = True) -> List[FileInfo]:
        """获取所有文件的详细信息"""
        files = self.get_files(recursive)
        return [FileInfo.from_path(f) for f in files]

    def get_files_by_pattern(self, pattern: str, recursive: bool = True) -> List[Path]:
        """使用通配符模式获取文件"""
        if recursive:
            all_files = self.directory.rglob("*")
        else:
            all_files = self.directory.iterdir()

        return [f for f in all_files if f.is_file() and fnmatch.fnmatch(f.name, pattern)]

    def get_files_by_extensions(self, extensions: List[str], recursive: bool = True) -> List[Path]:
        """按扩展名获取文件"""
        extensions = [ext.lower() if ext.startswith('.') else f'.{ext.lower()}' for ext in extensions]
        files = self.get_files(recursive)
        return [f for f in files if f.suffix.lower() in extensions]

    def get_files_by_size(self, min_size: int = 0, max_size: Optional[int] = None,
                          recursive: bool = True) -> List[Path]:
        """按大小范围获取文件"""
        files = self.get_files(recursive)
        result = []

        for f in files:
            size = f.stat().st_size
            if size >= min_size and (max_size is None or size <= max_size):
                result.append(f)

        return result

    def count_files(self, recursive: bool = True) -> int:
        """统计文件数量"""
        return len(self.get_files(recursive))

    def walk_files(self) -> Generator[Path, None, None]:
        """生成器方式遍历文件"""
        for file_path in self.directory.rglob("*"):
            if file_path.is_file():
                yield file_path

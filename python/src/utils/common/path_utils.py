import inspect
from pathlib import Path
from typing import Optional, List, Union


class PathUtils:
    """路径工具类"""

    @staticmethod
    def script_dir() -> Path:
        """获取当前脚本目录"""
        return Path(__file__).resolve().parent

    @staticmethod
    def script_path() -> Path:
        """获取当前脚本路径"""
        return Path(__file__).resolve()

    @staticmethod
    def caller_dir(level: int = 1) -> Path:
        """
        获取调用者文件的目录

        Args:
            level: 调用层级，1表示直接调用者，2表示调用者的调用者，以此类推
        """
        try:
            frame = inspect.currentframe()
            for _ in range(level + 1):
                if frame is None:
                    break
                frame = frame.f_back

            if frame is not None:
                caller_file = frame.f_globals.get('__file__')
                if caller_file:
                    return Path(caller_file).resolve().parent
        except:
            pass

        # 回退到当前工作目录
        return Path.cwd()

    @staticmethod
    def project_root(start_from: Optional[Union[str, Path]] = None,
                     markers: Optional[List[str]] = None) -> Path:
        """获取项目根目录"""
        if start_from is None:
            start_from = PathUtils.caller_dir(level=2)
        else:
            start_from = Path(start_from).resolve()

        if markers is None:
            markers = ['.git', 'requirements.txt', 'pyproject.toml',
                       'setup.py', 'MANIFEST.in', '.venv', "src"]

        current = start_from
        while current != current.parent:
            for marker in markers:
                if (current / marker).exists():
                    return current
            current = current.parent

        return start_from

    @staticmethod
    def ensure_dir(path: Union[str, Path]) -> Path:
        """确保目录存在，不存在则创建"""
        path_obj = Path(path).resolve()
        path_obj.mkdir(parents=True, exist_ok=True)
        return path_obj

    @staticmethod
    def relative_to_project(path: Union[str, Path]) -> Path:
        """获取相对于项目根目录的路径"""
        project_root = PathUtils.project_root()
        full_path = Path(path).resolve()
        try:
            return full_path.relative_to(project_root)
        except ValueError:
            return full_path

    @staticmethod
    def from_project_root(*parts: str) -> Path:
        """从项目根目录构建路径"""
        project_root = PathUtils.project_root()
        return project_root.joinpath(*parts)

    @staticmethod
    def from_script_dir(*parts: str) -> Path:
        """从脚本目录构建路径"""
        script_dir = PathUtils.script_dir()
        return script_dir.joinpath(*parts)

from src.utils.common.common_util import load_json_file
from src.utils.common.file_utils import FileScanner

class ConfigLoader:
    def __init__(self, conf_dir):
        self.config_dir = conf_dir

    def load(self) -> list[dict]:
        email_to_infos = []
        scanner = FileScanner(self.config_dir)
        for conf in scanner.get_files():
            email_to = load_json_file(conf)
            email_to_infos.append(email_to)
        return email_to_infos

from src.utils.common.common_util import load_json_file
from src.utils.common.path_utils import PathUtils

def test_load_json_file_not_exists():
    test_json = load_json_file(PathUtils.from_project_root("tests", "config", "common", "config_test_01.json"))

    assert test_json is None

def test_load_json_file():
    test_json = load_json_file(PathUtils.from_project_root("tests", "config", "common", "config_test.json"))

    assert test_json is not None
    assert test_json['test'] == 'fake'

def test_load_json_file_json_decode_error():
    test_json = load_json_file(PathUtils.from_project_root("tests", "config", "common", "config_test_json_decode_error.json"))

    assert test_json is None


def test_load_json_file_unicode_decode_error():
    test_json = load_json_file(PathUtils.from_project_root("tests", "config", "common", "config_test_unicode_decode_error.json"))

    assert test_json is None

def test_load_json_file_unicode_decode_error_gbk():
    test_json = load_json_file(PathUtils.from_project_root("tests", "config", "common", "config_test_unicode_decode_error_gbk.json"))

    assert test_json is not None
    assert test_json['test'] == 'fake'

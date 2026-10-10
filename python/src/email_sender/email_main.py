from src.email_sender.email_builder import EmailBuilder
from src.email_sender.qq_mail_sender import QQMailSender
from src.utils.common.common_util import load_json_file
from src.utils.common.path_utils import PathUtils
from src.utils.complete_logger import get_logger
from src.utils.crypto.chacha20.chacha20 import ChaCha20

logger = get_logger("qq_email")


if __name__ == "__main__":
    qq_config = load_json_file(PathUtils.from_project_root("src", "config", "config_from_qq.json"))
    decrypted = ChaCha20().decrypt(
        bytes.fromhex(qq_config['ciphertext']),
        bytes.fromhex(qq_config['secret_key']),
        bytes.fromhex(qq_config['nonce'])
    )
    AUTH_CODE = decrypted.decode()  # 你的授权码
    QQ_EMAIL = qq_config['email']  # 你的QQ邮箱

    for mail_info in EmailBuilder().build():
        sender = QQMailSender(QQ_EMAIL, AUTH_CODE)
        if sender.test_connection():
            result = sender.send(
                to_emails=mail_info['to_addrs'],
                subject=mail_info['subject'],
                content=mail_info['html_content'],
                content_type='html',
                use_ssl=False  # 使用 TLS (端口587)
            )

            logger.info(f"发送结果: {result}")
        else:
            logger.error("QQ邮箱连接测试失败")
            logger.error("请检查：")
            logger.error("1. QQ邮箱是否正确")
            logger.error("2. 是否使用了授权码（不是QQ密码）")
            logger.error("3. 是否在QQ邮箱设置中开启了SMTP服务")
            logger.error("4. 网络连接是否正常")
            logger.error(f"mail_info: {mail_info}")

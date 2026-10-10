from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
import os

# 使用密钥派生函数（KDF）从密码生成密钥
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
# PBKDF2HMAC：用于密码强化，从弱密码生成强密钥
# HKDF：用于密钥扩展，从强密钥材料派生子密钥

class ChaCha20:
    @staticmethod
    def _derive_key_from_password(password: bytes, salt: bytes = os.urandom(16)) -> bytes:
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,  # ChaCha20需要32字节
            salt=salt,
            iterations=1000000,  # OWASP推荐迭代次数
        )
        return kdf.derive(password)

    def encrypt(self, plaintext: bytes) -> dict:
        """
        使用ChaCha20-Poly1305进行认证加密
        """
        key = self._derive_key_from_password(plaintext)

        # 生成96位（12字节）随机nonce
        nonce = os.urandom(12)

        ciphertext = ChaCha20Poly1305(key).encrypt(nonce, plaintext, None)

        return {
            "secret_key": key.hex(),
            "ciphertext": ciphertext.hex(),
            "nonce": nonce.hex()
        }

    @staticmethod
    def decrypt(ciphertext: bytes, key: bytes, nonce: bytes) -> bytes:
        return ChaCha20Poly1305(key).decrypt(nonce, ciphertext, None)


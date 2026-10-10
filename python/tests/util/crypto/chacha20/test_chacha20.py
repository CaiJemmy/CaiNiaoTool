from src.utils.crypto.chacha20.chacha20 import ChaCha20


def test_chacha20():
    data = "test_chacha20"
    encrypted = ChaCha20().encrypt(data.encode("utf-8"))
    print(encrypted)

    decrypted = ChaCha20().decrypt(
        bytes.fromhex(encrypted['ciphertext']),
        bytes.fromhex(encrypted['secret_key']),
        bytes.fromhex(encrypted['nonce'])
    )

    assert data == decrypted.decode()


import requests
import base58
import ecdsa
import hashlib
import os
import time

def generate_wallet():
    private_key = os.urandom(32)
    private_key_hex = private_key.hex()

    sk = ecdsa.SigningKey.from_string(private_key, curve=ecdsa.SECP256k1)
    vk = sk.verifying_key
    public_key_bytes = b'\x04' + vk.to_string()
    public_key_hex = public_key_bytes.hex()

    sha256_bpk = hashlib.sha256(public_key_bytes).digest()
    ripemd160_bpk = hashlib.new('ripemd160', sha256_bpk).digest()
    network_byte = b'\x00' + ripemd160_bpk
    checksum = hashlib.sha256(hashlib.sha256(network_byte).digest()).digest()[:4]
    address_bytes = network_byte + checksum
    address = base58.b58encode(address_bytes).decode()

    return private_key_hex, public_key_hex, address

def get_balance(address):
    url = f"https://blockstream.info/api/address/{address}"
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
        received = data["chain_stats"]["funded_txo_sum"]
        spent = data["chain_stats"]["spent_txo_sum"]
        balance_sats = received - spent
        return balance_sats
    except Exception as e:
        print(f"查询地址失败 {address}，错误：{e}")
        return None

def save_wallet(private_key, public_key, address, balance):
    with open("found_wallets.txt", "a") as f:
        f.write(f"地址: {address}\n私钥: {private_key}\n公钥: {public_key}\n余额: {balance} sats\n\n")

print("启动脚本，开始无限生成并查询钱包...按 Ctrl+C 停止")
try:
    while True:
        priv, pub, addr = generate_wallet()
        balance = get_balance(addr)
        if balance is not None and balance > 0:
            print(f"[+] 找到有余额的钱包！地址: {addr}, 余额: {balance} sats")
            save_wallet(priv, pub, addr, balance)
        else:
            print(f"[-] 空钱包地址: {addr}")
        time.sleep(1)
except KeyboardInterrupt:
    print("\n已手动停止脚本。")

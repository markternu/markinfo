# 完全卸载重装，确保干净环境
sudo systemctl stop transmission-daemon
sudo apt remove --purge transmission-daemon transmission-common -y
sudo rm -rf /var/lib/transmission
sudo rm -rf /etc/systemd/system/transmission-daemon.service.d
sudo apt autoremove -y

# 重新安装
sudo apt update
sudo apt install -y transmission-daemon

# 创建目录
sudo mkdir -p /var/lib/transmission/.config/transmission-daemon
sudo mkdir -p /var/lib/transmission/downloads

# 直接创建最简配置（禁用所有白名单）
sudo tee /var/lib/transmission/.config/transmission-daemon/settings.json > /dev/null <<'EOF'
{
    "download-dir": "/var/lib/transmission/downloads",
    "rpc-authentication-required": true,
    "rpc-bind-address": "0.0.0.0",
    "rpc-enabled": true,
    "rpc-password": "123456a",
    "rpc-port": 9091,
    "rpc-username": "opengl",
    "rpc-whitelist-enabled": false
}
EOF

sudo chown -R debian-transmission:debian-transmission /var/lib/transmission
sudo chmod 600 /var/lib/transmission/.config/transmission-daemon/settings.json

# 启动
sudo systemctl start transmission-daemon
sleep 5

# 测试
curl http://206.189.164.14:9091/

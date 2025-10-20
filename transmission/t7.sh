# 1. 删除 Nginx 配置（避免冲突）
sudo rm -f /etc/nginx/sites-enabled/transmission
sudo rm -f /etc/nginx/sites-available/transmission
sudo systemctl restart nginx

# 2. 完全停止 Transmission
sudo systemctl stop transmission-daemon
sleep 2
sudo killall -9 transmission-daemon 2>/dev/null
sleep 2

# 3. 手工编辑配置文件，彻底禁用白名单
sudo tee /var/lib/transmission/.config/transmission-daemon/settings.json > /dev/null <<'EOF'
{
    "alt-speed-down": 50,
    "alt-speed-enabled": false,
    "bind-address-ipv4": "0.0.0.0",
    "bind-address-ipv6": "::",
    "blocklist-enabled": false,
    "cache-size-mb": 4,
    "dht-enabled": true,
    "download-dir": "/var/lib/transmission/downloads",
    "download-queue-enabled": true,
    "download-queue-size": 500,
    "encryption": 1,
    "idle-seeding-limit": 30,
    "idle-seeding-limit-enabled": false,
    "incomplete-dir": "/var/lib/transmission/incomplete",
    "incomplete-dir-enabled": true,
    "lpd-enabled": false,
    "message-level": 2,
    "peer-limit-global": 200,
    "peer-limit-per-torrent": 50,
    "peer-port": 51413,
    "peer-port-random-on-start": false,
    "pex-enabled": true,
    "port-forwarding-enabled": false,
    "preallocation": 1,
    "prefetch-enabled": true,
    "queue-stalled-enabled": true,
    "queue-stalled-minutes": 30,
    "ratio-limit": 2,
    "ratio-limit-enabled": false,
    "rename-partial-files": true,
    "rpc-authentication-required": true,
    "rpc-bind-address": "0.0.0.0",
    "rpc-enabled": true,
    "rpc-host-whitelist": "",
    "rpc-host-whitelist-enabled": false,
    "rpc-password": "123456a",
    "rpc-port": 9091,
    "rpc-url": "/transmission/",
    "rpc-username": "opengl",
    "rpc-whitelist": "",
    "rpc-whitelist-enabled": false,
    "scrape-paused-torrents-enabled": true,
    "seed-queue-enabled": false,
    "seed-queue-size": 10,
    "speed-limit-down": 100,
    "speed-limit-down-enabled": false,
    "speed-limit-up": 0,
    "speed-limit-up-enabled": true,
    "start-added-torrents": true,
    "trash-original-torrent-files": false,
    "umask": 2,
    "upload-slots-per-torrent": 14,
    "utp-enabled": true
}
EOF

# 4. 设置权限
sudo chown debian-transmission:debian-transmission /var/lib/transmission/.config/transmission-daemon/settings.json
sudo chmod 600 /var/lib/transmission/.config/transmission-daemon/settings.json

# 5. 启动服务
sudo systemctl start transmission-daemon
sleep 5

# 6. 验证
echo "=== 配置验证 ==="
sudo jq '.["rpc-port"], .["rpc-whitelist-enabled"], .["rpc-whitelist"]' \
  /var/lib/transmission/.config/transmission-daemon/settings.json

echo ""
echo "=== 测试访问 ==="
curl http://206.189.164.14:9091/ 2>&1 | head -5

echo ""
echo "=== 端口监听 ==="
sudo netstat -tlnp | grep 9091

# 1. 检查配置文件是否被 Transmission 修改
echo "=== 完整白名单配置 ==="
sudo cat /var/lib/transmission/.config/transmission-daemon/settings.json | grep -A 2 -B 2 whitelist

# 2. 检查是否有其他配置文件
echo ""
echo "=== 查找所有 Transmission 配置文件 ==="
sudo find /etc /var -name "settings.json" 2>/dev/null

# 3. 检查 Transmission 是否有启动参数覆盖
echo ""
echo "=== 检查启动参数 ==="
sudo cat /proc/$(pgrep transmission-daemon)/cmdline | tr '\0' ' '
echo ""

# 4. 启用调试日志重启
echo ""
echo "=== 启用详细日志 ==="
sudo systemctl stop transmission-daemon
sleep 2

# 修改日志级别
sudo jq '.["message-level"] = 3' \
  /var/lib/transmission/.config/transmission-daemon/settings.json > /tmp/s.json && \
  sudo mv /tmp/s.json /var/lib/transmission/.config/transmission-daemon/settings.json
sudo chown debian-transmission:debian-transmission /var/lib/transmission/.config/transmission-daemon/settings.json

sudo systemctl start transmission-daemon
sleep 5

# 5. 尝试访问并查看日志
echo "=== 发起测试请求 ==="
curl http://206.189.164.14:9091/ > /dev/null 2>&1

echo ""
echo "=== 查看实时日志（最后20行）==="
sudo journalctl -u transmission-daemon -n 20 --no-pager

# 6. 尝试用你的客户端 IP 从服务器发起请求
echo ""
echo "=== 模拟你的 IP 访问（如果有 curl --interface）==="
curl --max-time 3 http://206.189.164.14:9091/ 2>&1 | head -3

# 1. 完全停止 Transmission
sudo systemctl stop transmission-daemon
sleep 3
sudo killall -9 transmission-daemon 2>/dev/null
sleep 2

# 2. 确认 9091 端口已释放
sudo netstat -tlnp | grep 9091
# 应该没有输出

# 3. 修改配置到 9092 端口
sudo jq '.["rpc-port"] = 9092 | .["rpc-whitelist-enabled"] = false' \
  /var/lib/transmission/.config/transmission-daemon/settings.json > /tmp/s.json && \
  sudo mv /tmp/s.json /var/lib/transmission/.config/transmission-daemon/settings.json

sudo chown debian-transmission:debian-transmission /var/lib/transmission/.config/transmission-daemon/settings.json

# 4. 验证配置
echo "配置文件中的端口："
sudo jq '.["rpc-port"]' /var/lib/transmission/.config/transmission-daemon/settings.json

# 5. 启动 Transmission
sudo systemctl start transmission-daemon
sleep 5

# 6. 确认 Transmission 在 9092
echo ""
echo "Transmission 监听端口："
sudo netstat -tlnp | grep transmission | grep -v 51413

# 7. 重启 Nginx
sudo systemctl restart nginx
sleep 2

# 8. 确认 Nginx 在 9091
echo ""
echo "Nginx 监听 9091："
sudo netstat -tlnp | grep 9091

# 9. 测试
echo ""
echo "=== 测试 9092（Transmission 直接）==="
curl -u opengl:123456a http://localhost:9092/transmission/rpc 2>&1 | head -3

echo ""
echo "=== 测试 9091（通过 Nginx）==="
curl http://localhost:9091/ 2>&1 | head -3

echo ""
echo "=== 测试公网访问 ==="
curl http://206.189.164.14:9091/ 2>&1 | head -3

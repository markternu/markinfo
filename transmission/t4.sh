# 1. 检查 Transmission 是否改到 9092 端口
echo "=== Transmission 配置 ==="
sudo jq '.["rpc-port"], .["rpc-whitelist-enabled"]' /var/lib/transmission/.config/transmission-daemon/settings.json

echo ""
echo "=== Transmission 监听端口 ==="
sudo netstat -tlnp | grep transmission

# 2. 检查 Nginx 配置是否生效
echo ""
echo "=== Nginx 监听 9091 ==="
sudo netstat -tlnp | grep 9091

# 3. 查看 Nginx 配置内容
echo ""
echo "=== Nginx 配置文件 ==="
cat /etc/nginx/sites-available/transmission

# 4. 检查 Nginx 错误日志
echo ""
echo "=== Nginx 错误日志 ==="
sudo tail -20 /var/log/nginx/error.log

# 5. 测试访问
echo ""
echo "=== 测试本地访问 9092（Transmission 直接）==="
curl -u opengl:123456a http://localhost:9092/transmission/rpc 2>&1 | head -5

echo ""
echo "=== 测试本地访问 9091（通过 Nginx）==="
curl http://localhost:9091/ 2>&1 | head -10

echo ""
echo "=== 测试公网访问 9091 ==="
curl http://206.189.164.14:9091/ 2>&1 | head -10
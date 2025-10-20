# 1. 查看这3个配置文件的内容
echo "=== /etc/transmission-daemon/settings.json ==="
sudo cat /etc/transmission-daemon/settings.json | jq '.["rpc-whitelist"], .["rpc-whitelist-enabled"]'

echo ""
echo "=== /var/lib/transmission-daemon/.config/transmission-daemon/settings.json ==="
sudo cat /var/lib/transmission-daemon/.config/transmission-daemon/settings.json | jq '.["rpc-whitelist"], .["rpc-whitelist-enabled"]'

echo ""
echo "=== 当前使用的配置 (我们一直修改的) ==="
sudo cat /var/lib/transmission/.config/transmission-daemon/settings.json | jq '.["rpc-whitelist"], .["rpc-whitelist-enabled"]'

# 2. 修改所有3个配置文件
echo ""
echo "=== 修改所有配置文件 ==="

# 修改 /etc 下的
sudo jq '.["rpc-whitelist-enabled"] = false | .["rpc-authentication-required"] = true' \
  /etc/transmission-daemon/settings.json > /tmp/s1.json 2>/dev/null && \
  sudo mv /tmp/s1.json /etc/transmission-daemon/settings.json

# 修改 /var/lib/transmission-daemon 下的
sudo jq '.["rpc-whitelist-enabled"] = false | .["rpc-authentication-required"] = true' \
  /var/lib/transmission-daemon/.config/transmission-daemon/settings.json > /tmp/s2.json 2>/dev/null && \
  sudo mv /tmp/s2.json /var/lib/transmission-daemon/.config/transmission-daemon/settings.json

# 修改 /var/lib/transmission 下的（我们一直在改的）
sudo jq '.["rpc-whitelist-enabled"] = false | .["rpc-authentication-required"] = true' \
  /var/lib/transmission/.config/transmission-daemon/settings.json > /tmp/s3.json && \
  sudo mv /tmp/s3.json /var/lib/transmission/.config/transmission-daemon/settings.json

# 3. 设置权限
sudo chown debian-transmission:debian-transmission /etc/transmission-daemon/settings.json 2>/dev/null
sudo chown -R debian-transmission:debian-transmission /var/lib/transmission-daemon 2>/dev/null
sudo chown -R debian-transmission:debian-transmission /var/lib/transmission

# 4. 重启服务
sudo systemctl restart transmission-daemon
sleep 5

# 5. 测试
echo ""
echo "=== 测试访问 ==="
curl http://206.189.164.14:9091/

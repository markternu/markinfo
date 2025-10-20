# 停止服务
sudo systemctl stop transmission-daemon

# 只保留一个配置文件
sudo rm -f /etc/transmission-daemon/settings.json
sudo rm -rf /var/lib/transmission-daemon

# 确保只有这一个配置
sudo jq '.["rpc-whitelist-enabled"] = false' \
  /var/lib/transmission/.config/transmission-daemon/settings.json > /tmp/s.json && \
  sudo mv /tmp/s.json /var/lib/transmission/.config/transmission-daemon/settings.json

sudo chown -R debian-transmission:debian-transmission /var/lib/transmission

# 启动
sudo systemctl start transmission-daemon
sleep 5

# 测试
curl http://206.189.164.14:9091/

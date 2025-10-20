# 查看 systemd 服务配置
echo "=== Systemd 服务配置 ==="
sudo systemctl cat transmission-daemon.service

# 查看实际的启动命令
echo ""
echo "=== 实际运行的命令 ==="
ps aux | grep transmission-daemon | grep -v grep

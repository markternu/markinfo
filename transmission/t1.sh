#!/bin/bash

# 1. 检查 Transmission 版本
transmission-daemon --version

# 2. 使用正确的 HTTP 方法测试（Transmission RPC 需要 POST）
echo ""
echo "=== 使用 POST 方法测试 ==="
curl -X POST http://localhost:9091/transmission/rpc 2>&1 | head -10

# 3. 查看详细的服务日志
echo ""
echo "=== 服务详细日志 ==="
sudo journalctl -u transmission-daemon -n 50 --no-pager

# 4. 尝试直接访问 Web UI（不是 RPC）
echo ""
echo "=== 测试 Web UI 根路径 ==="
curl -I http://localhost:9091/ 2>&1 | head -10

# 5. 检查配置文件是否真的被读取
echo ""
echo "=== 检查进程打开的文件 ==="
sudo lsof -p $(pgrep transmission-daemon) | grep settings.json

# 6. 完全重装测试
echo ""
echo "=== 尝试完全重启服务 ==="
sudo systemctl stop transmission-daemon
sleep 2
sudo killall -9 transmission-daemon 2>/dev/null
sleep 2
sudo systemctl start transmission-daemon
sleep 5
curl -X POST http://localhost:9091/transmission/rpc 2>&1 | head -5
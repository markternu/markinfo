#!/bin/bash

# 1. 检查是否有其他 Web 服务占用或代理
echo "=== 检查 80/443 端口 ==="
sudo netstat -tlnp | grep -E ":80|:443"

# 2. 检查是否有 Nginx/Apache
echo ""
echo "=== 检查 Web 服务器 ==="
systemctl status nginx 2>/dev/null || echo "Nginx 未运行"
systemctl status apache2 2>/dev/null || echo "Apache 未运行"

# 3. 用浏览器的方式测试（完整的 GET 请求）
echo ""
echo "=== 模拟浏览器访问 ==="
curl -v http://localhost:9091/ 2>&1 | grep -A 20 "HTTP"

# 4. 测试从公网 IP 访问（重要！）
echo ""
echo "=== 从服务器自己访问公网 IP ==="
SERVER_PUBLIC_IP=$(curl -s ifconfig.me)
echo "服务器公网 IP: $SERVER_PUBLIC_IP"
curl -v http://$SERVER_PUBLIC_IP:9091/ 2>&1 | head -20

# 5. 检查云服务商的安全组/防火墙
echo ""
echo "=== 检查本地防火墙规则 ==="
sudo iptables -L -n -v | grep 9091

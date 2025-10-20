#!/bin/bash

# 创建 Nginx 配置
sudo tee /etc/nginx/sites-available/transmission > /dev/null <<'EOF'
server {
    listen 9091;
    server_name _;

    # IP 白名单（只允许你的 IP）
    allow 223.160.113.65;
    deny all;

    location / {
        proxy_pass http://127.0.0.1:9092;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

# 修改 Transmission 监听端口为 9092（避免冲突）
sudo systemctl stop transmission-daemon
sudo jq '.["rpc-port"] = 9092 | .["rpc-whitelist-enabled"] = false' \
  /var/lib/transmission/.config/transmission-daemon/settings.json > /tmp/s.json && \
  sudo mv /tmp/s.json /var/lib/transmission/.config/transmission-daemon/settings.json
sudo chown debian-transmission:debian-transmission /var/lib/transmission/.config/transmission-daemon/settings.json
sudo systemctl start transmission-daemon

# 启用 Nginx 配置
sudo ln -s /etc/nginx/sites-available/transmission /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "✅ 配置完成！"
echo "现在访问: http://206.189.164.14:9091"
echo "Nginx 会验证你的 IP，然后转发到 Transmission"
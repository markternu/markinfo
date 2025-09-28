#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
  echo "请以root权限运行此脚本"
  exit
fi

# 获取用户输入
read -p "请输入您的域名: " domain_name
read -p "请输入代理密码: " proxy_password

mkdir ak47
cd /ak47



# 安装必要的软件包
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx wget unzip



# 配置初始Nginx
cat > /etc/nginx/sites-available/default << EOL
server {
    listen 80;
    server_name ${domain_name};
    root /var/www/html;
    index index.html;
}
EOL

# 重启Nginx
systemctl restart nginx

# 获取SSL证书
certbot --nginx -d ${domain_name} --non-interactive --agree-tos --email webmaster@${domain_name}

# 安装Trojan
wget https://github.com/trojan-gfw/trojan/releases/download/v1.16.0/trojan-1.16.0-linux-amd64.tar.xz
tar xf trojan-1.16.0-linux-amd64.tar.xz
cd trojan

# 配置Trojan
cat > config.json << EOL
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "${proxy_password}"
    ],
    "ssl": {
        "cert": "/etc/letsencrypt/live/${domain_name}/fullchain.pem",
        "key": "/etc/letsencrypt/live/${domain_name}/privkey.pem",
        "alpn": [
            "http/1.1"
        ]
    }
}
EOL

# 创建systemd服务
cat > /etc/systemd/system/trojan.service << EOL
[Unit]
Description=Trojan Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=/ak47/trojan/trojan -c /ak47/trojan/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

# 还原Nginx配置为只监听80端口
cat > /etc/nginx/sites-available/default << EOL
server {
    listen 80;
    server_name ${domain_name};
    root /var/www/html;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOL

# 启动服务
systemctl daemon-reload
systemctl restart nginx
systemctl start trojan
systemctl enable trojan

echo "安装完成！"
echo "域名: ${domain_name}"
echo "密码: ${proxy_password}"
echo "Trojan 已配置完成并设置为开机自启"
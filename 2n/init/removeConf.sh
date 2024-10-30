#!/bin/bash

# 停止 Nginx 服务
sudo systemctl stop nginx

# 停用和删除 Trojan
sudo systemctl stop trojan
sudo systemctl disable trojan
sudo rm -rf /usr/local/etc/trojan

# 卸载软件
sudo apt purge -y nginx certbot python3-certbot-nginx

# 还原 Nginx 配置
sudo rm -dr /etc/nginx
echo "所有软件已卸载, Nginx 配置已还原。您可以重新运行安装脚本了。"
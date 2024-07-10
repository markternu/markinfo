#!/bin/bash

# 提示用户输入参数 域名和trojan的密码
read -p "Please input URL:" value_url
read -p "Please input password:" value_trojan_psw

# 声明字符串
string_cert="/etc/letsencrypt/live/$value_url/fullchain.pem"
string_key="/etc/letsencrypt/live/$value_url/privkey.pem"



# Certbot命令
certbot_command="certbot --register-unsafely-without-email --agree-tos  --nginx -d"

# 拼接命令
full_command="$certbot_command $value_url"

# 确保防火墙允许 HTTP 和 HTTPS 流量
sudo firewall-cmd --add-service=http --permanent && \
sudo firewall-cmd --add-service=https --permanent && \
sudo firewall-cmd --reload && \

echo "================================================="
echo "======================1=========================="
echo "================================================="
# 步骤1. 安装必备软件
sudo yum update -y && sudo yum install epel-release -y && \
sudo yum install wget vim net-tools  zsh git screen zip aria2 jq unzip -y && \
sudo sudo yum install epel-release -y && sudo yum update -y && sudo yum install nginx certbot python3-certbot-nginx -y  && \

echo "================================================="
echo "======================2=========================="
echo "================================================="
# 步骤2. nginx conf

nginx_conf="/etc/nginx/nginx.conf"

# 使用sed命令替换所有localhost的值

sudo sed -i -E "s/(server_name[[:space:]]+)[^;]+;/\1$value_url;/" "$nginx_conf" && \
echo "Nginx server_name has been updated to $value_url"  && \
cat /etc/nginx/nginx.conf  && \

echo "================================================="
echo "======================4=========================="
echo "================================================="
# 步骤4. 启动nginx
sudo nginx && \


echo "================================================="
echo "======================5=========================="
echo "================================================="
# 步骤5. 安装https证书
# certbot --register-unsafely-without-email --agree-tos  --nginx -d fk.cctvbh.com && \
# 执行Certbot命令
cat /etc/nginx/nginx.conf && \
echo " $full_command " && \
eval $full_command && \


echo "================================================="
echo "======================end========================"
echo "================================================="


echo "================================================="
echo "======================6=========================="
echo "================================================="
# 步骤6. 停止nginx服务
sudo nginx -s stop && \


echo "================================================="
echo "======================7=========================="
echo "================================================="
# 步骤7. 更换nginx config
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginxBK2024.conf && \
sudo rm /etc/nginx/nginx.conf  && \
sudo cp /etc/nginx/nginx.conf.default /etc/nginx/nginx.conf && \




echo "================================================="
echo "======================8=========================="
echo "================================================="
# 步骤8. 再次启动nginx
sudo nginx && \


echo "================================================="
echo "======================9=========================="
echo "================================================="
# 步骤9. 安装Trojan
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)" && \

# 修改配置文件
trojan_config="/usr/local/etc/trojan/config.json" && \
jq --arg password "$value_trojan_psw" --arg cert "$string_cert" --arg key "$string_key" \
   '.password = [$password] | .ssl.cert = $cert | .ssl.key = $key' \
   "$trojan_config" > "/tmp/config.json" && sudo mv /tmp/config.json "$trojan_config" && \



echo "================================================="
echo "======================10=========================="
echo "================================================="
# 步骤10 启用并启动 Trojan
sudo systemctl enable trojan && \
sudo systemctl start trojan && \



echo "======================end=========================="
# 打印
echo "trojan url: $value_url" && \
echo "trojan psw: $value_trojan_psw" && \
# sudo systemctl enable certbot-renew.timer && \
# sudo systemctl start certbot-renew.timer && \
netstat -lntup|grep 80 && \
netstat -lntup|grep 443
echo "======================end=========================="
#!/bin/bash

# 提示用户输入参数 域名和trojan的密码
read -p "Please input URL:" value_url
read -p "Please input password:" value_trojan_psw

# 声明字符串
string_cert="/etc/letsencrypt/live/$value_url/fullchain.pem"
string_key="/etc/letsencrypt/live/$value_url/privkey.pem"



# Certbot命令
certbot_command="certbot --nginx --register-unsafely-without-email --agree-tos --nginx-server-root=/application/nginx/conf -d"

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
sudo yum install epel-release -y && sudo yum install jq net-tools -y && \
sudo yum install git aria2 vim wget pcre pcre-devel openssl openssl-devel gcc -y && \
sudo yum install epel-release -y && sudo yum update -y && sudo yum install certbot python2-certbot-nginx -y  && \

echo "================================================="
echo "======================2=========================="
echo "================================================="
# 步骤2. 源码安装nginx
wget -q http://nginx.org/download/nginx-1.20.0.tar.gz && \
useradd www -s /sbin/nologin -M && \
tar xf nginx-1.20.0.tar.gz && \
cd nginx-1.20.0 && \
./configure --user=www --group=www --with-http_ssl_module --with-http_stub_status_module --prefix=/application/nginx-1.20.0/ && \
make && \
sudo make install && \
sudo ln -s /application/nginx-1.20.0/ /application/nginx && \
sudo ln -s /application/nginx/sbin/nginx /usr/bin/nginx && \

echo "================================================="
echo "======================3=========================="
echo "================================================="
# 步骤3. 修改nginx nginx/conf/nginx.conf 域名指向
# Nginx配置文件路径
nginx_conf="/application/nginx/conf/nginx.conf"

# 使用sed命令替换所有localhost的值
sudo sed -i "s/localhost/$value_url/g" "$nginx_conf" && \
cat /application/nginx/conf/nginx.conf  && \
echo "================================================="
echo "======================4=========================="
echo "================================================="
# 步骤4. 启动nginx
sudo /application/nginx/sbin/nginx && \


echo "================================================="
echo "======================5=========================="
echo "================================================="
# 步骤5. 安装https证书
# certbot --nginx --register-unsafely-without-email --agree-tos --nginx-server-root=/application/nginx/conf -d $value_url && \
# 执行Certbot命令
cat /application/nginx/conf/nginx.conf && \
echo " $full_command " && \
eval $full_command && \


echo "================================================="
echo "======================end========================"
echo "================================================="


echo "================================================="
echo "======================6=========================="
echo "================================================="
# 步骤6. 停止nginx服务
sudo /application/nginx/sbin/nginx -s stop && \


echo "================================================="
echo "======================7=========================="
echo "================================================="
# 步骤7. 更换nginx config
sudo cp /application/nginx/conf/nginx.conf /application/nginx/conf/nginxBK2024.conf && \
sudo cp /application/nginx/conf/nginx.conf.default /application/nginx/conf/nginx.conf && \




echo "================================================="
echo "======================8=========================="
echo "================================================="
# 步骤8. 再次启动nginx
sudo /application/nginx/sbin/nginx && \


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
sudo systemctl enable certbot-renew.timer && \
sudo systemctl start certbot-renew.timer && \
netstat -lntup|grep 80 && \
netstat -lntup|grep 443
echo "======================end=========================="
#!/bin/bash

# 读取用户输入
read -p "Please input URL/IP Addr: " value_url
read -p "Please input password: " value_psw

# 处理输入参数
value_url_str="$value_url,::1"
value_psw_str="$value_psw"

# 安装 Transmission 和必要的工具
sudo yum install epel-release -y
sudo yum update -y
sudo yum -y install transmission transmission-daemon jq vim

# 启动并停止 Transmission 以生成默认配置文件
sudo systemctl start transmission-daemon.service
sudo systemctl stop transmission-daemon.service

# 定义配置文件路径
CONFIG_FILE="/var/lib/transmission/.config/transmission-daemon/settings.json"

# 修改配置文件
sudo jq --arg url "$value_url_str" --arg psw "$value_psw_str" '
.["rpc-authentication-required"] = true |
.["rpc-password"] = $psw |
.["rpc-username"] = "opengl" |
.["rpc-whitelist-enabled"] = true |
.["rpc-whitelist"] = $url |
.["download-queue-enabled"] = true |
.["download-queue-size"] = 500 |
.["speed-limit-up"] = 0 |
.["speed-limit-up-enabled"] = true' $CONFIG_FILE > /tmp/settings.json && sudo mv /tmp/settings.json $CONFIG_FILE

# 启动 Transmission
sudo systemctl start transmission-daemon.service

# 获取并打印 rpc-password 和 rpc-username 的值
RPC_PASSWORD=$(jq -r '."rpc-password"' $CONFIG_FILE)
RPC_USERNAME=$(jq -r '."rpc-username"' $CONFIG_FILE)
echo "rpc-password: $RPC_PASSWORD"
echo "rpc-username: $RPC_USERNAME"

# 打印 Transmission 的 web 访问地址
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Transmission web access URL: http://$IP_ADDRESS:9091"

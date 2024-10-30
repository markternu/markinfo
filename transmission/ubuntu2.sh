#!/bin/bash

# 读取用户输入
read -p "Please input URL/IP Addr: " value_url
read -p "Please input password: " value_psw

# 处理输入参数
value_url_str="$value_url,::1"
value_psw_str="$value_psw"

# 安装 Transmission 和必要的工具
sudo apt remove --purge transmission-gtk transmission-cli transmission-daemon
sudo apt autoremove
sudo apt update
sudo apt install transmission-daemon -y
sudo apt install jq -y
sudo apt install vim -y


# 定义配置文件路径
CONFIG_FILE="/etc/transmission-daemon/settings.json"

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

# 重启 Transmission
sudo systemctl restart transmission-daemon

# 获取并打印 rpc-password 和 rpc-username 的值
RPC_PASSWORD=$(jq -r '."rpc-password"' $CONFIG_FILE)
RPC_USERNAME=$(jq -r '."rpc-username"' $CONFIG_FILE)
echo "rpc-password: $RPC_PASSWORD"
echo "rpc-username: $RPC_USERNAME"

# 打印 Transmission 的 web 访问地址
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Transmission web access URL: http://$IP_ADDRESS:9091"

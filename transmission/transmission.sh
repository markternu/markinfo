#!/bin/bash

# 安装 Transmission
sudo yum update -y && sudo yum install epel-release -y && \
sudo yum install wget vim net-tools  zsh git screen zip aria2 jq unzip -y && \
sudo yum install -y transmission-daemon && \

# 停止 Transmission 以便修改配置文件
systemctl start transmission-daemon.service && \
systemctl stop transmission-daemon.service && \

# 修改配置文件
CONFIG_FILE="/var/lib/transmission/.config/transmission-daemon/settings.json"

sudo jq '. 
  | .["rpc-authentication-required"] = true 
  | .["rpc-password"] = "666888a" 
  | .["rpc-username"] = "opengl" 
  | .["rpc-whitelist-enabled"] = true 
  | .["rpc-whitelist"] = "127.0.0.1"
  | .["download-queue-enabled"] = false
  | .["download-queue-size"] = 500 
  | .["speed-limit-up"] = 0 
  | .["speed-limit-up-enabled"] = true' $CONFIG_FILE | sudo tee $CONFIG_FILE

# 启动 Transmission
systemctl start transmission-daemon.service  && \

# 获取并打印 rpc-password 和 rpc-username 的值
RPC_PASSWORD=$(jq -r '."rpc-password"' $CONFIG_FILE)
RPC_USERNAME=$(jq -r '."rpc-username"' $CONFIG_FILE)
echo "rpc-password: $RPC_PASSWORD"
echo "rpc-username: $RPC_USERNAME"

# 打印 Transmission 的 web 访问地址
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Transmission web access URL: http://$IP_ADDRESS:9091"

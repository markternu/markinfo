#!/bin/bash

# 删除不兼容的PPA仓库
sudo add-apt-repository --remove ppa:transmissionbt/ppa
sudo apt update

# 卸载现有的 transmission 并清理不再需要的包
sudo apt remove -y transmission-daemon
sudo apt autoremove -y

# 从官方仓库安装 transmission
sudo apt install -y transmission-daemon

# 停止 transmission 服务
sudo service transmission-daemon stop

# 修改 systemd 服务文件
sudo sed -i 's/Type=notify/Type=simple/' /lib/systemd/system/transmission-daemon.service

# Reload systemd 配置
sudo systemctl daemon-reload

# 定义配置文件路径
CONFIG_FILE="/var/lib/transmission-daemon/.config/transmission-daemon/settings.json"

# 读取用户输入
read -p "Please input URL/IP Addr: " value_url
read -p "Please input password: " value_psw

# 处理输入参数
value_url_str="$value_url,::1"
value_psw_str="$value_psw"

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

# 重启 transmission 服务
sudo systemctl restart transmission-daemon

# 获取并打印 rpc-password 和 rpc-username 的值
RPC_PASSWORD=$(sudo jq -r '."rpc-password"' $CONFIG_FILE)
RPC_USERNAME=$(sudo jq -r '."rpc-username"' $CONFIG_FILE)
echo "rpc-password: $RPC_PASSWORD"
echo "rpc-username: $RPC_USERNAME"

# 打印 Transmission 的 web 访问地址
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Transmission web access URL: http://$IP_ADDRESS:9091"
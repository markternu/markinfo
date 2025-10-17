#!/bin/bash
读取用户输入
read -p "只允许这个IP访问Please input URL/IP Addr: " value_url
read -p "Please input password: " value_psw
处理输入参数
value_url_str="$value_url,::1"
value_psw_str="$value_psw"
安装 Transmission 和必要的工具
echo "--- 1. 更新并安装 Transmission 和工具 ---"
sudo apt update
sudo apt install -y transmission-daemon jq vim
启动 Transmission 并等待其创建默认配置文件
echo "--- 2. 启动 Transmission Daemon 以生成配置 ---"
sudo systemctl start transmission-daemon
增加延迟：等待 5 到 10 秒，确保服务有足够时间创建 settings.json
避免服务启动超时失败，导致后续 jq 找不到文件
echo "--- 给予 10 秒时间等待 settings.json 生成... ---"
sleep 10
停止 Transmission 以进行安全的配置修改
echo "--- 3. 停止 Daemon 进行配置修改 ---"
sudo systemctl stop transmission-daemon
检查配置文件是否已生成（添加一个检查以提高脚本健壮性）
CONFIG_FILE="/var/lib/transmission/.config/transmission-daemon/settings.json"
if [ ! -f "$CONFIG_FILE" ]; then
echo "错误：等待 10 秒后仍找不到配置文件 $CONFIG_FILE"
echo "请手动检查 service 状态：systemctl status transmission-daemon"
exit 1
fi
修改配置文件
echo "--- 4. 修改配置文件 ($CONFIG_FILE) ---"
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
启动 Transmission
echo "--- 5. 最终启动 Transmission Daemon ---"
sudo systemctl start transmission-daemon
获取并打印 rpc-password 和 rpc-username 的值
RPC_PASSWORD=$(jq -r '."rpc-password"' $CONFIG_FILE)
RPC_USERNAME=$(jq -r '."rpc-username"' $CONFIG_FILE)
echo "--------------------------------------------------------"
echo "配置成功！"
echo "rpc-username: $RPC_USERNAME"
echo "rpc-password: $RPC_PASSWORD"
打印 Transmission 的 web 访问地址
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Transmission web access URL: http://$IP_ADDRESS:9091"
echo "--------------------------------------------------------"

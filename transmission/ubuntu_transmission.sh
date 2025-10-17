#!/bin/bash

# 设置颜色变量，让输出更清晰

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Transmission 安装和配置脚本开始 ---${NC}"

# -- 1. 读取用户输入 ---

read -p "请输入允许访问 Transmission Web 界面的 IP 地址 (例如: 192.168.1.0/24): " value_url
read -p "请输入您想要的 RPC 密码: " value_psw

# 处理输入参数

value_url_str="$value_url,127.0.0.1,::1"
value_psw_str="$value_psw"
CONFIG_FILE="/var/lib/transmission/.config/transmission-daemon/settings.json"

# -- 2. 安装 Transmission 和必要的工具 ---

echo -e "${GREEN}--- 正在更新并安装 Transmission Daemon 和工具 (jq) ---${NC}"
sudo apt update
sudo apt install -y transmission-daemon jq

# -- 3. 临时解决首次启动超时问题：覆盖 Systemd 配置 ---

echo -e "${GREEN}--- 正在临时延长 Transmission 服务启动超时时间 (TimeoutStartSec=180) ---${NC}"

# 创建 systemd 覆盖目录和文件

sudo mkdir -p /etc/systemd/system/transmission-daemon.service.d
echo -e "[Service]\nTimeoutStartSec=180" | sudo tee /etc/systemd/system/transmission-daemon.service.d/override.conf > /dev/null

# 重新加载 systemd 配置

sudo systemctl daemon-reload

# -- 4. 启动并等待配置文件生成 ---

echo -e "${GREEN}--- 正在启动 Transmission Daemon 以生成默认配置文件 ---${NC}"
sudo systemctl start transmission-daemon

MAX_WAIT=30
WAIT_TIME=0
SLEEP_INTERVAL=5

# 循环等待 settings.json 生成

echo -e "${GREEN}--- 正在等待 ${CONFIG_FILE} 生成 (最多等待 ${MAX_WAIT} 秒) ---${NC}"

while [ ! -f "$CONFIG_FILE" ]; do
if [ $WAIT_TIME -ge $MAX_WAIT ]; then
echo -e "${RED}错误：超过 ${MAX_WAIT} 秒仍找不到配置文件 ${CONFIG_FILE}。服务可能启动失败。${NC}"
echo "请检查状态：sudo systemctl status transmission-daemon"
# 移除临时覆盖文件，恢复默认配置
sudo rm -f /etc/systemd/system/transmission-daemon.service.d/override.conf
sudo rmdir /etc/systemd/system/transmission-daemon.service.d
sudo systemctl daemon-reload
exit 1
fi
sleep $SLEEP_INTERVAL
WAIT_TIME=$((WAIT_TIME + SLEEP_INTERVAL))
echo "  - 已等待 $WAIT_TIME 秒..."
done

# -- 5. 停止服务进行配置修改 ---

echo -e "${GREEN}--- 配置文件找到！正在停止 Daemon 以进行配置修改 ---${NC}"
sudo systemctl stop transmission-daemon

# -- 6. 修改配置文件 ---

echo -e "${GREEN}--- 正在修改配置文件 ($CONFIG_FILE) ---${NC}"

if [ -f "$CONFIG_FILE" ]; then
# 使用 jq 安全地修改配置
sudo jq --arg url "$value_url_str" --arg psw "$value_psw_str" '
.["rpc-authentication-required"] = true |
.["rpc-password"] = $psw |
.["rpc-username"] = "opengl" |
.["rpc-whitelist-enabled"] = true |
.["rpc-whitelist"] = $url |
.["download-queue-enabled"] = true |
.["download-queue-size"] = 500 |
.["speed-limit-up"] = 0 |
.["speed-limit-up-enabled"] = true' "$CONFIG_FILE" > /tmp/settings.json && sudo mv /tmp/settings.json "$CONFIG_FILE"

```
# 确保文件权限正确，否则服务可能无法读取
sudo chown debian-transmission:debian-transmission "$CONFIG_FILE"

```

else
# 理论上不会走到这里，但以防万一
echo -e "${RED}致命错误：配置阶段配置文件丢失。${NC}"
exit 1
fi

# -- 7. 移除临时覆盖并最终启动 Transmission ---

echo -e "${GREEN}--- 正在移除临时超时设置并最终启动 Transmission Daemon ---${NC}"

# 移除临时覆盖文件，恢复默认配置

sudo rm -f /etc/systemd/system/transmission-daemon.service.d/override.conf
sudo rmdir /etc/systemd/system/transmission-daemon.service.d
sudo systemctl daemon-reload

# 最终启动服务

sudo systemctl start transmission-daemon
sleep 5 # 给予服务足够时间启动

# -- 8. 打印结果 ---

echo -e "\n${GREEN}========================================================"
echo "配置成功！"
echo "服务状态："
sudo systemctl status transmission-daemon | grep Active | awk '{print $1" "$2" "$3}'
echo "--------------------------------------------------------"
RPC_PASSWORD=$(jq -r '."rpc-password"' "$CONFIG_FILE")
RPC_USERNAME=$(jq -r '."rpc-username"' "$CONFIG_FILE")
echo "RPC 用户名: $RPC_USERNAME"
echo "RPC 密码: $RPC_PASSWORD (已加密，但您设置的是 $value_psw)"

# 打印 Transmission 的 web 访问地址

IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Transmission Web 访问 URL: http://$IP_ADDRESS:9091"
echo "========================================================${NC}"

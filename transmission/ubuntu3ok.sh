#!/bin/bash

# 设置颜色变量
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Transmission 安装和配置脚本 ===${NC}"

# 检查是否以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 此脚本需要 root 权限运行${NC}"
   echo "请使用: sudo $0"
   exit 1
fi

# --- 1. 读取用户输入 ---
echo -e "${YELLOW}请输入配置信息：${NC}"
read -p "允许访问 Transmission Web 的 IP 地址 (例如: 192.168.1.0/24): " value_url
read -s -p "RPC 登录密码: " value_psw
echo ""

# 验证输入
if [ -z "$value_url" ] || [ -z "$value_psw" ]; then
    echo -e "${RED}错误：IP 地址和密码不能为空${NC}"
    exit 1
fi

value_url_str="$value_url,127.0.0.1,::1"
CONFIG_DIR="/var/lib/transmission/.config/transmission-daemon"
CONFIG_FILE="$CONFIG_DIR/settings.json"
DOWNLOADS_DIR="/var/lib/transmission/downloads"
INCOMPLETE_DIR="/var/lib/transmission/incomplete"

# --- 2. 安装 Transmission ---
echo -e "${GREEN}--- 更新软件包并安装 Transmission ---${NC}"
apt update
apt install -y transmission-daemon jq

# --- 3. 确保用户存在 ---
echo -e "${GREEN}--- 检查 debian-transmission 用户 ---${NC}"
if ! id debian-transmission &>/dev/null; then
    echo -e "${YELLOW}创建 debian-transmission 用户...${NC}"
    useradd -r -s /usr/sbin/nologin debian-transmission
fi

# --- 5. 创建必要的目录结构 ---
echo -e "${GREEN}--- 停止 Transmission 服务 ---${NC}"
systemctl stop transmission-daemon 2>/dev/null
killall transmission-daemon 2>/dev/null
sleep 2

# --- 4. 创建必要的目录结构 ---
echo -e "${GREEN}--- 创建目录结构 ---${NC}"
mkdir -p "$CONFIG_DIR"
mkdir -p "$DOWNLOADS_DIR"
mkdir -p "$INCOMPLETE_DIR"

# --- 6. 设置正确的权限 ---
echo -e "${GREEN}--- 设置目录权限 ---${NC}"
chown -R debian-transmission:debian-transmission /var/lib/transmission
chmod -R 755 /var/lib/transmission

# --- 7. 创建配置文件 ---
echo -e "${GREEN}--- 创建配置文件 ---${NC}"
cat > "$CONFIG_FILE" <<EOF
{
    "alt-speed-down": 50,
    "alt-speed-enabled": false,
    "alt-speed-time-begin": 540,
    "alt-speed-time-day": 127,
    "alt-speed-time-enabled": false,
    "alt-speed-time-end": 1020,
    "alt-speed-up": 50,
    "bind-address-ipv4": "0.0.0.0",
    "bind-address-ipv6": "::",
    "blocklist-enabled": false,
    "blocklist-url": "http://www.example.com/blocklist",
    "cache-size-mb": 4,
    "dht-enabled": true,
    "download-dir": "$DOWNLOADS_DIR",
    "download-queue-enabled": true,
    "download-queue-size": 500,
    "encryption": 1,
    "idle-seeding-limit": 30,
    "idle-seeding-limit-enabled": false,
    "incomplete-dir": "$INCOMPLETE_DIR",
    "incomplete-dir-enabled": true,
    "lpd-enabled": false,
    "message-level": 1,
    "peer-congestion-algorithm": "",
    "peer-id-ttl-hours": 6,
    "peer-limit-global": 200,
    "peer-limit-per-torrent": 50,
    "peer-port": 51413,
    "peer-port-random-high": 65535,
    "peer-port-random-low": 49152,
    "peer-port-random-on-start": false,
    "peer-socket-tos": "default",
    "pex-enabled": true,
    "port-forwarding-enabled": false,
    "preallocation": 1,
    "prefetch-enabled": true,
    "queue-stalled-enabled": true,
    "queue-stalled-minutes": 30,
    "ratio-limit": 2,
    "ratio-limit-enabled": false,
    "rename-partial-files": true,
    "rpc-authentication-required": true,
    "rpc-bind-address": "0.0.0.0",
    "rpc-enabled": true,
    "rpc-host-whitelist": "",
    "rpc-host-whitelist-enabled": false,
    "rpc-password": "$value_psw",
    "rpc-port": 9091,
    "rpc-url": "/transmission/",
    "rpc-username": "opengl",
    "rpc-whitelist": "$value_url_str",
    "rpc-whitelist-enabled": true,
    "scrape-paused-torrents-enabled": true,
    "script-torrent-done-enabled": false,
    "script-torrent-done-filename": "",
    "seed-queue-enabled": false,
    "seed-queue-size": 10,
    "speed-limit-down": 100,
    "speed-limit-down-enabled": false,
    "speed-limit-up": 0,
    "speed-limit-up-enabled": true,
    "start-added-torrents": true,
    "trash-original-torrent-files": false,
    "umask": 2,
    "upload-slots-per-torrent": 14,
    "utp-enabled": true
}
EOF

# 设置配置文件权限
chown debian-transmission:debian-transmission "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

echo -e "${GREEN}配置文件已创建: $CONFIG_FILE${NC}"

# --- 8. 创建 systemd 服务覆盖配置 ---
echo -e "${GREEN}--- 配置 systemd 服务 ---${NC}"
mkdir -p /etc/systemd/system/transmission-daemon.service.d
cat > /etc/systemd/system/transmission-daemon.service.d/override.conf <<EOF
[Service]
Type=simple
Restart=on-failure
RestartSec=5s
TimeoutStartSec=30s
EOF

# --- 9. 重新加载并启动服务 ---
echo -e "${GREEN}--- 启动 Transmission 服务 ---${NC}"
systemctl daemon-reload
systemctl enable transmission-daemon
systemctl start transmission-daemon

# 等待服务启动
sleep 3

# --- 10. 检查服务状态 ---
echo -e "\n${GREEN}=== 安装完成 ===${NC}"

if systemctl is-active --quiet transmission-daemon; then
    echo -e "${GREEN}✓ Transmission 服务运行正常${NC}"
    
    # 获取加密后的密码（Transmission 会自动加密）
    sleep 2
    ENCRYPTED_PSW=$(jq -r '."rpc-password"' "$CONFIG_FILE" 2>/dev/null || echo "无法读取")
    
    # 获取 IP 地址
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}配置信息：${NC}"
    echo -e "  RPC 用户名: ${YELLOW}opengl${NC}"
    echo -e "  RPC 密码: ${YELLOW}$value_psw${NC}"
    echo -e "  下载目录: ${YELLOW}$DOWNLOADS_DIR${NC}"
    echo -e "  未完成目录: ${YELLOW}$INCOMPLETE_DIR${NC}"
    echo -e "  允许访问的 IP: ${YELLOW}$value_url_str${NC}"
    echo -e "\n${GREEN}Web 访问地址：${NC}"
    echo -e "  ${YELLOW}http://$IP_ADDRESS:9091${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # 显示端口监听状态
    if command -v netstat &> /dev/null; then
        echo -e "\n${GREEN}端口监听状态：${NC}"
        netstat -tlnp | grep 9091 || echo -e "${YELLOW}警告: 端口 9091 未在监听${NC}"
    fi
else
    echo -e "${RED}✗ Transmission 服务启动失败${NC}"
    echo -e "${YELLOW}请检查日志：${NC}"
    echo "  sudo systemctl status transmission-daemon"
    echo "  sudo journalctl -xeu transmission-daemon"
    exit 1
fi

echo -e "\n${GREEN}提示：${NC}"
echo "  - 查看服务状态: sudo systemctl status transmission-daemon"
echo "  - 重启服务: sudo systemctl restart transmission-daemon"
echo "  - 查看日志: sudo journalctl -xeu transmission-daemon"
echo "  - 编辑配置: sudo systemctl stop transmission-daemon && sudo nano $CONFIG_FILE && sudo systemctl start transmission-daemon"
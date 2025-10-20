#!/bin/bash

# ============================================================
# Transmission 自动安装和配置脚本 v2.0
# 解决了密码加密和白名单的所有问题
# ============================================================

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}    Transmission BitTorrent 自动安装配置脚本 v2.0${NC}"
echo -e "${BLUE}============================================================${NC}\n"

# --- 检查 root 权限 ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ 错误: 此脚本需要 root 权限运行${NC}"
   echo -e "${YELLOW}请使用: sudo $0${NC}"
   exit 1
fi

# --- 读取用户输入 ---
echo -e "${GREEN}📝 请输入配置信息：${NC}\n"

# 读取 IP 白名单
while true; do
    read -p "允许访问的 IP 地址或网段 (例如: 192.168.1.0/24 或输入 * 允许所有): " value_url
    if [ -n "$value_url" ]; then
        break
    fi
    echo -e "${RED}IP 地址不能为空，请重新输入${NC}"
done

# 读取密码（隐藏输入）
while true; do
    read -s -p "设置 RPC 登录密码: " value_psw
    echo ""
    if [ -n "$value_psw" ]; then
        read -s -p "再次确认密码: " value_psw_confirm
        echo ""
        if [ "$value_psw" = "$value_psw_confirm" ]; then
            break
        else
            echo -e "${RED}两次密码不一致，请重新输入${NC}"
        fi
    else
        echo -e "${RED}密码不能为空，请重新输入${NC}"
    fi
done

# 询问是否启用密码认证
echo ""
read -p "是否启用密码认证? (y/n，默认 y): " enable_auth
enable_auth=${enable_auth:-y}

if [[ "$enable_auth" =~ ^[Yy]$ ]]; then
    rpc_auth_required=true
    echo -e "${GREEN}✓ 将启用密码认证${NC}"
else
    rpc_auth_required=false
    echo -e "${YELLOW}⚠ 将禁用密码认证（不安全）${NC}"
fi

# 询问是否启用白名单
echo ""
read -p "是否启用 IP 白名单? (y/n，默认 n 更方便): " enable_whitelist
enable_whitelist=${enable_whitelist:-n}

if [[ "$enable_whitelist" =~ ^[Yy]$ ]]; then
    rpc_whitelist_enabled=true
    value_url_str="$value_url,127.0.0.1,::1"
    echo -e "${GREEN}✓ 将启用 IP 白名单: $value_url_str${NC}"
else
    rpc_whitelist_enabled=false
    value_url_str="*"
    echo -e "${YELLOW}⚠ 将禁用 IP 白名单（允许所有 IP 访问）${NC}"
fi

# 配置变量
CONFIG_DIR="/var/lib/transmission/.config/transmission-daemon"
CONFIG_FILE="$CONFIG_DIR/settings.json"
DOWNLOADS_DIR="/var/lib/transmission/downloads"
INCOMPLETE_DIR="/var/lib/transmission/incomplete"
RPC_USERNAME="opengl"

echo -e "\n${BLUE}============================================================${NC}"
echo -e "${GREEN}开始安装和配置...${NC}\n"

# --- 1. 安装 Transmission ---
echo -e "${GREEN}[1/9] 更新软件包并安装 Transmission...${NC}"
apt update -qq
apt install -y transmission-daemon jq > /dev/null 2>&1
echo -e "${GREEN}✓ Transmission 安装完成${NC}\n"

# --- 2. 确保用户存在 ---
echo -e "${GREEN}[2/9] 检查系统用户...${NC}"
if ! id debian-transmission &>/dev/null; then
    useradd -r -s /usr/sbin/nologin debian-transmission
    echo -e "${GREEN}✓ 已创建 debian-transmission 用户${NC}\n"
else
    echo -e "${GREEN}✓ debian-transmission 用户已存在${NC}\n"
fi

# --- 3. 停止服务 ---
echo -e "${GREEN}[3/9] 停止现有服务...${NC}"
systemctl stop transmission-daemon 2>/dev/null
killall transmission-daemon 2>/dev/null
sleep 2
echo -e "${GREEN}✓ 服务已停止${NC}\n"

# --- 4. 创建目录结构 ---
echo -e "${GREEN}[4/9] 创建目录结构...${NC}"
mkdir -p "$CONFIG_DIR"
mkdir -p "$DOWNLOADS_DIR"
mkdir -p "$INCOMPLETE_DIR"
echo -e "${GREEN}✓ 目录创建完成${NC}\n"

# --- 5. 设置权限 ---
echo -e "${GREEN}[5/9] 设置目录权限...${NC}"
chown -R debian-transmission:debian-transmission /var/lib/transmission
chmod -R 755 /var/lib/transmission
echo -e "${GREEN}✓ 权限设置完成${NC}\n"

# --- 6. 创建配置文件 ---
echo -e "${GREEN}[6/9] 创建配置文件...${NC}"
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
    "rpc-authentication-required": $rpc_auth_required,
    "rpc-bind-address": "0.0.0.0",
    "rpc-enabled": true,
    "rpc-host-whitelist": "",
    "rpc-host-whitelist-enabled": false,
    "rpc-password": "$value_psw",
    "rpc-port": 9091,
    "rpc-url": "/transmission/",
    "rpc-username": "$RPC_USERNAME",
    "rpc-whitelist": "$value_url_str",
    "rpc-whitelist-enabled": $rpc_whitelist_enabled,
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

# 验证 JSON 格式
if jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ 配置文件创建成功（JSON 格式正确）${NC}\n"
else
    echo -e "${RED}❌ 配置文件 JSON 格式错误${NC}"
    exit 1
fi

# --- 7. 配置 systemd 服务 ---
echo -e "${GREEN}[7/9] 配置 systemd 服务...${NC}"
mkdir -p /etc/systemd/system/transmission-daemon.service.d
cat > /etc/systemd/system/transmission-daemon.service.d/override.conf <<EOF
[Service]
Type=simple
Restart=on-failure
RestartSec=5s
TimeoutStartSec=30s
EOF
echo -e "${GREEN}✓ systemd 配置完成${NC}\n"

# --- 8. 启动服务 ---
echo -e "${GREEN}[8/9] 启动 Transmission 服务...${NC}"
systemctl daemon-reload
systemctl enable transmission-daemon > /dev/null 2>&1
systemctl start transmission-daemon

# 等待服务启动
sleep 3

# --- 9. 验证安装 ---
echo -e "${GREEN}[9/9] 验证安装...${NC}\n"

if systemctl is-active --quiet transmission-daemon; then
    echo -e "${GREEN}✓ Transmission 服务运行正常${NC}\n"
    
    # 等待密码加密
    sleep 2
    
    # 获取服务器 IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # 显示配置信息
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${GREEN}🎉 安装成功！${NC}\n"
    echo -e "${YELLOW}访问信息：${NC}"
    echo -e "  Web 地址: ${GREEN}http://$SERVER_IP:9091${NC}"
    echo -e "  用户名: ${GREEN}$RPC_USERNAME${NC}"
    
    if [ "$rpc_auth_required" = "true" ]; then
        echo -e "  密码: ${GREEN}$value_psw${NC}"
        echo -e "  认证: ${GREEN}已启用${NC}"
    else
        echo -e "  密码: ${YELLOW}已禁用（无需密码）${NC}"
        echo -e "  认证: ${YELLOW}已禁用${NC}"
    fi
    
    if [ "$rpc_whitelist_enabled" = "true" ]; then
        echo -e "  IP 白名单: ${GREEN}已启用 ($value_url_str)${NC}"
    else
        echo -e "  IP 白名单: ${YELLOW}已禁用（允许所有 IP）${NC}"
    fi
    
    echo -e "\n${YELLOW}目录信息：${NC}"
    echo -e "  下载目录: ${GREEN}$DOWNLOADS_DIR${NC}"
    echo -e "  未完成目录: ${GREEN}$INCOMPLETE_DIR${NC}"
    echo -e "  配置文件: ${GREEN}$CONFIG_FILE${NC}"
    
    # 测试连接
    echo -e "\n${YELLOW}连接测试：${NC}"
    if [ "$rpc_auth_required" = "true" ]; then
        TEST_RESULT=$(curl -s -o /dev/null -w "%{http_code}" -u $RPC_USERNAME:$value_psw http://localhost:9091/transmission/rpc)
    else
        TEST_RESULT=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9091/transmission/rpc)
    fi
    
    if [ "$TEST_RESULT" = "409" ]; then
        echo -e "  ${GREEN}✓ RPC 连接测试成功 (HTTP 409 - 正常)${NC}"
    elif [ "$TEST_RESULT" = "401" ]; then
        echo -e "  ${RED}✗ 认证失败 (HTTP 401)${NC}"
        echo -e "  ${YELLOW}提示: 密码可能已被 Transmission 加密，请使用您设置的原始密码登录${NC}"
    elif [ "$TEST_RESULT" = "403" ]; then
        echo -e "  ${RED}✗ IP 被拒绝 (HTTP 403)${NC}"
    else
        echo -e "  ${YELLOW}⚠ 未知状态 (HTTP $TEST_RESULT)${NC}"
    fi
    
    # 检查端口监听
    if netstat -tlnp 2>/dev/null | grep -q ":9091"; then
        echo -e "  ${GREEN}✓ 端口 9091 正在监听${NC}"
    else
        echo -e "  ${YELLOW}⚠ 端口 9091 未在监听${NC}"
    fi
    
    echo -e "\n${YELLOW}常用命令：${NC}"
    echo -e "  查看状态: ${GREEN}sudo systemctl status transmission-daemon${NC}"
    echo -e "  重启服务: ${GREEN}sudo systemctl restart transmission-daemon${NC}"
    echo -e "  查看日志: ${GREEN}sudo journalctl -xeu transmission-daemon${NC}"
    echo -e "  编辑配置: ${GREEN}sudo systemctl stop transmission-daemon${NC}"
    echo -e "           ${GREEN}sudo nano $CONFIG_FILE${NC}"
    echo -e "           ${GREEN}sudo systemctl start transmission-daemon${NC}"
    
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${GREEN}✨ 现在可以通过浏览器访问 http://$SERVER_IP:9091 了！${NC}"
    echo -e "${BLUE}============================================================${NC}\n"
    
else
    echo -e "${RED}❌ Transmission 服务启动失败${NC}\n"
    echo -e "${YELLOW}请检查以下信息：${NC}"
    echo -e "  1. 服务状态: ${GREEN}sudo systemctl status transmission-daemon${NC}"
    echo -e "  2. 查看日志: ${GREEN}sudo journalctl -xeu transmission-daemon -n 50${NC}"
    echo -e "  3. 检查配置: ${GREEN}sudo jq . $CONFIG_FILE${NC}"
    exit 1
fi
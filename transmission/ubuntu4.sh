#!/bin/bash

# ============================================================
# Transmission 公网安全安装配置脚本 v3.0
# 专门解决公网部署的 IP 白名单问题
# ============================================================

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}    Transmission 公网安全部署脚本 v3.0${NC}"
echo -e "${BLUE}============================================================${NC}\n"

# --- 检查 root 权限 ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ 错误: 此脚本需要 root 权限运行${NC}"
   echo -e "${YELLOW}请使用: sudo $0${NC}"
   exit 1
fi

# --- 读取用户输入 ---
echo -e "${GREEN}📝 请输入配置信息：${NC}\n"

# 获取当前 SSH 连接的客户端 IP
CLIENT_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
if [ -n "$CLIENT_IP" ]; then
    echo -e "${YELLOW}检测到您的 SSH 连接 IP: ${GREEN}$CLIENT_IP${NC}"
    read -p "是否使用此 IP 作为白名单? (y/n，默认 y): " use_detected_ip
    use_detected_ip=${use_detected_ip:-y}
    
    if [[ "$use_detected_ip" =~ ^[Yy]$ ]]; then
        value_url="$CLIENT_IP"
        echo -e "${GREEN}✓ 将使用 $value_url 作为白名单${NC}\n"
    else
        read -p "请输入允许访问的 IP 地址（单个IP或网段，如 166.66.66.90 或 166.66.66.0/24）: " value_url
    fi
else
    read -p "请输入允许访问的 IP 地址（单个IP或网段，如 166.66.66.90 或 166.66.66.0/24）: " value_url
fi

# 验证 IP 输入
if [ -z "$value_url" ]; then
    echo -e "${RED}❌ IP 地址不能为空${NC}"
    exit 1
fi

# 读取密码
while true; do
    read -s -p "设置 RPC 登录密码（强密码）: " value_psw
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

# 配置变量
CONFIG_DIR="/var/lib/transmission/.config/transmission-daemon"
CONFIG_FILE="$CONFIG_DIR/settings.json"
DOWNLOADS_DIR="/var/lib/transmission/downloads"
INCOMPLETE_DIR="/var/lib/transmission/incomplete"
RPC_USERNAME="opengl"
RPC_PORT="9091"

# 白名单配置（包含本地和用户指定的 IP）
WHITELIST="$value_url,127.0.0.1,::1"

echo -e "\n${BLUE}============================================================${NC}"
echo -e "${GREEN}开始安装和配置...${NC}\n"
echo -e "${YELLOW}配置摘要：${NC}"
echo -e "  用户名: ${GREEN}$RPC_USERNAME${NC}"
echo -e "  密码: ${GREEN}******${NC} (已隐藏)"
echo -e "  白名单: ${GREEN}$WHITELIST${NC}"
echo -e "  端口: ${GREEN}$RPC_PORT${NC}"
echo -e "${BLUE}============================================================${NC}\n"

# --- 1. 卸载旧版本（如果存在）---
echo -e "${GREEN}[1/10] 清理旧版本...${NC}"
systemctl stop transmission-daemon 2>/dev/null
sleep 2
killall -9 transmission-daemon 2>/dev/null
sleep 1

# 检查是否已安装
if dpkg -l | grep -q transmission-daemon; then
    echo -e "${YELLOW}发现已安装的版本，正在卸载...${NC}"
    apt remove --purge -y transmission-daemon transmission-common 2>/dev/null
fi

# 清理配置和数据
if [ -d "/var/lib/transmission" ]; then
    echo -e "${YELLOW}清理旧配置...${NC}"
    rm -rf /var/lib/transmission/*
fi

rm -rf /etc/systemd/system/transmission-daemon.service.d 2>/dev/null
systemctl daemon-reload
echo -e "${GREEN}✓ 清理完成${NC}\n"

# --- 2. 安装 Transmission ---
echo -e "${GREEN}[2/10] 安装 Transmission...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update -qq
apt install -y transmission-daemon jq netstat-nat 2>&1 | grep -v "^Selecting\|^Preparing\|^Unpacking" || true
echo -e "${GREEN}✓ 安装完成${NC}\n"

# --- 3. 确保用户存在 ---
echo -e "${GREEN}[3/10] 检查系统用户...${NC}"
if ! id debian-transmission &>/dev/null; then
    useradd -r -s /usr/sbin/nologin debian-transmission
    echo -e "${GREEN}✓ 已创建用户${NC}\n"
else
    echo -e "${GREEN}✓ 用户已存在${NC}\n"
fi

# --- 4. 停止服务 ---
echo -e "${GREEN}[4/10] 确保服务已停止...${NC}"
systemctl stop transmission-daemon 2>/dev/null
killall transmission-daemon 2>/dev/null
sleep 3
echo -e "${GREEN}✓ 服务已停止${NC}\n"

# --- 5. 创建目录结构 ---
echo -e "${GREEN}[5/10] 创建目录结构...${NC}"
mkdir -p "$CONFIG_DIR"
mkdir -p "$DOWNLOADS_DIR"
mkdir -p "$INCOMPLETE_DIR"
echo -e "${GREEN}✓ 目录创建完成${NC}\n"

# --- 6. 设置权限 ---
echo -e "${GREEN}[6/10] 设置权限...${NC}"
chown -R debian-transmission:debian-transmission /var/lib/transmission
chmod -R 755 /var/lib/transmission
chmod 755 "$CONFIG_DIR"
echo -e "${GREEN}✓ 权限设置完成${NC}\n"

# --- 7. 创建配置文件（关键：密码使用明文）---
echo -e "${GREEN}[7/10] 创建配置文件...${NC}"
cat > "$CONFIG_FILE" <<EOF
{
    "alt-speed-down": 50,
    "alt-speed-enabled": false,
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
    "message-level": 2,
    "peer-limit-global": 200,
    "peer-limit-per-torrent": 50,
    "peer-port": 51413,
    "peer-port-random-on-start": false,
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
    "rpc-port": $RPC_PORT,
    "rpc-url": "/transmission/",
    "rpc-username": "$RPC_USERNAME",
    "rpc-whitelist": "$WHITELIST",
    "rpc-whitelist-enabled": true,
    "scrape-paused-torrents-enabled": true,
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

chown debian-transmission:debian-transmission "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

if jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ 配置文件创建成功${NC}\n"
else
    echo -e "${RED}❌ JSON 格式错误${NC}"
    exit 1
fi

# --- 8. 配置 systemd ---
echo -e "${GREEN}[8/10] 配置 systemd 服务...${NC}"
mkdir -p /etc/systemd/system/transmission-daemon.service.d
cat > /etc/systemd/system/transmission-daemon.service.d/override.conf <<EOF
[Service]
Type=simple
Restart=on-failure
RestartSec=5s
TimeoutStartSec=30s
ExecStartPre=/bin/sleep 2
EOF

systemctl daemon-reload
echo -e "${GREEN}✓ systemd 配置完成${NC}\n"

# --- 9. 首次启动并等待密码加密 ---
echo -e "${GREEN}[9/10] 首次启动服务（Transmission 会自动加密密码）...${NC}"
systemctl enable transmission-daemon > /dev/null 2>&1
systemctl start transmission-daemon

echo -e "${YELLOW}等待 Transmission 启动并加密密码...${NC}"
# 等待服务完全启动
for i in {1..15}; do
    if systemctl is-active --quiet transmission-daemon; then
        echo -e "${GREEN}✓ 服务已启动（第 $i 秒）${NC}"
        sleep 2
        break
    fi
    echo -e "  等待中... $i/15 秒"
    sleep 1
done

# 再等待几秒确保配置文件被写入
sleep 3

# 检查服务状态
if systemctl is-active --quiet transmission-daemon; then
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 验证配置文件是否被修改（密码应该被加密了）
    CURRENT_PASSWORD=$(jq -r '.["rpc-password"]' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$CURRENT_PASSWORD" == {* ]]; then
        echo -e "${GREEN}✓ 密码已被 Transmission 加密${NC}\n"
    else
        echo -e "${YELLOW}⚠ 密码可能未加密，将在下一步处理${NC}\n"
    fi
else
    echo -e "${RED}❌ 服务启动失败${NC}"
    systemctl status transmission-daemon
    journalctl -xeu transmission-daemon -n 20 --no-pager
    exit 1
fi

# --- 10. 二次配置：恢复白名单设置 ---
echo -e "${GREEN}[10/10] 强制恢复白名单配置...${NC}"
echo -e "${YELLOW}说明: Transmission 启动时会加密密码，现在确保白名单配置正确${NC}\n"

# 停止服务
echo -e "${YELLOW}停止服务...${NC}"
systemctl stop transmission-daemon
sleep 3

# 再次确认服务已停止
if systemctl is-active --quiet transmission-daemon; then
    echo -e "${RED}⚠ 服务未完全停止，强制终止...${NC}"
    killall -9 transmission-daemon 2>/dev/null
    sleep 2
fi

# 备份当前配置
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"

# 使用 jq 精确修改白名单，保留已加密的密码
echo -e "${YELLOW}更新白名单配置...${NC}"
jq --arg whitelist "$WHITELIST" \
   '.["rpc-whitelist"] = $whitelist | .["rpc-whitelist-enabled"] = true | .["rpc-authentication-required"] = true' \
   "$CONFIG_FILE" > /tmp/settings.json.tmp

# 验证新配置
if jq empty /tmp/settings.json.tmp 2>/dev/null; then
    mv /tmp/settings.json.tmp "$CONFIG_FILE"
    chown debian-transmission:debian-transmission "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}✓ 白名单配置已更新${NC}"
    
    # 显示关键配置
    echo -e "${YELLOW}当前配置：${NC}"
    jq '.["rpc-whitelist"], .["rpc-whitelist-enabled"], .["rpc-authentication-required"]' "$CONFIG_FILE"
else
    echo -e "${RED}❌ 配置更新失败，恢复备份${NC}"
    mv "${CONFIG_FILE}.backup" "$CONFIG_FILE"
    exit 1
fi
echo ""

# 最终启动
echo -e "${GREEN}最终启动服务...${NC}"
systemctl start transmission-daemon

# 等待服务启动
for i in {1..10}; do
    if systemctl is-active --quiet transmission-daemon; then
        echo -e "${GREEN}✓ 服务已成功启动${NC}"
        break
    fi
    echo -e "  等待启动... $i/10 秒"
    sleep 1
done

sleep 2

# --- 验证安装 ---
echo -e "\n${BLUE}============================================================${NC}"

if systemctl is-active --quiet transmission-daemon; then
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}🎉 安装成功！${NC}\n"
    
    echo -e "${YELLOW}=== 访问信息 ===${NC}"
    echo -e "  Web 地址: ${GREEN}http://$SERVER_IP:$RPC_PORT${NC}"
    echo -e "  用户名: ${GREEN}$RPC_USERNAME${NC}"
    echo -e "  密码: ${GREEN}$value_psw${NC} (请妥善保管)"
    
    echo -e "\n${YELLOW}=== 安全配置 ===${NC}"
    echo -e "  密码认证: ${GREEN}已启用${NC}"
    echo -e "  IP 白名单: ${GREEN}已启用${NC}"
    echo -e "  允许的 IP: ${GREEN}$WHITELIST${NC}"
    
    echo -e "\n${YELLOW}=== 目录信息 ===${NC}"
    echo -e "  下载目录: ${GREEN}$DOWNLOADS_DIR${NC}"
    echo -e "  配置文件: ${GREEN}$CONFIG_FILE${NC}"
    
    # 配置验证
    echo -e "\n${YELLOW}=== 配置验证 ===${NC}"
    CURRENT_WHITELIST=$(jq -r '.["rpc-whitelist"]' "$CONFIG_FILE")
    WHITELIST_ENABLED=$(jq -r '.["rpc-whitelist-enabled"]' "$CONFIG_FILE")
    AUTH_REQUIRED=$(jq -r '.["rpc-authentication-required"]' "$CONFIG_FILE")
    
    echo -e "  当前白名单: ${GREEN}$CURRENT_WHITELIST${NC}"
    echo -e "  白名单状态: ${GREEN}$WHITELIST_ENABLED${NC}"
    echo -e "  认证状态: ${GREEN}$AUTH_REQUIRED${NC}"
    
    # 端口检查
    echo -e "\n${YELLOW}=== 网络检查 ===${NC}"
    if command -v netstat &>/dev/null; then
        if netstat -tlnp 2>/dev/null | grep -q ":$RPC_PORT"; then
            echo -e "  端口监听: ${GREEN}✓ 端口 $RPC_PORT 正常监听${NC}"
        else
            echo -e "  端口监听: ${RED}✗ 端口 $RPC_PORT 未监听${NC}"
        fi
    elif command -v ss &>/dev/null; then
        if ss -tlnp 2>/dev/null | grep -q ":$RPC_PORT"; then
            echo -e "  端口监听: ${GREEN}✓ 端口 $RPC_PORT 正常监听${NC}"
        else
            echo -e "  端口监听: ${RED}✗ 端口 $RPC_PORT 未监听${NC}"
        fi
    else
        echo -e "  端口监听: ${YELLOW}⚠ 无法检查（缺少 netstat/ss 工具）${NC}"
    fi
    
    echo -e "\n${YELLOW}=== 安全提示 ===${NC}"
    echo -e "  ${RED}⚠${NC}  Transmission 使用 HTTP 协议（未加密）"
    echo -e "  ${RED}⚠${NC}  请确保只有可信 IP 在白名单中"
    echo -e "  ${GREEN}✓${NC}  建议定期更换密码"
    echo -e "  ${GREEN}✓${NC}  考虑使用 Nginx 反向代理添加 HTTPS"
    
    echo -e "\n${YELLOW}=== 常用命令 ===${NC}"
    echo -e "  查看状态: ${GREEN}systemctl status transmission-daemon${NC}"
    echo -e "  重启服务: ${GREEN}systemctl restart transmission-daemon${NC}"
    echo -e "  查看日志: ${GREEN}journalctl -xeu transmission-daemon -f${NC}"
    echo -e "  查看配置: ${GREEN}jq . $CONFIG_FILE${NC}"
    
    echo -e "\n${YELLOW}=== 修改白名单 ===${NC}"
    echo -e "  ${GREEN}systemctl stop transmission-daemon${NC}"
    echo -e "  ${GREEN}jq '.\"rpc-whitelist\" = \"新IP,127.0.0.1,::1\"' $CONFIG_FILE > /tmp/s.json${NC}"
    echo -e "  ${GREEN}mv /tmp/s.json $CONFIG_FILE && chown debian-transmission:debian-transmission $CONFIG_FILE${NC}"
    echo -e "  ${GREEN}systemctl start transmission-daemon${NC}"
    
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${GREEN}✨ 现在可以从 $value_url 访问 http://$SERVER_IP:$RPC_PORT 了！${NC}"
    echo -e "${BLUE}============================================================${NC}\n"
    
else
    echo -e "${RED}❌ 安装失败${NC}\n"
    echo -e "请运行以下命令排查："
    echo -e "  systemctl status transmission-daemon"
    echo -e "  journalctl -xeu transmission-daemon -n 50"
    exit 1
fi
#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# 错误处理函数
handle_error() {
    echo -e "${RED}错误: $1${NC}"
    exit 1
}

# 确保完全停止服务
stop_transmission() {
    echo "停止 transmission-daemon 服务..."
    systemctl stop transmission-daemon
    killall -9 transmission-daemon 2>/dev/null || true
    
    # 等待进程完全停止
    while pgrep -x "transmission-daemon" > /dev/null; do
        echo "等待进程停止..."
        sleep 1
    done
}

# 清理并重置transmission
cleanup_transmission() {
    echo "清理 transmission 配置..."
    stop_transmission
    
    # 删除可能损坏的配置文件
    rm -f /etc/transmission-daemon/settings.json
    
    # 重新创建目录结构
    mkdir -p /var/lib/transmission-daemon/downloads
    mkdir -p /var/lib/transmission-daemon/incomplete
    mkdir -p /etc/transmission-daemon
}

# 设置正确的权限
fix_permissions() {
    echo "修复权限..."
    
    # 设置目录权限
    chown -R debian-transmission:debian-transmission /var/lib/transmission-daemon
    chmod -R 755 /var/lib/transmission-daemon
    
    # 设置配置文件权限
    chown -R debian-transmission:debian-transmission /etc/transmission-daemon
    chmod 755 /etc/transmission-daemon
    chmod 600 /etc/transmission-daemon/settings.json
}

# 主安装流程
echo "开始安装 transmission..."

# 1. 获取用户输入
read -p "请输入允许访问的IP地址(多个IP用逗号分隔,例如: 192.168.1.*,192.168.2.*): " ALLOWED_IPS
read -s -p "请设置登录密码: " PASSWORD
echo

# 2. 清理现有安装
cleanup_transmission

# 3. 重新安装transmission-daemon
apt-get update || handle_error "更新软件源失败"
apt-get remove -y transmission-daemon || true
apt-get install -y transmission-daemon || handle_error "安装transmission-daemon失败"

# 4. 停止服务准备配置
stop_transmission

# 5. 创建配置文件
cat > /etc/transmission-daemon/settings.json << EOF
{
    "alt-speed-down": 50,
    "alt-speed-enabled": false,
    "alt-speed-up": 50,
    "bind-address-ipv4": "0.0.0.0",
    "bind-address-ipv6": "::",
    "blocklist-enabled": false,
    "download-dir": "/var/lib/transmission-daemon/downloads",
    "download-queue-enabled": true,
    "download-queue-size": 100,
    "encryption": 1,
    "incomplete-dir": "/var/lib/transmission-daemon/incomplete",
    "incomplete-dir-enabled": true,
    "rpc-authentication-required": true,
    "rpc-bind-address": "0.0.0.0",
    "rpc-enabled": true,
    "rpc-password": "$PASSWORD",
    "rpc-port": 9091,
    "rpc-username": "opengl",
    "rpc-whitelist": "$ALLOWED_IPS",
    "rpc-whitelist-enabled": true,
    "speed-limit-up": 0,
    "speed-limit-up-enabled": true,
    "umask": 2
}
EOF

# 6. 修复权限
fix_permissions

# 7. 重新加载systemd配置
systemctl daemon-reload

# 8. 启动服务
echo "启动服务..."
if ! systemctl start transmission-daemon; then
    echo -e "${RED}服务启动失败。显示详细日志：${NC}"
    journalctl -xeu transmission-daemon.service
    systemctl status transmission-daemon
    exit 1
fi

# 9. 检查服务状态
if systemctl is-active --quiet transmission-daemon; then
    echo -e "${GREEN}Transmission 安装成功！${NC}"
    echo "访问地址: http://服务器IP:9091"
    echo "用户名: opengl"
    echo "密码: $PASSWORD"
    echo "允许访问的IP: $ALLOWED_IPS"
else
    handle_error "服务启动失败"
fi
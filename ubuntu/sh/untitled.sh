#!/bin/bash

# LinuxServer Firefox + Nginx 反向代理自动化部署脚本
# 作者: Assistant
# 版本: 1.0

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印彩色信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示横幅
show_banner() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "  Firefox + Nginx 反向代理自动部署脚本"
    echo "=========================================="
    echo -e "${NC}"
}

# 检查用户权限并设置变量
check_user() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "检测到root用户运行"
        IS_ROOT=true
        SUDO_CMD=""
        USER_HOME="/root"
        print_info "将以root权限执行所有操作"
    else
        IS_ROOT=false
        SUDO_CMD="sudo"
        USER_HOME="$HOME"
        print_info "将使用sudo执行需要管理员权限的操作"
    fi
}

# 检查系统是否为Ubuntu/Debian
check_system() {
    if ! command -v apt &> /dev/null; then
        print_error "此脚本仅支持 Ubuntu/Debian 系统"
        exit 1
    fi
}

# 获取用户输入
get_user_input() {
    echo
    print_info "请输入部署信息："
    
    # 获取域名
    while true; do
        read -p "请输入你的域名 (例如: example.com): " DOMAIN
        if [[ -n "$DOMAIN" ]]; then
            break
        else
            print_warning "域名不能为空，请重新输入"
        fi
    done
    
    # 获取邮箱
    while true; do
        read -p "请输入你的邮箱 (用于SSL证书): " EMAIL
        if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            print_warning "邮箱格式不正确，请重新输入"
        fi
    done
    
    echo
    print_info "配置信息："
    echo "域名: $DOMAIN"
    echo "邮箱: $EMAIL"
    echo
    
    read -p "确认以上信息正确？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "部署已取消"
        exit 0
    fi
}

# 检查域名解析
check_domain_resolution() {
    print_info "检查域名解析..."
    
    # 检查dig命令是否存在
    if ! command -v dig &> /dev/null; then
        print_info "安装dig工具..."
        $SUDO_CMD apt update && $SUDO_CMD apt install dnsutils -y
    fi
    
    # 获取服务器公网IP
    SERVER_IP=$(curl -s --connect-timeout 10 ifconfig.me || curl -s --connect-timeout 10 ipinfo.io/ip || echo "无法获取")
    
    if [[ "$SERVER_IP" == "无法获取" ]]; then
        print_warning "无法获取服务器公网IP，跳过域名解析检查"
        return 0
    fi
    
    # 检查域名解析
    DOMAIN_IP=$(dig +short $DOMAIN 2>/dev/null | head -n1 || echo "无法解析")
    
    if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
        print_success "域名解析正确: $DOMAIN -> $SERVER_IP"
    else
        print_warning "域名解析检查结果:"
        echo "  服务器IP: $SERVER_IP"
        echo "  域名解析IP: $DOMAIN_IP"
        echo
        print_warning "注意: 如果域名刚配置，可能需要等待DNS传播生效"
        read -p "是否继续部署？(y/n): " continue_deploy
        if [[ "$continue_deploy" != "y" && "$continue_deploy" != "Y" ]]; then
            print_info "请先配置域名解析，然后重新运行脚本"
            exit 0
        fi
    fi
}

# 第一阶段：环境准备和Docker安装
install_docker() {
    print_info "第一阶段：安装Docker环境..."
    
    # 更新系统
    print_info "更新系统包..."
    $SUDO_CMD apt update && $SUDO_CMD apt upgrade -y
    
    # 安装Docker
    print_info "安装Docker..."
    $SUDO_CMD apt install docker.io -y
    
    # 启动Docker服务
    print_info "启动Docker服务..."
    $SUDO_CMD systemctl start docker
    $SUDO_CMD systemctl enable docker
    
    # 配置Docker权限
    if [[ "$IS_ROOT" == "true" ]]; then
        print_info "root用户，跳过用户组配置"
        # 直接验证Docker
        if docker --version > /dev/null 2>&1; then
            print_success "Docker安装成功: $(docker --version)"
            if docker run --rm hello-world > /dev/null 2>&1; then
                print_success "Docker测试通过"
            fi
        else
            print_error "Docker安装失败"
            exit 1
        fi
    else
        # 添加用户到docker组
        print_info "配置Docker权限..."
        $SUDO_CMD usermod -aG docker $USER
        
        # 刷新用户组权限（重要：让docker组生效）
        print_info "刷新用户组权限..."
        newgrp docker << EONG
        # 在新的用户组环境中验证Docker
        if docker --version > /dev/null 2>&1; then
            echo -e "${GREEN}[SUCCESS]${NC} Docker安装成功: \$(docker --version)"
            docker run --rm hello-world > /dev/null 2>&1 && echo -e "${GREEN}[SUCCESS]${NC} Docker测试通过"
        else
            echo -e "${RED}[ERROR]${NC} Docker权限配置失败"
            exit 1
        fi
EONG
    fi
    
    print_success "第一阶段完成：Docker环境安装成功"
}

# 第二阶段：部署Firefox容器
deploy_firefox() {
    print_info "第二阶段：部署Firefox容器..."
    
    # 创建配置目录
    print_info "创建Firefox配置目录..."
    mkdir -p $USER_HOME/firefox-config
    mkdir -p $USER_HOME/firefox-downloads
    
    # 设置目录权限（确保容器可以访问）
    if [[ "$IS_ROOT" == "true" ]]; then
        # root用户需要确保目录权限正确
        chown -R 1000:1000 $USER_HOME/firefox-config $USER_HOME/firefox-downloads
    else
        $SUDO_CMD chown -R 1000:1000 $USER_HOME/firefox-config $USER_HOME/firefox-downloads
    fi
    
    # 停止已存在的容器（如果有）
    if docker ps -a --format "table {{.Names}}" | grep -q "^firefox$"; then
        print_info "停止并删除已存在的Firefox容器..."
        docker stop firefox 2>/dev/null || true
        docker rm firefox 2>/dev/null || true
    fi
    
    # 部署Firefox容器
    print_info "启动Firefox容器..."
    docker run -d \
        --name=firefox \
        -e PUID=1000 \
        -e PGID=1000 \
        -p 127.0.0.1:3000:3000 \
        -v $USER_HOME/firefox-config:/config \
        -v $USER_HOME/firefox-downloads:/config/Downloads \
        --shm-size="1gb" \
        --restart unless-stopped \
        ghcr.io/linuxserver/firefox:latest
    
    # 等待容器启动
    print_info "等待Firefox容器启动..."
    sleep 15
    
    # 检查容器状态
    if ! docker ps | grep -q "firefox"; then
        print_error "Firefox容器启动失败"
        print_info "容器日志："
        docker logs firefox
        exit 1
    fi
    
    # 等待服务就绪
    print_info "等待Firefox服务就绪..."
    for i in {1..30}; do
        if curl -s --connect-timeout 3 http://127.0.0.1:3000 > /dev/null 2>&1; then
            print_success "Firefox服务已就绪"
            break
        fi
        if [ $i -eq 30 ]; then
            print_error "Firefox服务启动超时"
            docker logs firefox
            exit 1
        fi
        sleep 2
        echo -n "."
    done
    echo
    
    print_success "第二阶段完成：Firefox容器部署成功"
}

# 第三阶段：安装配置Nginx
install_nginx() {
    print_info "第三阶段：安装配置Nginx..."
    
    # 安装Nginx和相关工具
    print_info "安装Nginx和SSL工具..."
    $SUDO_CMD apt install nginx certbot net-tools python3-certbot-nginx -y
    
    # 启动Nginx服务
    print_info "启动Nginx服务..."
    $SUDO_CMD systemctl start nginx
    $SUDO_CMD systemctl enable nginx
    
    # 配置Nginx反向代理
    print_info "配置Nginx反向代理..."
    $SUDO_CMD tee /etc/nginx/sites-available/default > /dev/null << EOL
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # WebSocket支持
        proxy_http_version 1.1;
        proxy_buffering off;
        
        # 超时设置
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
EOL
    
    # 测试Nginx配置
    print_info "测试Nginx配置..."
    if $SUDO_CMD nginx -t; then
        print_success "Nginx配置语法正确"
    else
        print_error "Nginx配置语法错误"
        exit 1
    fi
    
    # 重新加载Nginx
    $SUDO_CMD systemctl reload nginx
    
    print_success "第三阶段完成：Nginx安装配置成功"
}

# 第四阶段：配置HTTPS证书
configure_https() {
    print_info "第四阶段：配置HTTPS证书..."
    
    # 检查80端口是否可访问
    print_info "检查HTTP访问..."
    
    # 等待nginx完全启动
    sleep 3
    
    # 检查本地访问
    if curl -s --connect-timeout 5 http://localhost | grep -q "noVNC" || curl -s --connect-timeout 5 http://127.0.0.1 > /dev/null 2>&1; then
        print_success "本地HTTP访问正常"
    else
        print_warning "本地HTTP访问测试失败，但继续尝试申请证书..."
    fi
    
    # 申请SSL证书
    print_info "申请SSL证书..."
    if $SUDO_CMD certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL; then
        print_success "SSL证书申请成功"
    else
        print_error "SSL证书申请失败"
        print_warning "可能的原因："
        echo "  1. 域名解析未生效"
        echo "  2. 服务器防火墙阻止了80/443端口"
        echo "  3. 域名已经有证书或达到申请限制"
        echo
        print_info "你可以稍后手动运行以下命令申请证书："
        echo "  $SUDO_CMD certbot --nginx -d $DOMAIN --email $EMAIL"
        return 1
    fi
    
    # 设置证书自动更新
    print_info "设置证书自动更新..."
    # 检查是否已存在定时任务，避免重复添加
    if $SUDO_CMD crontab -l 2>/dev/null | grep -q "certbot renew"; then
        print_info "证书自动更新任务已存在"
    else
        ($SUDO_CMD crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | $SUDO_CMD crontab -
        print_success "证书自动更新任务已添加"
    fi
    
    # 测试证书更新
    print_info "测试证书自动更新..."
    if $SUDO_CMD certbot renew --dry-run > /dev/null 2>&1; then
        print_success "证书自动更新测试通过"
    else
        print_warning "证书自动更新测试失败，但不影响当前使用"
    fi
    
    print_success "第四阶段完成：HTTPS证书配置成功"
}

# 显示部署结果
show_result() {
    echo
    echo -e "${GREEN}=========================================="
    echo "           部署完成！"
    echo -e "==========================================${NC}"
    echo
    print_success "Firefox浏览器已成功部署"
    echo
    print_info "访问信息："
    echo "  HTTP访问:  http://$DOMAIN"
    echo "  HTTPS访问: https://$DOMAIN"
    echo
    print_info "管理命令："
    if [[ "$IS_ROOT" == "true" ]]; then
        echo "  查看Firefox容器状态: docker ps"
        echo "  查看Firefox日志:     docker logs firefox"
        echo "  重启Firefox容器:     docker restart firefox"
        echo "  查看Nginx状态:       systemctl status nginx"
        echo "  重启Nginx:           systemctl restart nginx"
    else
        echo "  查看Firefox容器状态: docker ps"
        echo "  查看Firefox日志:     docker logs firefox"
        echo "  重启Firefox容器:     docker restart firefox"
        echo "  查看Nginx状态:       sudo systemctl status nginx"
        echo "  重启Nginx:           sudo systemctl restart nginx"
    fi
    echo
    print_warning "注意事项："
    echo "  1. 如果无法访问，请检查服务器防火墙设置"
    echo "  2. 确保80和443端口已开放"
    echo "  3. 首次访问可能需要等待1-2分钟初始化"
    echo
}

# 清理函数（在脚本异常退出时调用）
cleanup() {
    print_warning "脚本执行被中断，正在清理..."
    # 这里可以添加一些清理逻辑
    exit 1
}

# 主函数
main() {
    # 设置trap捕获信号
    trap cleanup INT TERM
    
    show_banner
    check_user
    check_system
    get_user_input
    check_domain_resolution
    
    print_info "开始自动化部署..."
    
    install_docker
    deploy_firefox
    install_nginx
    
    if configure_https; then
        show_result
    else
        print_warning "HTTPS配置失败，但HTTP访问应该可以正常使用"
        print_info "你可以通过 http://$DOMAIN 访问Firefox"
        print_info "稍后可以手动配置HTTPS证书"
    fi
}

# 执行主函数
main "$@"
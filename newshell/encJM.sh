#!/bin/bash

# 记录开始时间
start_time=$(date +%s)

# 生成固定长度的密钥和IV
generate_key_iv() {
    local password="$1"
    # 使用SHA256生成32字节密钥
    key=$(echo -n "$password" | openssl dgst -sha256 -binary | xxd -p -c 64)
    # 使用MD5生成16字节IV
    iv=$(echo -n "$password" | openssl dgst -md5 -binary | xxd -p -c 32)
}

# 获取用户输入的文件夹路径
echo "请输入文件夹路径："
read folder_path

# 进入指定路径
cd "$folder_path"

# 检查是否成功进入目录
if [ $? -ne 0 ]; then
    echo "错误：无法进入指定路径 $folder_path"
    exit 1
fi

echo "已成功进入路径：$(pwd)"

# 询问用户操作类型
echo "请选择操作："
echo "1. 加密"
echo "2. 解密"
read -p "请输入选择 (1 或 2)：" choice

case $choice in
    1)
        echo "您选择了加密"
        echo "请输入密码："
        read password
        
        # 生成密钥和IV
        generate_key_iv "$password"
        
        echo "开始加密文件..."
        for name in *; do 
            # 跳过目录和已加密文件
            if [ -f "$name" ] && [[ "$name" != *.data ]]; then
                echo "正在加密: $name"
                openssl enc -aes-256-cbc -K "$key" -iv "$iv" -in "$name" -out "$name.data"
                if [ $? -eq 0 ]; then
                    echo "✓ $name 加密成功"
                else
                    echo "✗ $name 加密失败"
                fi
            fi
        done
        echo "加密完成！"
        ;;
    2)
        echo "您选择了解密"
        echo "请输入密码："
        read password
        
        # 生成密钥和IV
        generate_key_iv "$password"
        
        echo "开始解密文件..."
        for name in `ls`; do 
            if [ -f "$name" ]; then
                echo "正在解密: $name"
                
                openssl enc -aes-256-cbc -K "$key" -iv "$iv" -in "$name" -out "$name.data" -d
                
                if [ $? -eq 0 ]; then
                    echo "✓ $name 解密成功"
                else
                    echo "✗ $name 解密失败"
                fi
            fi
        done
        echo "解密完成！"
        ;;
    *)
        echo "无效选择，请输入 1 或 2"
        exit 1
        ;;
esac

# 记录结束时间并计算总用时
end_time=$(date +%s)
total_time=$((end_time - start_time))

echo "================================"
echo "脚本执行完成！"
echo "总用时: ${total_time} 秒"

# 如果超过60秒，也显示分钟数
if [ $total_time -ge 60 ]; then
    minutes=$((total_time / 60))
    seconds=$((total_time % 60))
    echo "总用时: ${minutes} 分 ${seconds} 秒"
fi
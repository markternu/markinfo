#!/bin/bash

# AES-128-CBC 字符串加密脚本
# 模拟原始Objective-C代码的功能

# 默认密钥和IV
DEFAULT_KEY="1234567890123456"
DEFAULT_IV="123456789012345"

# 纯函数：字符串加密
# 参数：$1 - 要加密的字符串, $2 - 密钥, $3 - IV
# 返回：加密后的十六进制字符串，如果失败则返回空字符串
strADD() {
    local input_string="$1"
    local key="${2:-$DEFAULT_KEY}"
    local iv="${3:-$DEFAULT_IV}"
    
    # 检查输入是否为空
    if [ -z "$input_string" ]; then
        return 1
    fi
    
    # 将KEY和IV转换为十六进制格式（填充到合适长度）
    local hex_key=$(printf "%s" "$key" | xxd -p | tr -d '\n')
    local hex_iv=$(printf "%s" "$iv" | xxd -p | tr -d '\n')
    
    # 确保KEY和IV长度正确（AES-128需要16字节=32个十六进制字符）
    # 如果长度不足，用0填充；如果过长，截取
    hex_key=$(printf "%-32s" "$hex_key" | tr ' ' '0' | cut -c1-32)
    hex_iv=$(printf "%-32s" "$hex_iv" | tr ' ' '0' | cut -c1-32)
    
    # 执行AES加密并转换为十六进制
    local encrypted_hex=$(echo -n "$input_string" | openssl enc -aes-128-cbc -K "$hex_key" -iv "$hex_iv" -nosalt | xxd -p | tr -d '\n')
    
    # 检查加密是否成功
    if [ $? -eq 0 ] && [ -n "$encrypted_hex" ]; then
        echo "$encrypted_hex"
        return 0
    else
        return 1
    fi
}

# 纯函数：字符串解密
# 参数：$1 - 要解密的十六进制字符串, $2 - 密钥, $3 - IV
# 返回：解密后的原始字符串，如果失败则返回空字符串
strDECRYPT() {
    local encrypted_hex="$1"
    local key="${2:-$DEFAULT_KEY}"
    local iv="${3:-$DEFAULT_IV}"
    
    # 检查输入是否为空
    if [ -z "$encrypted_hex" ]; then
        return 1
    fi
    
    # 检查是否为有效的十六进制字符串
    if ! echo "$encrypted_hex" | grep -qE '^[0-9a-fA-F]+$'; then
        return 1
    fi
    
    # 将KEY和IV转换为十六进制格式
    local hex_key=$(printf "%s" "$key" | xxd -p | tr -d '\n')
    local hex_iv=$(printf "%s" "$iv" | xxd -p | tr -d '\n')
    
    # 确保KEY和IV长度正确
    hex_key=$(printf "%-32s" "$hex_key" | tr ' ' '0' | cut -c1-32)
    hex_iv=$(printf "%-32s" "$hex_iv" | tr ' ' '0' | cut -c1-32)
    
    # 执行AES解密
    local decrypted_text=$(echo "$encrypted_hex" | xxd -r -p | openssl enc -aes-128-cbc -d -K "$hex_key" -iv "$hex_iv" -nosalt 2>/dev/null)
    
    # 检查解密是否成功
    if [ $? -eq 0 ] && [ -n "$decrypted_text" ]; then
        echo "$decrypted_text"
        return 0
    else
        return 1
    fi
}

# 获取用户自定义密码
get_custom_password() {
    echo -n "是否使用自己的密码？(Y/N): " >&2
    read use_custom
    
    case $use_custom in
        [Yy]|[Yy][Ee][Ss])
            echo -n "请输入您的密码: " >&2
            read custom_password
            if [ -z "$custom_password" ]; then
                echo "错误: 密码不能为空，将使用默认密码" >&2
                echo "$DEFAULT_KEY"
                echo "$DEFAULT_IV"
            else
                echo "$custom_password"
                echo "$custom_password"
            fi
            ;;
        *)
            echo "$DEFAULT_KEY"
            echo "$DEFAULT_IV"
            ;;
    esac
}

# 交互式加密函数
interactive_encrypt() {
    echo "📜-加密-字符串"
    echo -n "请输入字符串: "
    read input_string
    echo  # 换行
    
    # 检查输入是否为空
    if [ -z "$input_string" ]; then
        echo "错误: 输入字符串不能为空"
        return 1
    fi
    
    # 获取密码设置
    local password_info
    password_info=($(get_custom_password))
    local key="${password_info[0]}"
    local iv="${password_info[1]}"
    
    # 调用纯函数进行加密
    local result=$(strADD "$input_string" "$key" "$iv")
    
    if [ $? -eq 0 ]; then
        echo "加密结果: $result"
    else
        echo "加密失败"
        return 1
    fi
}

# 交互式解密函数
interactive_decrypt() {
    echo "📜-解密-字符串"
    echo -n "请输入十六进制加密字符串: "
    read encrypted_hex
    echo  # 换行
    
    # 检查输入是否为空
    if [ -z "$encrypted_hex" ]; then
        echo "错误: 输入字符串不能为空"
        return 1
    fi
    
    # 获取密码设置
    local password_info
    password_info=($(get_custom_password))
    local key="${password_info[0]}"
    local iv="${password_info[1]}"
    
    # 调用纯函数进行解密
    local result=$(strDECRYPT "$encrypted_hex" "$key" "$iv")
    
    if [ $? -eq 0 ]; then
        echo "解密结果: $result"
    else
        echo "解密失败，请检查输入的十六进制字符串是否正确，或密码是否匹配"
        return 1
    fi
}

# 文件夹文件名加密函数
folder_encrypt() {
    echo "📁-加密-文件夹文件名"
    echo -n "请输入文件夹路径: "
    read folder_path
    echo  # 换行
    
    # 检查输入是否为空
    if [ -z "$folder_path" ]; then
        echo "错误: 文件夹路径不能为空"
        return 1
    fi
    
    # 检查文件夹是否存在
    if [ ! -d "$folder_path" ]; then
        echo "错误: 文件夹不存在: $folder_path"
        return 1
    fi
    
    # 获取密码设置
    local password_info
    password_info=($(get_custom_password))
    local key="${password_info[0]}"
    local iv="${password_info[1]}"
    
    # 保存当前目录
    local original_dir=$(pwd)
    
    # 进入文件夹
    if ! cd "$folder_path"; then
        echo "错误: 无法进入文件夹: $folder_path"
        return 1
    fi
    
    echo "正在加密文件夹中的文件名..."
    local success_count=0
    local fail_count=0
    
    # 遍历文件夹中的所有文件
    for name in *; do
        # 跳过目录
        if [ -d "$name" ]; then
            echo "跳过目录: $name"
            continue
        fi
        
        # 跳过不存在的文件（处理空文件夹的情况）
        if [ ! -e "$name" ]; then
            continue
        fi
        
        # 对文件名进行加密
        local encrypted_name=$(strADD "$name" "$key" "$iv")
        
        if [ $? -eq 0 ] && [ -n "$encrypted_name" ]; then
            # 重命名文件
            if mv "$name" "$encrypted_name"; then
                echo "✓ $name -> $encrypted_name"
                success_count=$((success_count + 1))
            else
                echo "✗ 重命名失败: $name"
                fail_count=$((fail_count + 1))
            fi
        else
            echo "✗ 加密失败: $name"
            fail_count=$((fail_count + 1))
        fi
    done
    
    # 返回原目录
    cd "$original_dir"
    
    echo "================================"
    echo "加密完成！成功: $success_count, 失败: $fail_count"
    echo "================================"
}

# 文件夹文件名解密函数
folder_decrypt() {
    echo "📁-解密-文件夹文件名"
    echo -n "请输入文件夹路径: "
    read folder_path
    echo  # 换行
    
    # 检查输入是否为空
    if [ -z "$folder_path" ]; then
        echo "错误: 文件夹路径不能为空"
        return 1
    fi
    
    # 检查文件夹是否存在
    if [ ! -d "$folder_path" ]; then
        echo "错误: 文件夹不存在: $folder_path"
        return 1
    fi
    
    # 获取密码设置
    local password_info
    password_info=($(get_custom_password))
    local key="${password_info[0]}"
    local iv="${password_info[1]}"
    
    # 保存当前目录
    local original_dir=$(pwd)
    
    # 进入文件夹
    if ! cd "$folder_path"; then
        echo "错误: 无法进入文件夹: $folder_path"
        return 1
    fi
    
    echo "正在解密文件夹中的文件名..."
    local success_count=0
    local fail_count=0
    
    # 遍历文件夹中的所有文件
    for name in *; do
        # 跳过目录
        if [ -d "$name" ]; then
            echo "跳过目录: $name"
            continue
        fi
        
        # 跳过不存在的文件（处理空文件夹的情况）
        if [ ! -e "$name" ]; then
            continue
        fi
        
        # 对文件名进行解密
        local decrypted_name=$(strDECRYPT "$name" "$key" "$iv")
        
        if [ $? -eq 0 ] && [ -n "$decrypted_name" ]; then
            # 重命名文件
            if mv "$name" "$decrypted_name"; then
                echo "✓ $name -> $decrypted_name"
                success_count=$((success_count + 1))
            else
                echo "✗ 重命名失败: $name"
                fail_count=$((fail_count + 1))
            fi
        else
            echo "✗ 解密失败: $name"
            fail_count=$((fail_count + 1))
        fi
    done
    
    # 返回原目录
    cd "$original_dir"
    
    echo "================================"
    echo "解密完成！成功: $success_count, 失败: $fail_count"
    echo "================================"
}

# 主菜单函数
main_menu() {
    echo "================================"
    echo "    字符串加密/解密工具"
    echo "================================"
    echo "1. 加密字符串"
    echo "2. 解密字符串"
    echo "3. 加密文件夹文件名"
    echo "4. 解密文件夹文件名"
    echo "0. 退出"
    echo "================================"
    echo -n "请选择功能 (0-4): "
    read choice
    
    case $choice in
        1)
            interactive_encrypt
            ;;
        2)
            interactive_decrypt
            ;;
        3)
            folder_encrypt
            ;;
        4)
            folder_decrypt
            ;;
        0)
            echo "再见！"
            exit 0
            ;;
        *)
            echo "无效选择，请重新输入"
            ;;
    esac
}

# 检查openssl是否安装
check_dependencies() {
    if ! command -v openssl &> /dev/null; then
        echo "错误: 需要安装openssl"
        echo "在macOS上安装: brew install openssl"
        echo "在Ubuntu上安装: sudo apt-get install openssl"
        exit 1
    fi
    
    if ! command -v xxd &> /dev/null; then
        echo "错误: 需要安装xxd"
        echo "在macOS上通常已预装"
        echo "在Ubuntu上安装: sudo apt-get install xxd"
        exit 1
    fi
}

# 主程序
main() {
    # 检查依赖
    check_dependencies
    
    # 交互模式
    while true; do
        main_menu
        echo
    done
}

# 运行主程序
main "$@"
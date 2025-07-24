#!/bin/bash






#========================================================================================================================

#========================================================================================================================


# 功能1：去掉文件夹下所有文件的文件后缀
function1() {
    read -p "请输入目标文件夹路径：" dir
    if [[ ! -d "$dir" ]]; then
        echo "文件夹不存在！"
        return 1
    fi

    for file in "$dir"/*; do
        if [[ -f "$file" && "$file" == *.* ]]; then
            base="${file%.*}"
            mv "$file" "$base"
            echo "已重命名：$file -> $base"
        fi
    done
}

# 功能2：无脑给所有文件/文件夹添加指定后缀
function2() {
    read -p "请输入目标文件夹路径：" dir
    if [[ ! -d "$dir" ]]; then
        echo "文件夹不存在！"
        return 1
    fi

    read -p "请输入要添加的后缀（不要带点）：" suffix

    cd "$dir" || { echo "无法进入目录"; return 1; }

    for name in *; do
        if [[ -e "$name" ]]; then
            mv "$name" "$name.$suffix"
            echo "已重命名：$name -> $name.$suffix"
        fi
    done
}


# 主函数
qu_main() {
    echo "请选择你要执行的功能："
    echo "1：去掉文件夹下所有文件的文件后缀"
    echo "2：给文件夹下所有无后缀的文件添加后缀"

    read -p "请输入功能编号（1或2）：" choice

    case "$choice" in
        1)
            function1
            ;;
        2)
            function2
            ;;
        *)
            echo "无效的选项！请输入1或2。"
            ;;
    esac
}

# # 主函数
# main() {
#     echo "请选择你要执行的功能："
#     echo "1：去掉文件夹下所有文件的文件后缀"
#     echo "2：给文件夹下所有无后缀的文件添加后缀"

#     read -p "请输入功能编号（1或2）：" choice

#     case "$choice" in
#         1)
#             function1
#             ;;
#         2)
#             function2
#             ;;
#         *)
#             echo "无效的选项！请输入1或2。"
#             ;;
#     esac
# }

# # 运行主程序
# main "$@"




#========================================================================================================================

#========================================================================================================================




# 生成固定长度的密钥和IV
generate_key_iv() {
    local password="$1"
    # 使用SHA256生成32字节密钥
    key=$(echo -n "$password" | openssl dgst -sha256 -binary | xxd -p -c 64)
    # 使用MD5生成16字节IV
    iv=$(echo -n "$password" | openssl dgst -md5 -binary | xxd -p -c 32)
}

jiamioktion() {

# 记录开始时间
start_time=$(date +%s)
    
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
                openssl enc -aes-256-cbc -K "$key" -iv "$iv" -in "$name" -out "$name.data" && rm $name
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

}






#========================================================================================================================

#========================================================================================================================

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

# # 主程序
# main() {
#     # 检查依赖
#     check_dependencies
    
#     # 交互模式
#     while true; do
#         main_menu
#         echo
#     done
# }

# # 运行主程序
# main "$@"


#========================================================================================================================

#========================================================================================================================

# 主程序
main() {

check_dependencies

echo "======================================"
echo "🛠️ 请选择功能："
echo "A/a: 文件夹文件加密/解密 (encJM.sh)"
echo "B/b: 字符串加密/解密 (untitled5.sh)"
echo "C/c: 添加或者去掉后缀"
echo "======================================"
read -p "请输入选项 (A/B/C): " choice

case "$choice" in
    A|a)
        echo "正在调用 encJM.sh..."
        jiamioktion
        ;;
    B|b)
        echo "正在调用 untitled5.sh..."
        main_menu
        ;;
    C|c)
        echo "正在调用  添加或者去掉后缀"
        qu_main
        ;;
    *)
        echo "❌ 无效输入，请输入 A 或 B, C"
        exit 1
        ;;
esac
}

# 运行主程序
main "$@"






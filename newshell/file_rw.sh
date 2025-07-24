#!/bin/bash

# 功能1：向文件末尾追加固定1000字节的数据
# 参数1: 要写入的字符串
# 参数2: 目标文件路径
function write_fixed_bytes() {
    local name="$1"
    local file_path="$2"
    
    # 检查参数
    if [ -z "$name" ] || [ -z "$file_path" ]; then
        echo "❌ 错误: 参数不能为空"
        echo "用法: write_fixed_bytes <字符串> <文件路径>"
        return 1
    fi
    
    # 创建一个临时文件来构造1000字节的数据
    local temp_file=$(mktemp)
    
    # 将字符串写入临时文件
    echo -n "$name" > "$temp_file"
    
    # 获取当前字符串的字节数
    local current_size=$(wc -c < "$temp_file")
    
    # 计算需要填充的字节数
    local padding_size=$((1000 - current_size))
    
    if [ $padding_size -lt 0 ]; then
        # 如果字符串超过1000字节，截断到1000字节
        echo "⚠️  警告: 输入字符串超过1000字节，将被截断"
        head -c 1000 "$temp_file" >> "$file_path"
    else
        # 如果字符串不足1000字节，用空字符(\0)填充
        cat "$temp_file" >> "$file_path"
        # 使用dd填充剩余字节为0
        dd if=/dev/zero bs=1 count=$padding_size >> "$file_path" 2>/dev/null
    fi
    
    # 清理临时文件
    rm -f "$temp_file"
    
    echo "✅ 成功向文件 '$file_path' 末尾写入1000字节数据"
    echo "📝 写入内容: '$name'"
    echo "📊 文件当前大小: $(wc -c < "$file_path") 字节"
}

# 功能2：读取文件末尾1000字节并还原为字符串，然后删除这1000字节
# 参数1: 文件路径
function read_and_remove_fixed_bytes() {
    local file_path="$1"
    
    # 检查参数
    if [ -z "$file_path" ]; then
        echo "❌ 错误: 文件路径不能为空"
        echo "用法: read_and_remove_fixed_bytes <文件路径>"
        return 1
    fi
    
    # 检查文件是否存在
    if [ ! -f "$file_path" ]; then
        echo "❌ 错误: 文件 '$file_path' 不存在"
        return 1
    fi
    
    # 获取文件大小
    local file_size=$(wc -c < "$file_path")
    
    # 检查文件是否至少有1000字节
    if [ $file_size -lt 1000 ]; then
        echo "❌ 错误: 文件大小不足1000字节 (当前: $file_size 字节)"
        return 1
    fi
    
    # 读取末尾1000字节
    local last_1000_bytes=$(tail -c 1000 "$file_path")
    
    # 移除末尾的null字符并转换为可读字符串
    local readable_string=$(echo -n "$last_1000_bytes" | tr -d '\0')
    
    # 计算新文件大小（移除末尾1000字节）
    local new_size=$((file_size - 1000))
    
    # 创建临时文件
    local temp_file=$(mktemp)
    
    # 将原文件除了末尾1000字节的部分复制到临时文件
    head -c $new_size "$file_path" > "$temp_file"
    
    # 用临时文件替换原文件
    mv "$temp_file" "$file_path"
    
    echo "✅ 成功读取并移除文件 '$file_path' 末尾1000字节"
    echo "📝 读取到的字符串: '$readable_string'"
    echo "📊 文件新大小: $(wc -c < "$file_path") 字节"
    
    # 返回读取到的字符串（通过echo）
    return 0
}

# 主程序
main() {
    echo "🛠️  请选择功能："
    echo "1) 向文件末尾写入固定1000字节数据"
    echo "2) 读取文件末尾1000字节数据并移除"
    echo "3) 退出"
    
    read -p "请输入选择 (1-3): " choice
    
    case $choice in
        1)
            echo ""
            echo "📝 功能1: 写入固定1000字节数据"
            read -p "请输入要写入的字符串: " input_string
            read -p "请输入目标文件路径: " target_file
            echo ""
            write_fixed_bytes "$input_string" "$target_file"
            ;;
        2)
            echo ""
            echo "📖 功能2: 读取末尾1000字节数据"
            read -p "请输入文件路径: " source_file
            echo ""
            read_and_remove_fixed_bytes "$source_file"
            ;;
        3)
            echo "👋 再见!"
            exit 0
            ;;
        *)
            echo "❌ 无效选择，请重新运行脚本"
            exit 1
            ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
    echo ""
    main  # 递归调用主菜单
}

# 脚本入口点
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
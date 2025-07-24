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

# 功能3：遍历文件夹并处理文件
# 参数1: 文件路径列表字符串 (如 "/Users/cc/Desktop/test/oppp/v{1..40}" 或 "/v30")
function process_folders() {
    local file_path_list_string="$1"
    local file_suffix_string="tmpfile"
    
    # 检查参数
    if [ -z "$file_path_list_string" ]; then
        echo "❌ 错误: 文件路径列表不能为空"
        echo "用法: process_folders <文件路径列表>"
        echo "示例: process_folders \"/Users/cc/Desktop/test/oppp/v{1..40}\" 或 process_folders \"/v30\""
        return 1
    fi
    
    echo "🔍 开始处理文件夹列表: $file_path_list_string"
    echo "🚫 跳过条件: 存在后缀为 '$file_suffix_string' 的文件"
    echo ""
    
    # 展开路径列表 (处理 {1..40} 这样的bash扩展)
    local path_array
    # 临时启用bash的大括号展开，然后安全地展开路径
    set +f  # 启用文件名展开
    eval "path_array=($file_path_list_string)"
    set -f  # 重新禁用文件名展开以避免意外展开
    
    # 如果展开失败或者只有一个元素且包含大括号，尝试手动处理
    if [ ${#path_array[@]} -eq 1 ] && [[ "${path_array[0]}" == *"{"* ]]; then
        echo "🔧 检测到大括号语法，手动展开路径..."
        local original_path="${path_array[0]}"
        
        # 检查是否包含 {数字..数字} 模式
        if [[ "$original_path" =~ \{([0-9]+)\.\.([0-9]+)\} ]]; then
            local start_num="${BASH_REMATCH[1]}"
            local end_num="${BASH_REMATCH[2]}"
            local base_path="${original_path%\{*\}*}"  # 获取大括号前的部分
            local suffix_path="${original_path#*\}}"   # 获取大括号后的部分
            
            # 重新构建路径数组
            path_array=()
            for ((i=start_num; i<=end_num; i++)); do
                path_array+=("${base_path}${i}${suffix_path}")
            done
            
            echo "   ✅ 成功展开为 ${#path_array[@]} 个路径 (${base_path}${start_num}${suffix_path} 到 ${base_path}${end_num}${suffix_path})"
        fi
    fi
    
    local processed_count=0
    local skipped_count=0
    
    # 遍历每个路径
    for path in "${path_array[@]}"; do
        echo "📁 处理文件夹: $path"
        
        # 检查文件夹是否存在
        if [ ! -d "$path" ]; then
            echo "   ⚠️  警告: 文件夹 '$path' 不存在，跳过"
            echo ""
            continue
        fi
        
        # 使用while read循环安全处理包含空格的文件名
        local has_tmp_file=false
        local files_processed=0
        local files_deleted=0
        
        # 第一遍：检查是否存在以指定后缀结尾的文件
        while IFS= read -r -d '' file_path; do
            local filename=$(basename "$file_path")
            if [[ "$filename" == *"$file_suffix_string" ]]; then
                has_tmp_file=true
                echo "   🚫 发现后缀文件: $filename，跳过此文件夹"
                break
            fi
        done < <(find "$path" -maxdepth 1 -type f -print0 2>/dev/null)
        
        if [ "$has_tmp_file" = true ]; then
            ((skipped_count++))
            echo ""
            continue
        fi
        
        # 检查文件夹是否为空
        local file_count=$(find "$path" -maxdepth 1 -type f 2>/dev/null | wc -l)
        if [ "$file_count" -eq 0 ]; then
            echo "   📝 文件夹为空，跳过"
            echo ""
            continue
        fi
        
        # 第二遍：处理文件夹中的文件
        echo "   ✅ 开始处理文件夹中的文件"
        
        while IFS= read -r -d '' file_path; do
            local filename=$(basename "$file_path")
            
            # 调试信息：显示正在处理的文件
            echo "   🔍 处理文件: '$filename'"
            
            if [ "$filename" = "url" ]; then
                echo "   🗑️  删除文件: $file_path"
                rm -f "$file_path"
                if [ $? -eq 0 ]; then
                    ((files_deleted++))
                    echo "   ✅ 成功删除: $file_path"
                else
                    echo "   ❌ 删除失败: $file_path"
                fi
            else
                echo "   📝 使用write_fixed_bytes给文件 '$file_path' 末尾追加文件名 '$filename'"
                write_fixed_bytes "$filename" "$file_path"
                if [ $? -eq 0 ]; then
                    ((files_processed++))
                else
                    echo "   ❌ 追加数据失败: $file_path"
                fi
            fi
        done < <(find "$path" -maxdepth 1 -type f -print0 2>/dev/null)
        
        echo "   📊 处理完成 - 追加数据: $files_processed 个文件, 删除: $files_deleted 个文件"
        ((processed_count++))
        echo ""
    done
    
    echo "🎉 批量处理完成!"
    echo "📊 统计信息:"
    echo "   - 总文件夹数: ${#path_array[@]}"
    echo "   - 已处理文件夹: $processed_count"
    echo "   - 跳过文件夹: $skipped_count"
    echo ""
}

# 功能4：遍历文件夹并还原文件名（与功能3相反）
# 参数1: 文件路径列表字符串 (如 "/Users/cc/Desktop/test/oppp/v{1..40}" 或 "/v30")
function restore_file_names() {
    local file_path_list_string="$1"
    
    # 检查参数
    if [ -z "$file_path_list_string" ]; then
        echo "❌ 错误: 文件路径列表不能为空"
        echo "用法: restore_file_names <文件路径列表>"
        echo "示例: restore_file_names \"/Users/cc/Desktop/test/oppp/v{1..40}\" 或 restore_file_names \"/v30\""
        return 1
    fi
    
    echo "🔄 开始还原文件名，处理文件夹列表: $file_path_list_string"
    echo "📖 操作: 读取文件末尾1000字节作为新文件名"
    echo ""
    
    # 展开路径列表 (处理 {1..40} 这样的bash扩展)
    local path_array
    # 临时启用bash的大括号展开，然后安全地展开路径
    set +f  # 启用文件名展开
    eval "path_array=($file_path_list_string)"
    set -f  # 重新禁用文件名展开以避免意外展开
    
    # 如果展开失败或者只有一个元素且包含大括号，尝试手动处理
    if [ ${#path_array[@]} -eq 1 ] && [[ "${path_array[0]}" == *"{"* ]]; then
        echo "🔧 检测到大括号语法，手动展开路径..."
        local original_path="${path_array[0]}"
        
        # 检查是否包含 {数字..数字} 模式
        if [[ "$original_path" =~ \{([0-9]+)\.\.([0-9]+)\} ]]; then
            local start_num="${BASH_REMATCH[1]}"
            local end_num="${BASH_REMATCH[2]}"
            local base_path="${original_path%\{*\}*}"  # 获取大括号前的部分
            local suffix_path="${original_path#*\}}"   # 获取大括号后的部分
            
            # 重新构建路径数组
            path_array=()
            for ((i=start_num; i<=end_num; i++)); do
                path_array+=("${base_path}${i}${suffix_path}")
            done
            
            echo "   ✅ 成功展开为 ${#path_array[@]} 个路径 (${base_path}${start_num}${suffix_path} 到 ${base_path}${end_num}${suffix_path})"
        fi
    fi
    
    local processed_count=0
    local error_count=0
    
    # 遍历每个路径
    for path in "${path_array[@]}"; do
        echo "📁 处理文件夹: $path"
        
        # 检查文件夹是否存在
        if [ ! -d "$path" ]; then
            echo "   ⚠️  警告: 文件夹 '$path' 不存在，跳过"
            echo ""
            continue
        fi
        
        # 检查文件夹是否为空
        local file_count=$(find "$path" -maxdepth 1 -type f 2>/dev/null | wc -l)
        if [ "$file_count" -eq 0 ]; then
            echo "   📝 文件夹为空，跳过"
            echo ""
            continue
        fi
        
        # 处理文件夹中的文件
        echo "   ✅ 开始还原文件夹中的文件名"
        local files_processed=0
        local files_failed=0
        
        # 使用while read循环安全处理包含空格的文件名
        while IFS= read -r -d '' file_path; do
            local original_filename=$(basename "$file_path")
            local file_dir=$(dirname "$file_path")
            
            # 调试信息：显示正在处理的文件
            echo "   🔍 处理文件: '$original_filename'"
            
            # 调用功能2读取末尾1000字节并获取字符串
            local get_name_string
            get_name_string=$(read_and_remove_fixed_bytes "$file_path" 2>/dev/null)
            local read_result=$?
            
            if [ $read_result -eq 0 ] && [ -n "$get_name_string" ]; then
                # 构建新文件路径
                local new_file_path="$file_dir/$get_name_string"
                
                echo "   📝 还原文件名: '$original_filename' -> '$get_name_string'"
                
                # 检查目标文件是否已存在
                if [ -f "$new_file_path" ] && [ "$file_path" != "$new_file_path" ]; then
                    echo "   ⚠️  警告: 目标文件 '$get_name_string' 已存在，添加时间戳后缀"
                    local timestamp=$(date +"%Y%m%d_%H%M%S")
                    new_file_path="$file_dir/${get_name_string}_${timestamp}"
                fi
                
                # 重命名文件
                mv "$file_path" "$new_file_path"
                if [ $? -eq 0 ]; then
                    ((files_processed++))
                    echo "   ✅ 成功重命名: '$new_file_path'"
                else
                    ((files_failed++))
                    echo "   ❌ 重命名失败: '$original_filename'"
                fi
            else
                ((files_failed++))
                echo "   ❌ 读取末尾数据失败或数据为空: '$original_filename'"
            fi
            
        done < <(find "$path" -maxdepth 1 -type f -print0 2>/dev/null)
        
        echo "   📊 处理完成 - 成功还原: $files_processed 个文件, 失败: $files_failed 个文件"
        ((processed_count++))
        echo ""
    done
    
    echo "🎉 批量还原完成!"
    echo "📊 统计信息:"
    echo "   - 总文件夹数: ${#path_array[@]}"
    echo "   - 已处理文件夹: $processed_count"
    echo ""
}

# 功能2：读取文件末尾1000字节并还原为字符串，然后删除这1000字节
# 参数1: 文件路径
# 返回: 读取到的字符串（通过echo输出）
function read_and_remove_fixed_bytes() {
    local file_path="$1"
    
    # 检查参数
    if [ -z "$file_path" ]; then
        echo "❌ 错误: 文件路径不能为空" >&2
        echo "用法: read_and_remove_fixed_bytes <文件路径>" >&2
        return 1
    fi
    
    # 检查文件是否存在
    if [ ! -f "$file_path" ]; then
        echo "❌ 错误: 文件 '$file_path' 不存在" >&2
        return 1
    fi
    
    # 获取文件大小
    local file_size=$(wc -c < "$file_path")
    
    # 检查文件是否至少有1000字节
    if [ $file_size -lt 1000 ]; then
        echo "❌ 错误: 文件大小不足1000字节 (当前: $file_size 字节)" >&2
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
    
    # 当在交互模式下调用时显示详细信息
    if [ "${FUNCNAME[1]}" = "main" ]; then
        echo "✅ 成功读取并移除文件 '$file_path' 末尾1000字节" >&2
        echo "📝 读取到的字符串: '$readable_string'" >&2
        echo "📊 文件新大小: $(wc -c < "$file_path") 字节" >&2
    fi
    
    # 返回读取到的字符串
    echo "$readable_string"
    return 0
}

# 主程序
main() {
    echo "🛠️  请选择功能："
    echo "1) 向文件末尾写入固定1000字节数据"
    echo "2) 读取文件末尾1000字节数据并移除"
    echo "3) 批量处理文件夹中的文件（追加文件名到末尾）"
    echo "4) 批量还原文件名（从文件末尾读取并重命名）"
    echo "5) 退出"
    
    read -p "请输入选择 (1-5): " choice
    
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
            echo ""
            echo "🔄 功能3: 批量处理文件夹"
            echo "支持格式:"
            echo "  - 单个文件夹: /v30"
            echo "  - 多个文件夹: '/v{1..40}' (注意加引号)"
            echo "  - 完整路径: '/Users/cc/Desktop/test/oppp/v{1..40}'"
            echo "  - 多个文件夹: '/path1 /path2 /path3'"
            read -p "请输入文件夹路径列表: " folder_list
            echo ""
            process_folders "$folder_list"
            ;;
        4)
            echo ""
            echo "🔄 功能4: 批量还原文件名"
            echo "支持格式:"
            echo "  - 单个文件夹: /v30"
            echo "  - 多个文件夹: '/v{1..40}' (注意加引号)"
            echo "  - 完整路径: '/Users/cc/Desktop/test/oppp/v{1..40}'"
            echo "  - 多个文件夹: '/path1 /path2 /path3'"
            read -p "请输入文件夹路径列表: " folder_list
            echo ""
            restore_file_names "$folder_list"
            ;;
        5)
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
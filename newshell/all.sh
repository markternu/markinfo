#!/bin/bash


#========================================================================================================================

#========================================================================================================================



# 功能1：向文件末尾追加固定1100字节的数据（100字节标志位 + 1000字节内容）
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
    
    # 标志字符串
    local mark_string="FKY996"
    
    echo "🔧 开始写入数据到文件: '$file_path'"
    
    # 第一步：写入100字节的标志位
    echo "📝 第一步: 写入100字节标志位 '$mark_string'"
    
    # 获取标志字符串的字节数
    local mark_size=${#mark_string}
    echo "   标志字符串长度: $mark_size 字节"
    
    # 计算标志位需要填充的字节数
    local mark_padding_size=$((100 - mark_size))
    
    if [ $mark_padding_size -lt 0 ]; then
        # 如果标志字符串超过100字节，截断到100字节
        echo "   ⚠️  警告: 标志字符串超过100字节，将被截断"
        printf "%.100s" "$mark_string" >> "$file_path"
    else
        # 如果标志字符串不足100字节，用空字符(\0)填充
        echo "   填充 $mark_padding_size 个null字节"
        printf "%s" "$mark_string" >> "$file_path"
        # 使用printf填充剩余字节为0
        printf "%*s" $mark_padding_size "" | tr ' ' '\0' >> "$file_path"
    fi
    
    echo "   ✅ 标志位写入完成 (100字节)"
    
    # 第二步：写入1000字节的内容数据
    echo "📝 第二步: 写入1000字节内容数据 '$name'"
    
    # 获取当前字符串的字节数
    local current_size=${#name}
    echo "   内容字符串长度: $current_size 字节"
    
    # 计算需要填充的字节数
    local padding_size=$((1000 - current_size))
    
    if [ $padding_size -lt 0 ]; then
        # 如果字符串超过1000字节，截断到1000字节
        echo "   ⚠️  警告: 输入字符串超过1000字节，将被截断"
        printf "%.1000s" "$name" >> "$file_path"
    else
        # 如果字符串不足1000字节，用空字符(\0)填充
        echo "   填充 $padding_size 个null字节"
        printf "%s" "$name" >> "$file_path"
        # 使用printf填充剩余字节为0
        printf "%*s" $padding_size "" | tr ' ' '\0' >> "$file_path"
    fi
    
    echo "   ✅ 内容数据写入完成 (1000字节)"
    
    echo "🎉 总计写入完成!"
    echo "✅ 成功向文件 '$file_path' 末尾写入1100字节数据"
    echo "   📊 结构: 100字节标志位 + 1000字节内容"
    echo "   🏷️  标志位: '$mark_string'"
    echo "   📝 写入内容: '$name'"
    echo "   📊 文件当前大小: $(wc -c < "$file_path") 字节"
}

# 功能2：读取文件末尾1100字节并还原为字符串，然后删除这1100字节
# 参数1: 文件路径
# 返回: 读取到的内容字符串（通过echo输出）
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
    
    # 检查文件是否至少有1100字节
    if [ $file_size -lt 1100 ]; then
        echo "❌ 错误: 文件大小不足1100字节 (当前: $file_size 字节)" >&2
        return 1
    fi
    
    # 使用dd直接读取末尾1100字节，避免管道问题
    local temp_file=$(mktemp)
    tail -c 1100 "$file_path" > "$temp_file"
    
    # 使用dd分离前100字节（标志位）和后1000字节（内容数据）
    local mark_temp_file=$(mktemp)
    local content_temp_file=$(mktemp)
    
    # 读取前100字节（标志位）
    dd if="$temp_file" of="$mark_temp_file" bs=1 count=100 2>/dev/null
    
    # 读取后1000字节（内容数据）
    dd if="$temp_file" of="$content_temp_file" bs=1 skip=100 count=1000 2>/dev/null
    
    # 将100字节标志位还原为字符串
    local mark_string=$(cat "$mark_temp_file" | tr -d '\0')
    
    # 验证标志位
    if [ "$mark_string" != "FKY996" ]; then
        echo "❌ 错误: 文件非通过本脚本追加写入生成的文件，不能通过本功能读取并切除文件末尾数据" >&2
        echo "🔍 检测到的标志位: '$mark_string' (期望: 'FKY996')" >&2
        # 清理临时文件
        rm -f "$temp_file" "$mark_temp_file" "$content_temp_file"
        return 1
    fi
    
    # 将1000字节内容数据还原为字符串
    local content_string=$(cat "$content_temp_file" | tr -d '\0')
    
    # 清理临时文件
    rm -f "$temp_file" "$mark_temp_file" "$content_temp_file"
    
    # 计算新文件大小（移除末尾1100字节）
    local new_size=$((file_size - 1100))
    
    # 创建临时文件
    local new_temp_file=$(mktemp)
    
    # 将原文件除了末尾1100字节的部分复制到临时文件
    head -c $new_size "$file_path" > "$new_temp_file"
    
    # 用临时文件替换原文件
    mv "$new_temp_file" "$file_path"
    
    # 当在交互模式下调用时显示详细信息
    if [ "${FUNCNAME[1]}" = "main" ]; then
        echo "✅ 成功读取并移除文件 '$file_path' 末尾1100字节" >&2
        echo "🏷️  验证标志位: '$mark_string' ✓" >&2
        echo "📝 读取到的内容: '$content_string'" >&2
        echo "📊 文件新大小: $(wc -c < "$file_path") 字节" >&2
    fi
    
    # 返回读取到的内容字符串
    echo "$content_string"
    return 0
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
    echo "📖 操作: 读取文件末尾1100字节作为新文件名"
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
            
            # 调用功能2读取末尾1100字节并获取字符串
            local get_name_string
            local error_temp_file=$(mktemp)
            get_name_string=$(read_and_remove_fixed_bytes "$file_path" 2>"$error_temp_file")
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
                # 清理临时文件
                rm -f "$error_temp_file"
            else
                ((files_failed++))
                echo "   ❌ 读取末尾数据失败或数据为空: '$original_filename'"
                echo "     调试信息: read_result=$read_result, get_name_string='$get_name_string'"
                # 显示详细的错误信息
                if [ -s "$error_temp_file" ]; then
                    echo "     详细错误信息:"
                    sed 's/^/       /' "$error_temp_file"
                fi
                rm -f "$error_temp_file"
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


# 主程序
write_fixed_bytes_main() {
    echo "🛠️  请选择功能："
    echo "1) 向文件末尾写入固定1100字节数据 (100字节标志位 + 1000字节内容)"
    echo "2) 读取文件末尾1100字节数据并移除 (验证标志位)"
    echo "3) 批量处理文件夹中的文件（追加文件名到末尾）"
    echo "4) 批量还原文件名（从文件末尾读取并重命名）"
    echo "5) 退出"
    
    read -p "请输入选择 (1-5): " choice
    
    case $choice in
        1)
            echo ""
            echo "📝 功能1: 写入固定1100字节数据 (100字节标志位 + 1000字节内容)"
            read -p "请输入要写入的字符串: " input_string
            read -p "请输入目标文件路径: " target_file
            echo ""
            write_fixed_bytes "$input_string" "$target_file"
            ;;
        2)
            echo ""
            echo "📖 功能2: 读取末尾1100字节数据 (验证标志位并提取内容)"
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
    
    
}

# # 主程序
# main() {
#     echo "🛠️  请选择功能："
#     echo "1) 向文件末尾写入固定1100字节数据 (100字节标志位 + 1000字节内容)"
#     echo "2) 读取文件末尾1100字节数据并移除 (验证标志位)"
#     echo "3) 批量处理文件夹中的文件（追加文件名到末尾）"
#     echo "4) 批量还原文件名（从文件末尾读取并重命名）"
#     echo "5) 退出"
    
#     read -p "请输入选择 (1-5): " choice
    
#     case $choice in
#         1)
#             echo ""
#             echo "📝 功能1: 写入固定1100字节数据 (100字节标志位 + 1000字节内容)"
#             read -p "请输入要写入的字符串: " input_string
#             read -p "请输入目标文件路径: " target_file
#             echo ""
#             write_fixed_bytes "$input_string" "$target_file"
#             ;;
#         2)
#             echo ""
#             echo "📖 功能2: 读取末尾1100字节数据 (验证标志位并提取内容)"
#             read -p "请输入文件路径: " source_file
#             echo ""
#             read_and_remove_fixed_bytes "$source_file"
#             ;;
#         3)
#             echo ""
#             echo "🔄 功能3: 批量处理文件夹"
#             echo "支持格式:"
#             echo "  - 单个文件夹: /v30"
#             echo "  - 多个文件夹: '/v{1..40}' (注意加引号)"
#             echo "  - 完整路径: '/Users/cc/Desktop/test/oppp/v{1..40}'"
#             echo "  - 多个文件夹: '/path1 /path2 /path3'"
#             read -p "请输入文件夹路径列表: " folder_list
#             echo ""
#             process_folders "$folder_list"
#             ;;
#         4)
#             echo ""
#             echo "🔄 功能4: 批量还原文件名"
#             echo "支持格式:"
#             echo "  - 单个文件夹: /v30"
#             echo "  - 多个文件夹: '/v{1..40}' (注意加引号)"
#             echo "  - 完整路径: '/Users/cc/Desktop/test/oppp/v{1..40}'"
#             echo "  - 多个文件夹: '/path1 /path2 /path3'"
#             read -p "请输入文件夹路径列表: " folder_list
#             echo ""
#             restore_file_names "$folder_list"
#             ;;
#         5)
#             echo "👋 再见!"
#             exit 0
#             ;;
#         *)
#             echo "❌ 无效选择，请重新运行脚本"
#             exit 1
#             ;;
#     esac
    
#     echo ""
#     read -p "按回车键继续..."
#     echo ""
#     main  # 递归调用主菜单
# }

# # 脚本入口点
# if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
#     main "$@"
# fi





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
echo "D/d: 追加文件名到末尾/或者去掉文件末尾的追加数据"



echo "======================================"
read -p "请输入选项 (A/B/C/D): " choice

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
    D|d)
        echo "正在调用  追加文件名到末尾/或者去掉文件末尾的追加数据"
        write_fixed_bytes_main
        ;;
    *)
        echo "❌ 无效输入，请输入 A 或 B, C, D"
        exit 1
        ;;
esac
}

# 运行主程序
main "$@"






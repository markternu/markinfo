function batch_view_original_names() {
    local file_path_list_string="$1"
    
    # 检查参数
    if [ -z "$file_path_list_string" ]; then
        echo "❌ 错误: 文件路径列表不能为空"
        echo "用法: batch_view_original_names <文件路径列表>"
        echo "示例: batch_view_original_names \"/Users/cc/Desktop/test/oppp/v{1..40}\" 或 batch_view_original_names \"/v30\""
        return 1
    fi
    
    echo "👁️  开始批量查看原始文件名，处理文件夹列表: $file_path_list_string"
    echo "📖 操作: 读取文件末尾TLV数据获取原始文件名（不删除数据）"
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
    local success_count=0
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
        echo "   👁️  开始查看文件夹中的文件原始名称"
        local files_success=0
        local files_failed=0
        
        # 使用while read循环安全处理包含空格的文件名
        while IFS= read -r -d '' file_path; do
            local current_filename=$(basename "$file_path")
            
            # 调试信息：显示正在处理的文件
            echo "     🔍 查看文件: '$current_filename'"
            
            # 调用view_original_names函数查看原始文件名
            local original_name_string
            local error_temp_file=$(mktemp)
            original_name_string=$(view_original_names "$file_path" 2>"$error_temp_file")
            local view_result=$?
            
            if [ $view_result -eq 0 ] && [ -n "$original_name_string" ]; then
                ((files_success++))
                echo "     ✅ 当前文件名: '$current_filename'"
                echo "     📝 原始文件名: '$original_name_string'"
                echo "     ➡️  映射关系: '$original_name_string' -> '$current_filename'"
            else
                ((files_failed++))
                echo "     ❌ 读取原始文件名失败: '$current_filename'"
                # 显示详细的错误信息
                if [ -s "$error_temp_file" ]; then
                    echo "       详细错误信息:"
                    sed 's/^/          /' "$error_temp_file"
                fi
            fi
            
            # 清理临时文件
            rm -f "$error_temp_file"
            echo ""
            
        done < <(find "$path" -maxdepth 1 -type f -print0 2>/dev/null)
        
        echo "   📊 文件夹处理完成 - 成功查看: $files_success 个文件, 失败: $files_failed 个文件"
        ((processed_count++))
        ((success_count += files_success))
        ((error_count += files_failed))
        echo ""
    done
    
    echo "🎉 批量查看完成!"
    echo "📊 统计信息:"
    echo "   - 总文件夹数: ${#path_array[@]}"
    echo "   - 已处理文件夹: $processed_count"
    echo "   - 成功查看文件: $success_count"
    echo "   - 失败文件: $error_count"
    echo ""
}


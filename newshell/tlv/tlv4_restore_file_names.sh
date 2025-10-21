#!/bin/bash

# ============================================================================
# 功能4：遍历文件夹并还原文件名（TLV版本）
# 参数1: 文件路径列表字符串 (如 "/Users/cc/Desktop/test/oppp/v{1..40}" 或 "/v30")
# 依赖: 需要配合 tlv2_read_and_remove_fixed_bytes.sh 中的函数使用
# ============================================================================
function restore_file_names() {
    local file_path_list_string="$1"
    
    # ========================================================================
    # 参数检查
    # ========================================================================
    if [ -z "$file_path_list_string" ]; then
        echo "❌ 错误: 文件路径列表不能为空"
        echo "用法: restore_file_names <文件路径列表>"
        echo "示例: restore_file_names \"/Users/cc/Desktop/test/oppp/v{1..40}\" 或 restore_file_names \"/v30\""
        return 1
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📄 批量还原文件名工具 (TLV版本)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 处理文件夹列表: $file_path_list_string"
    echo "📖 操作说明: 从文件末尾读取 TLV 数据作为新文件名"
    echo "🗑️  同时移除: 文件末尾的 TLV 数据块"
    echo "📋 数据格式: Type(100B) + Length(4B) + Value(NB)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # ========================================================================
    # 展开路径列表 (处理 {1..40} 这样的bash扩展)
    # ========================================================================
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
    
    echo ""
    
    local processed_count=0
    local error_count=0
    local total_success=0
    local total_failed=0
    
    # ========================================================================
    # 遍历每个路径
    # ========================================================================
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
            echo "   📭 文件夹为空，跳过"
            echo ""
            continue
        fi
        
        # 处理文件夹中的文件
        echo "   ✅ 开始还原文件夹中的文件名"
        local files_processed=0
        local files_failed=0
        
        # ====================================================================
        # 使用while read循环安全处理包含空格的文件名
        # ====================================================================
        while IFS= read -r -d '' file_path; do
            local original_filename=$(basename "$file_path")
            local file_dir=$(dirname "$file_path")
            
            # 显示正在处理的文件
            echo "     🔍 处理文件: '$original_filename'"
            
            # ================================================================
            # 调用功能2读取末尾TLV数据并获取字符串
            # 使用 tlv2 版本的 read_and_remove_fixed_bytes
            # ================================================================
            local get_name_string
            local error_temp_file=$(mktemp)
            
            # 调用 read_and_remove_fixed_bytes 函数（TLV版本）
            # 该函数会：
            #   1. 验证 TLV 格式（标志位 FKY996）
            #   2. 读取文件名
            #   3. 移除文件末尾的 TLV 数据
            get_name_string=$(read_and_remove_fixed_bytes "$file_path" 2>"$error_temp_file")
            local read_result=$?
            
            if [ $read_result -eq 0 ] && [ -n "$get_name_string" ]; then
                # ============================================================
                # 成功读取到文件名，进行重命名
                # ============================================================
                
                # 构建新文件路径
                local new_file_path="$file_dir/$get_name_string"
                
                echo "     📝 还原文件名: '$original_filename' -> '$get_name_string'"
                
                # 检查目标文件是否已存在
                if [ -f "$new_file_path" ] && [ "$file_path" != "$new_file_path" ]; then
                    echo "     ⚠️  警告: 目标文件 '$get_name_string' 已存在，添加时间戳后缀"
                    local timestamp=$(date +"%Y%m%d_%H%M%S" 2>/dev/null || date +"%s")
                    
                    # 分离文件名和扩展名
                    local name_without_ext="${get_name_string%.*}"
                    local ext="${get_name_string##*.}"
                    
                    if [ "$name_without_ext" = "$get_name_string" ]; then
                        # 没有扩展名
                        new_file_path="$file_dir/${get_name_string}_${timestamp}"
                    else
                        # 有扩展名
                        new_file_path="$file_dir/${name_without_ext}_${timestamp}.${ext}"
                    fi
                    
                    echo "        新文件名: '$(basename "$new_file_path")'"
                fi
                
                # 重命名文件
                if mv "$file_path" "$new_file_path" 2>/dev/null; then
                    ((files_processed++))
                    echo "     ✅ 成功重命名: '$(basename "$new_file_path")'"
                else
                    ((files_failed++))
                    echo "     ❌ 重命名失败: '$original_filename'"
                fi
                
                # 清理临时文件
                rm -f "$error_temp_file"
                
            else
                # ============================================================
                # 读取失败或数据为空
                # ============================================================
                ((files_failed++))
                echo "     ❌ 读取末尾数据失败或数据为空: '$original_filename'"
                echo "        调试信息: read_result=$read_result, get_name_string='$get_name_string'"
                
                # 显示详细的错误信息
                if [ -s "$error_temp_file" ]; then
                    echo "        详细错误信息:"
                    sed 's/^/          /' "$error_temp_file"
                fi
                rm -f "$error_temp_file"
            fi
            
            echo ""
            
        done < <(find "$path" -maxdepth 1 -type f -print0 2>/dev/null)
        
        echo "   📊 文件夹处理完成 - 成功还原: $files_processed 个文件, 失败: $files_failed 个文件"
        ((processed_count++))
        ((total_success += files_processed))
        ((total_failed += files_failed))
        echo ""
    done
    
    # ========================================================================
    # 输出统计信息
    # ========================================================================
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 批量还原完成!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 统计信息:"
    echo "   ├─ 总文件夹数:       ${#path_array[@]}"
    echo "   ├─ 已处理文件夹:     $processed_count"
    echo "   ├─ 成功还原文件:     $total_success"
    echo "   └─ 失败文件:         $total_failed"
    echo ""
    echo "✅ TLV 数据已从所有成功文件中移除"
    echo "📋 还原后文件已恢复原始文件名"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}


# ============================================================================
# 使用示例
# ============================================================================
# restore_file_names "/Users/cc/Desktop/test/oppp/v{1..40}"
# restore_file_names "/v30"

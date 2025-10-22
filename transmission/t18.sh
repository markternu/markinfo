#!/bin/bash


#========================================================================================================================

#========================================================================================================================





#========================================================================================================================
# DDDDD >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
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
    local file_suffix_string="aria2"
    
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



# 功能5：获取一个带序号的文件名
# 返回: 生成的文件名（通过echo输出）
function getFileName() {
    # 文件前缀
    local filePrefix="dom"
    local indexFile="/indexFXY"
    
    echo "🔢 开始生成文件名..." >&2
    
    # 检查索引文件是否存在，不存在则创建并初始化为1
    if [ ! -f "$indexFile" ]; then
        echo "📝 索引文件不存在，创建并初始化: $indexFile" >&2
        echo "1" > "$indexFile"
        if [ $? -eq 0 ]; then
            echo "   ✅ 成功创建索引文件" >&2
        else
            echo "   ❌ 创建索引文件失败" >&2
            return 1
        fi
    fi
    
    # 读取当前索引值
    local index
    if ! index=$(cat "$indexFile" 2>/dev/null); then
        echo "❌ 错误: 无法读取索引文件 $indexFile" >&2
        return 1
    fi
    
    # 验证索引值是否为数字
    if ! [[ "$index" =~ ^[0-9]+$ ]]; then
        echo "❌ 错误: 索引文件中的值不是有效数字: '$index'" >&2
        echo "🔧 重置索引文件为1" >&2
        echo "1" > "$indexFile"
        index=1
    fi
    
    echo "📖 读取的索引值: $index" >&2
    
    # 生成文件名
    local fileNameString="${filePrefix}${index}"
    echo "🏷️  生成的文件名: '$fileNameString'" >&2
    
    # 索引值加一并写回文件
    ((index++))
    if echo "$index" > "$indexFile"; then
        echo "📝 索引值已更新为: $index" >&2
    else
        echo "⚠️  警告: 更新索引文件失败，但仍返回生成的文件名" >&2
    fi
    
    # 返回生成的文件名（输出到标准输出）
    echo "$fileNameString"
    return 0
}


# 功能6：根据文件后缀判断是否为视频文件
# 参数1: 文件路径
# 返回: 0表示是视频文件，1表示不是视频文件
function isVideoFileFunction() {
    local filePath="$1"
    
    # 检查参数
    if [ -z "$filePath" ]; then
        echo "❌ 错误: 文件路径不能为空" >&2
        return 1
    fi
    
    # 检查文件是否存在
    if [ ! -f "$filePath" ]; then
        echo "❌ 错误: 文件 '$filePath' 不存在" >&2
        return 1
    fi
    
    # 获取文件后缀
    local file_suffix_string="${filePath##*.}"
    
    # 如果没有后缀（文件名中没有点），返回false
    if [ "$file_suffix_string" = "$filePath" ]; then
        return 1
    fi
    
    # 将后缀转换为小写
    local file_suffix_string_allLowercase=$(echo "$file_suffix_string" | tr '[:upper:]' '[:lower:]')
    
    # 定义视频文件后缀列表
    local video_extensions=(
        "mp4" "avi" "wmv" "mov" "mkv" "flv" "webm" "m4v" "3gp" "3g2"
        "mpg" "mpeg" "m2v" "m4p" "m4v" "divx" "xvid" "asf" "rm" "rmvb"
        "vob" "ts" "mts" "m2ts" "f4v" "f4p" "f4a" "f4b" "ogv" "ogg"
        "dv" "amv" "m2p" "ps" "qt" "yuv" "viv" "nsr" "nsv" "nut"
    )
    
    # 检查后缀是否在视频文件列表中
    for ext in "${video_extensions[@]}"; do
        if [ "$file_suffix_string_allLowercase" = "$ext" ]; then
            return 0  # 是视频文件
        fi
    done
    
    return 1  # 不是视频文件
}
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# ============================================================================
# processVideoFiles 完整函数套件 (V-L-T 结构)
# ============================================================================
# 包含的函数:
#   1. isVideoFileFunction       - 判断是否为视频文件（未修改）
#   2. write_fixed_bytes         - 写入V-L-T数据（已更新）
#   3. read_fixed_bytes          - 读取V-L-T数据（已更新）
#   4. verify_tlv_data           - 验证V-L-T数据（已更新）
#   5. remove_tlv_data           - 移除V-L-T数据（已更新）
#   6. processVideoFiles         - 批量处理视频文件（主函数）
# ============================================================================
#
# 数据结构 (V-L-T):
#   [Value]  N字节：  文件名实际内容（UTF-8编码）
#   [Length] 4字节：  文件名长度 N（32位无符号整数，大端序）
#   [Type]   100字节：标志位 "FKY996" + null填充
#
# ============================================================================

# ============================================================================
# 功能1：向文件末尾追加 V-L-T 格式数据（已更新）
# 参数1: 要写入的字符串（文件名）
# 参数2: 目标文件路径
# 返回: 0=成功, 1=失败
# ============================================================================
function write_fixed_bytes() {
    local name="$1"
    local file_path="$2"
    
    # 参数检查
    if [ -z "$name" ] || [ -z "$file_path" ]; then
        echo "❌ 错误: 参数不能为空" >&2
        echo "用法: write_fixed_bytes <字符串> <文件路径>" >&2
        return 1
    fi
    
    # 文件存在性检查
    if [ ! -f "$file_path" ]; then
        echo "❌ 错误: 文件不存在: '$file_path'" >&2
        return 1
    fi
    
    # 标志字符串
    local mark_string="FKY996"
    
    echo "🔧 开始写入 V-L-T 数据到文件: '$file_path'"
    
    # ==================================================
    # 第一步：写入 Value 字段（文件名原始内容）
    # ==================================================
    # 计算文件名的实际字节数（UTF-8 编码）
    local name_size=$(printf "%s" "$name" | wc -c)
    echo "📝 [Value] 写入文件名内容 ($name_size 字节)"
    
    # 检查长度是否超过32位无符号整数最大值
    if [ $name_size -gt 4294967295 ]; then
        echo "❌ 错误: 文件名过长 ($name_size 字节)，超过4GB限制" >&2
        return 1
    fi
    
    # 直接写入文件名，保留原始 UTF-8 编码
    printf "%s" "$name" >> "$file_path"
    
    echo "   ✅ Value 字段写入完成"

    # ==================================================
    # 第二步：写入 Length 字段（4字节长度信息）
    # ==================================================
    echo "📝 [Length] 写入文件名长度字段 (4字节, 值=$name_size)"
    
    # 将长度转换为4字节大端序整数
    printf "%08x" "$name_size" | xxd -r -p >> "$file_path"
    
    echo "   ✅ Length 字段写入完成"
    
    # ==================================================
    # 第三步：写入 Type 字段（100字节标志位）
    # ==================================================
    echo "📝 [Type] 写入100字节标志位 '$mark_string' (文件末尾)"
    
    local mark_size=$(printf "%s" "$mark_string" | wc -c)
    local mark_padding_size=$((100 - mark_size))
    
    if [ $mark_padding_size -lt 0 ]; then
        echo "   ⚠️  警告: 标志字符串超过100字节，将被截断" >&2
        printf "%s" "$mark_string" | dd bs=1 count=100 >> "$file_path" 2>/dev/null
    else
        # 写入标志字符串
        printf "%s" "$mark_string" >> "$file_path"
        # 填充剩余字节为 null
        dd if=/dev/zero bs=1 count=$mark_padding_size >> "$file_path" 2>/dev/null
    fi
    
    echo "   ✅ Type 字段写入完成 (100字节)"
    
    # ==================================================
    # 完成统计
    # ==================================================
    local total_bytes=$((name_size + 4 + 100))
    
    echo ""
    echo "🎉 V-L-T 数据写入完成!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 写入统计 (结构: Value-Length-Type):"
    echo "   ├─ [Type]   标志位: 100 字节 (固定)"
    echo "   ├─ [Length] 长度字段: 4 字节 (值=$name_size)"
    echo "   └─ [Value]  文件名: $name_size 字节 (UTF-8)"
    echo "   ─────────────────────────────────────────────"
    echo "   总计写入: $total_bytes 字节"
    echo ""
    echo "📝 文件名预览: '${name:0:50}$([ ${#name} -gt 50 ] && echo "...")'"
    echo "📊 文件当前大小: $(wc -c < "$file_path") 字节"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    return 0
}


# ============================================================================
# 功能3：验证文件是否包含有效的 V-L-T 数据（已更新）
# 参数1: 文件路径
# 返回: 0=包含有效TLV数据, 1=不包含或数据无效
# ============================================================================
function verify_tlv_data() {
    local file_path="$1"
    
    if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
        return 1
    fi
    
    local file_size=$(wc -c < "$file_path")
    
    # 文件太小 (L+T = 104 字节)
    if [ $file_size -lt 104 ]; then
        return 1
    fi
    
    # 读取文件末尾100字节 (Type 字段)
    local mark=$(tail -c 100 "$file_path" | tr -d '\0')
    
    # 验证标志位
    if [ "$mark" = "FKY996" ]; then
        return 0  # 包含有效 V-L-T 数据
    else
        return 1  # 不包含有效 V-L-T 数据
    fi
}


# ============================================================================
# 功能2：从文件末尾读取 V-L-T 格式数据（已更新）
# 参数1: 文件路径
# 返回: 0=成功, 1=失败
# 输出: 读取到的文件名（通过 echo）
# ============================================================================
function read_fixed_bytes() {
    local file_path="$1"
    
    # 参数检查
    if [ -z "$file_path" ]; then
        echo "❌ 错误: 文件路径不能为空" >&2
        return 1
    fi
    
    # 文件存在性检查
    if [ ! -f "$file_path" ]; then
        echo "❌ 错误: 文件不存在: '$file_path'" >&2
        return 1
    fi
    
    local file_size=$(wc -c < "$file_path")
    
    # 最小文件大小检查（至少需要 L + T = 104 字节）
    if [ $file_size -lt 104 ]; then
        echo "❌ 错误: 文件太小 ($file_size 字节)，无法包含完整 V-L-T 数据" >&2
        return 1
    fi
    
    echo "🔍 开始读取文件末尾 V-L-T 数据: '$file_path'" >&2
    echo "" >&2
    
    # ==================================================
    # 第一步：读取 Type 字段（标志位验证）
    # ==================================================
    echo "📖 [Type] 读取并验证标志位 (末尾 100 字节)..." >&2
    
    # 读取文件末尾100字节
    local mark=$(tail -c 100 "$file_path" | tr -d '\0')
    
    echo "   标志位内容: '$mark'" >&2
    
    if [ "$mark" != "FKY996" ]; then
        echo "❌ 错误: 标志位不匹配 (期望='FKY996', 实际='$mark')" >&2
        echo "   文件可能未经处理或数据已损坏" >&2
        return 1
    fi
    
    echo "   ✅ 标志位验证通过" >&2

    # ==================================================
    # 第二步：读取 Length 字段
    # ==================================================
    echo "📖 [Length] 读取长度字段 (末尾 104 字节中的前 4 字节)..." >&2
    
    # 读取 L+T 块 (末尾104字节)，并提取 L (前4字节)
    local length_hex=$(tail -c 104 "$file_path" | head -c 4 | xxd -p | tr -d '\n')
    local name_length=$((16#$length_hex))
    
    echo "   文件名长度: $name_length 字节" >&2
    
    # 长度合理性检查
    local total_tlv_size=$((name_length + 4 + 100))
    if [ $name_length -lt 0 ] || [ $file_size -lt $total_tlv_size ]; then
        echo "❌ 错误: 长度字段异常 ($name_length 字节)，数据损坏或文件不完整" >&2
        return 1
    fi
    
    echo "   ✅ 长度字段读取成功" >&2
    
    # ==================================================
    # 第三步：读取 Value 字段（文件名内容）
    # ==================================================
    echo "📖 [Value] 读取文件名内容 ($name_length 字节)..." >&2
    
    # 读取完整的 V-L-T 块
    # 然后提取 V (前 name_length 字节)
    local file_name=$(tail -c $total_tlv_size "$file_path" | head -c $name_length)
    
    echo "   ✅ 文件名读取成功" >&2
    echo "" >&2
    
    # 输出结果
    echo "🎉 V-L-T 数据读取完成!" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "📊 读取结果 (结构: Value-Length-Type):" >&2
    echo "   ├─ [Type]   标志位: FKY996 ✅" >&2
    echo "   ├─ [Length] 文件名长度: $name_length 字节" >&2
    echo "   └─ [Value]  文件名内容: '$file_name'" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    
    # 将文件名输出到 stdout
    echo "$file_name"
    
    return 0
}


# ============================================================================
# 功能4：移除文件末尾的 V-L-T 数据（已更新）
# 参数1: 文件路径
# 返回: 0=成功, 1=失败
# ============================================================================
function remove_tlv_data() {
    local file_path="$1"
    
    if [ -z "$file_path" ]; then
        echo "❌ 错误: 文件路径不能为空" >&2
        return 1
    fi
    
    if [ ! -f "$file_path" ]; then
        echo "❌ 错误: 文件不存在: '$file_path'" >&2
        return 1
    fi
    
    # 先验证是否包含 V-L-T 数据
    if ! verify_tlv_data "$file_path"; then
        echo "❌ 错误: 文件不包含有效的 V-L-T 数据" >&2
        return 1
    fi
    
    echo "🗑️  正在移除 V-L-T 数据..."
    
    local file_size=$(wc -c < "$file_path")
    
    # 读取 Length 字段 (末尾104字节中的前4字节)
    local length_hex=$(tail -c 104 "$file_path" | head -c 4 | xxd -p | tr -d '\n')
    local name_length=$((16#$length_hex))
    
    # 计算需要删除的总字节数
    local tlv_total_size=$((name_length + 4 + 100))
    
    # 计算原始文件大小
    local original_size=$((file_size - tlv_total_size))
    
    echo "   V-L-T 数据大小: $tlv_total_size 字节"
    echo "   原始文件大小: $original_size 字节"
    
    # 使用 truncate 截断文件
    truncate -s $original_size "$file_path"
    
    echo "✅ V-L-T 数据已移除，文件已恢复"
    
    return 0
}


# ============================================================================
# 功能7：给视频文件末尾追加 V-L-T 格式信息（主函数）
# 参数1: 文件夹路径
# ============================================================================
function processVideoFiles() {
    local folderPath="$1"
    local file_suffix_string="aria2"
    
    # 检查参数
    if [ -z "$folderPath" ]; then
        echo "❌ 错误: 文件夹路径不能为空"
        echo "用法: processVideoFiles <文件夹路径>"
        return 1
    fi
    
    # 检查文件夹是否存在
    if [ ! -d "$folderPath" ]; then
        echo "❌ 错误: 文件夹 '$folderPath' 不存在"
        return 1
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎬 视频文件 V-L-T 标记处理工具"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 目标文件夹: '$folderPath'"
    echo "📏 处理条件:"
    echo "   ✅ 必须是视频文件"
    echo "   ✅ 文件大小 > 100MB"
    echo "   ✅ 未添加过 V-L-T 标记"
    echo "🚫 跳过条件:"
    echo "   ⏭️  存在后缀为 '$file_suffix_string' 的文件（下载未完成）"
    echo ""
    echo "🔄 开始递归扫描..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    local total_files=0
    local video_files=0
    local processed_files=0
    local skipped_files=0
    local skipped_already_marked=0
    local skipped_folders=0
    local total_bytes_written=0
    local min_size_bytes=$((100 * 1024 * 1024))  # 100MB
    
    # 递归处理文件夹的内部函数
    function process_directory() {
        local current_dir="$1"
        local relative_path="${current_dir#$folderPath}"
        [ -z "$relative_path" ] && relative_path="/"
        
        echo "📁 进入文件夹: $(basename "$current_dir") $relative_path"
        
        # 检查当前文件夹是否存在以file_suffix_string为后缀的文件
        local has_tmp_file=false
        while IFS= read -r -d '' file_path; do
            local filename=$(basename "$file_path")
            if [[ "$filename" == *"$file_suffix_string" ]]; then
                has_tmp_file=true
                echo "   🚫 发现下载标记文件: $filename，跳过此文件夹及其子文件夹"
                ((skipped_folders++))
                break
            fi
        done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
        
        # 如果当前文件夹存在后缀文件，跳过整个文件夹
        if [ "$has_tmp_file" = true ]; then
            echo ""
            return 0
        fi
        
        # 处理当前文件夹中的文件
        while IFS= read -r -d '' file_path; do
            ((total_files++))
            local filename=$(basename "$file_path")
            local file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
            
            # 显示当前处理的文件
            echo "   🔍 检查文件: '$filename'"
            
            # 检查是否为视频文件
            if isVideoFileFunction "$file_path"; then
                ((video_files++))
                echo "      ✅ 识别为视频文件"
                
                # 检查是否已经添加过 V-L-T 标记
                # 【已更新】verify_tlv_data 现在非常高效
                if verify_tlv_data "$file_path"; then
                    ((skipped_already_marked++))
                    echo "      ⏭️  跳过: 已存在 V-L-T 标记"
                    continue
                fi
                
                # 检查文件大小
                if [ -n "$file_size" ] && [ "$file_size" -gt "$min_size_bytes" ]; then
                    local size_mb=$((file_size / 1024 / 1024))
                    echo "      📏 文件大小: ${size_mb}MB (符合条件)"
                    echo "      📝 开始写入 V-L-T 数据..."
                    
                    # 记录写入前的文件大小
                    local size_before=$(wc -c < "$file_path")
                    
                    # 调用 write_fixed_bytes 函数（V-L-T格式）
                    # 【已更新】将按 V-L-T 顺序写入
                    if write_fixed_bytes "$filename" "$file_path" > /dev/null 2>&1; then
                        ((processed_files++))
                        
                        # 计算写入的字节数
                        local size_after=$(wc -c < "$file_path")
                        local bytes_written=$((size_after - size_before))
                        total_bytes_written=$((total_bytes_written + bytes_written))
                        
                        echo "      🎉 成功处理: '$filename' (写入 ${bytes_written} 字节)"
                    else
                        echo "      ❌ 处理失败: '$filename'"
                    fi
                else
                    ((skipped_files++))
                    local size_mb=$((file_size / 1024 / 1024))
                    echo "      ⏭️  跳过: 文件大小 ${size_mb}MB < 100MB"
                fi
            else
                echo "      ⏭️  跳过: 非视频文件"
            fi
        done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
        
        # 递归处理子文件夹
        while IFS= read -r -d '' dir_path; do
            process_directory "$dir_path"
        done < <(find "$current_dir" -maxdepth 1 -type d ! -path "$current_dir" -print0 2>/dev/null)
        
        echo ""
    }
    
    # 开始处理根文件夹
    process_directory "$folderPath"
    
    # 输出统计信息
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 视频文件 V-L-T 标记处理完成!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 统计信息:"
    echo "   ├─ 总文件数:        $total_files"
    echo "   ├─ 视频文件数:      $video_files"
    echo "   ├─ 已处理文件数:    $processed_files"
    echo "   ├─ 跳过文件数:      $skipped_files"
    echo "   │  ├─ 已有标记:     $skipped_already_marked"
    echo "   │  └─ 不符合条件:   $((skipped_files - skipped_already_marked))"
    echo "   └─ 跳过文件夹数:    $skipped_folders"
    echo ""
    echo "💾 数据写入统计:"
    echo "   ├─ 总写入字节:      $total_bytes_written 字节"
    echo "   ├─ 平均每文件:      $((processed_files > 0 ? total_bytes_written / processed_files : 0)) 字节"
    echo "   └─ V-L-T 结构:     Value(NB) + Length(4B) + Type(100B)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}


# ============================================================================
# 使用示例
# ============================================================================
# processVideoFiles "/path/to/video/folder"





# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# ============================================================================
# 功能8：识别脚本默认追加的文件并移动到指定文件夹（V-L-T版本）
# 参数1: 文件夹路径
# 数据结构: [Value NB][Length 4B][Type 100B]
# ============================================================================
function moveProcessedFiles() {
    local folderPath="$1"
    local target_folder="/p2"
    
    # ========================================================================
    # 参数检查
    # ========================================================================
    if [ -z "$folderPath" ]; then
        echo "❌ 错误: 文件夹路径不能为空"
        echo "用法: moveProcessedFiles <文件夹路径>"
        return 1
    fi
    
    # 检查文件夹是否存在
    if [ ! -d "$folderPath" ]; then
        echo "❌ 错误: 文件夹 '$folderPath' 不存在"
        return 1
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 脚本处理文件识别与移动工具 (V-L-T版本)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 扫描文件夹: '$folderPath'"
    echo "🎯 目标文件夹: '$target_folder'"
    echo "🔍 识别条件: 文件末尾100字节为 'FKY996' 标志位"
    echo "📝 操作流程: 验证标志位 → 读取文件名 → 重命名 → 移动"
    echo "📋 数据格式: Value(NB) + Length(4B) + Type(100B)"
    echo ""
    echo "🔄 正在递归扫描文件..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 检查目标文件夹是否存在，不存在则创建
    if [ ! -d "$target_folder" ]; then
        echo "📁 目标文件夹不存在，正在创建: '$target_folder'"
        mkdir -p "$target_folder"
        if [ $? -eq 0 ]; then
            echo "   ✅ 成功创建目标文件夹"
        else
            echo "   ❌ 创建目标文件夹失败"
            return 1
        fi
        echo ""
    fi
    
    local total_files=0
    local processed_files=0
    local moved_files=0
    local failed_files=0
    
    # ========================================================================
    # 递归遍历文件夹中的所有文件
    # ========================================================================
    while IFS= read -r -d '' file_path; do
        ((total_files++))
        local filename=$(basename "$file_path")
        local relative_path="${file_path#$folderPath/}"
        
        # 显示当前处理的文件及其相对路径
        echo "🔍 检查文件: '$relative_path'"
        
        # 检查文件是否可读
        if [ ! -r "$file_path" ]; then
            echo "   ❌ 文件不可读，跳过"
            echo ""
            continue
        fi
        
        # 获取文件大小
        local file_size
        if command -v stat >/dev/null 2>&1; then
            file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
        else
            file_size=$(wc -c < "$file_path" 2>/dev/null)
        fi
        
        # 检查文件是否至少有104字节（V-L-T最小结构：Length(4B) + Type(100B)）
        if [ -z "$file_size" ] || [ "$file_size" -lt 104 ]; then
            echo "   ⏭️  跳过: 文件大小不足104字节 (当前: ${file_size:-0} 字节)"
            echo ""
            continue
        fi
        
        echo "   📏 文件大小: $file_size 字节"
        
        # ====================================================================
        # 步骤1：验证 Type 字段（末尾100字节）- V-L-T 核心优势！
        # ====================================================================
        echo "   📖 [步骤1/4] 验证 Type 字段 (末尾100字节)..."
        
        # 读取文件末尾100字节
        local mark=$(tail -c 100 "$file_path" 2>/dev/null | tr -d '\0' 2>/dev/null)
        
        if [ -z "$mark" ]; then
            echo "   ❌ 读取 Type 字段失败"
            echo ""
            continue
        fi
        
        # 显示标志位（用于调试）
        local debug_mark="${mark:0:20}"
        echo "      检测到标志位: '${debug_mark}...'"
        
        # 快速验证：如果不是 FKY996，立即跳过（不读取其他数据）
        if [ "$mark" != "FKY996" ]; then
            echo "   ⏭️  跳过: 非 V-L-T 格式文件 (标志位='$mark')"
            echo ""
            continue
        fi
        
        echo "      ✅ 标志位验证通过 (FKY996)"
        ((processed_files++))
        
        # ====================================================================
        # 步骤2：读取 Length 字段（倒数101-104字节）
        # ====================================================================
        echo "   📖 [步骤2/4] 读取 Length 字段..."
        
        # 读取末尾104字节，提取前4字节作为 Length
        local length_hex=$(tail -c 104 "$file_path" 2>/dev/null | head -c 4 2>/dev/null | xxd -p 2>/dev/null | tr -d '\n')
        
        if [ -z "$length_hex" ]; then
            echo "   ❌ 读取 Length 字段失败"
            ((failed_files++))
            echo ""
            continue
        fi
        
        # 将十六进制转换为十进制
        local name_length=$((16#$length_hex))
        
        echo "      文件名长度: $name_length 字节"
        
        # 长度合理性检查
        local total_vlt_size=$((name_length + 4 + 100))
        if [ $name_length -lt 0 ] || [ $file_size -lt $total_vlt_size ]; then
            echo "   ❌ 长度字段异常 ($name_length 字节)，数据损坏"
            echo "      VLT总大小: $total_vlt_size, 文件大小: $file_size"
            ((failed_files++))
            echo ""
            continue
        fi
        
        echo "      ✅ Length 字段有效"
        
        # ====================================================================
        # 步骤3：读取 Value 字段（文件名）
        # ====================================================================
        echo "   📖 [步骤3/4] 读取 Value 字段 ($name_length 字节)..."
        
        echo "      VLT 总大小: $total_vlt_size 字节"
        echo "      ├─ Value:  $name_length 字节"
        echo "      ├─ Length: 4 字节"
        echo "      └─ Type:   100 字节"
        
        # 读取完整的 V-L-T 块，提取前 name_length 字节（Value）
        local new_name_string=$(tail -c $total_vlt_size "$file_path" 2>/dev/null | head -c $name_length 2>/dev/null)
        
        if [ -z "$new_name_string" ]; then
            ((failed_files++))
            echo "   ❌ 提取文件名失败：文件名为空"
            echo ""
            continue
        fi
        
        echo "      🏷️  提取到的文件名: '$new_name_string'"
        echo "      ✅ Value 字段读取成功"
        
        # ====================================================================
        # 步骤4：重命名文件（如果需要）
        # ====================================================================
        echo "   📝 [步骤4/4] 重命名并移动文件..."
        
        local file_dir=$(dirname "$file_path")
        local temp_new_path="$file_dir/$new_name_string"
        
        # 检查新文件名是否与原文件名相同
        if [ "$filename" = "$new_name_string" ]; then
            echo "      ℹ️  文件名无需更改，直接移动"
            temp_new_path="$file_path"
        else
            # 需要重命名
            echo "      📝 重命名: '$filename' → '$new_name_string'"
            if mv "$file_path" "$temp_new_path" 2>/dev/null; then
                echo "      ✅ 成功重命名文件"
            else
                ((failed_files++))
                echo "   ❌ 重命名文件失败"
                echo ""
                continue
            fi
        fi
        
        # ====================================================================
        # 步骤5：移动文件到目标文件夹
        # ====================================================================
        local final_target_path="$target_folder/$new_name_string"
        
        # 检查目标位置是否已有同名文件
        if [ -f "$final_target_path" ]; then
            echo "      ⚠️  目标位置已存在同名文件，添加时间戳后缀"
            local timestamp=$(date +"%Y%m%d_%H%M%S_%N" 2>/dev/null || date +"%Y%m%d_%H%M%S")
            local name_without_ext="${new_name_string%.*}"
            local ext="${new_name_string##*.}"
            
            if [ "$name_without_ext" = "$new_name_string" ]; then
                # 没有扩展名
                final_target_path="$target_folder/${new_name_string}_${timestamp}"
            else
                # 有扩展名
                final_target_path="$target_folder/${name_without_ext}_${timestamp}.${ext}"
            fi
            
            echo "         新文件名: '$(basename "$final_target_path")'"
        fi
        
        echo "      📦 移动到: '$(basename "$final_target_path")'"
        if mv "$temp_new_path" "$final_target_path" 2>/dev/null; then
            ((moved_files++))
            echo "   🎉 成功移动文件"
        else
            ((failed_files++))
            echo "   ❌ 移动文件失败"
            
            # 如果重命名了但移动失败，尝试恢复原文件名
            if [ "$temp_new_path" != "$file_path" ] && [ -f "$temp_new_path" ]; then
                echo "      🔄 尝试恢复原文件名"
                mv "$temp_new_path" "$file_path" 2>/dev/null
            fi
        fi
        
        echo ""
        
    done < <(find "$folderPath" -type f -print0 2>/dev/null)
    
    # ========================================================================
    # 输出统计信息
    # ========================================================================
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 文件移动处理完成!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 统计信息:"
    echo "   ├─ 总文件数:             $total_files"
    echo "   ├─ 识别到的处理文件数:   $processed_files"
    echo "   ├─ 成功移动文件数:       $moved_files"
    echo "   ├─ 失败文件数:           $failed_files"
    echo "   └─ 目标文件夹:           '$target_folder'"
    echo ""
    echo "✅ 所有符合 V-L-T 格式的文件已处理完毕"
    echo "📋 数据结构: Value(NB) + Length(4B) + Type(100B)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}


# ============================================================================
# 使用示例
# ============================================================================
# moveProcessedFiles "/path/to/source/folder"


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>





# 功能9：查看文件末尾1100字节的原始文件名（不删除数据）
# 参数1: 文件路径
# 返回: 读取到的内容字符串（通过echo输出）
function view_original_names() {
    local file_path="$1"
    
    # 检查参数
    if [ -z "$file_path" ]; then
        echo "❌ 错误: 文件路径不能为空" >&2
        echo "用法: view_original_names <文件路径>" >&2
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
    
    echo "🔍 开始查看文件末尾的原始文件名信息" >&2
    echo "📁 文件路径: '$file_path'" >&2
    echo "📏 文件大小: $file_size 字节" >&2
    echo "" >&2
    
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
    
    # 将100字节标志位还原为字符串（去除null字符）
    local mark_string=$(cat "$mark_temp_file" | tr -d '\0')
    
    # 验证标志位
    echo "🔍 标志位验证:" >&2
    echo "   检测到的标志位: '$mark_string'" >&2
    echo "   期望的标志位: 'FKY996'" >&2
    
    if [ "$mark_string" != "FKY996" ]; then
        echo "   ❌ 失败 (检测到: '$mark_string'，期望: 'FKY996')" >&2
        echo "❌ 错误: 文件非通过本脚本追加写入生成的文件" >&2
        
        # 清理临时文件
        rm -f "$temp_file" "$mark_temp_file" "$content_temp_file"
        return 1
    fi
    
    echo "   ✅ 成功" >&2
    
    # 将1000字节内容数据还原为字符串（去除null字符）
    local content_string=$(cat "$content_temp_file" | tr -d '\0')
    
    # 清理临时文件
    rm -f "$temp_file" "$mark_temp_file" "$content_temp_file"
    
    echo "" >&2
    echo "📋 读取结果:" >&2
    echo "🏷️  标志位: '$mark_string' ✅" >&2
    echo "📝 原始文件名: '$content_string'" >&2
    echo "📊 数据结构: 100字节标志位 + 1000字节内容" >&2
    echo "" >&2
    
    # 返回读取到的内容字符串
    echo "$content_string"
    return 0
}

# 功能10：批量查看文件夹中文件的原始文件名
# 参数1: 文件路径列表字符串 (如 "/Users/cc/Desktop/test/oppp/v{1..40}" 或 "/v30")
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
    echo "📖 操作: 读取文件末尾1100字节获取原始文件名（不删除数据）"
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
                    sed 's/^/         /' "$error_temp_file"
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


# 主程序
write_fixed_bytes_main() {
    echo "🛠️  请选择功能："
    echo "1) 读取文件末尾1100字节数据并移除 (验证标志位)"
    echo "2) 批量还原文件名（从文件末尾读取并重命名）"
    echo "3) 批量处理视频文件（递归扫描，追加文件名）"
    echo "4) 识别并移动脚本处理过的文件"
    echo "5) 查看单个文件（纯查看，不修改）"
    echo "6) 功能10：批量查看文件夹中文件的原始文件名（纯查看，不修改）"
    

    echo "0) 退出"
    
    read -p "请输入对应序号: " choice
    
    case $choice in
        1)
            echo ""
            echo "📖 功能: 读取末尾1100字节数据 (验证标志位并提取内容)"
            read -p "请输入文件路径: " source_file
            echo ""
            read_and_remove_fixed_bytes "$source_file"
            ;;
        2)
            echo ""
            echo "🔄 功能: 批量还原文件名"
            echo "支持格式:"
            echo "  - 单个文件夹: /v30"
            echo "  - 多个文件夹: '/v{1..40}' (注意加引号)"
            echo "  - 完整路径: '/Users/cc/Desktop/test/oppp/v{1..40}'"
            echo "  - 多个文件夹: '/path1 /path2 /path3'"
            read -p "请输入文件夹路径列表: " folder_list
            echo ""
            restore_file_names "$folder_list"
            ;;
        3)
            echo ""
            echo "🎬 功能: 批量处理视频文件"
            echo "说明: 递归扫描指定文件夹，对大于100MB的视频文件追加文件名到末尾"
            read -p "请输入文件夹路径: " video_folder_path
            echo ""
            processVideoFiles "$video_folder_path"
            ;;
        4)
            echo ""
            echo "🔍 功能: 识别并移动脚本处理过的文件"
            echo "说明: 递归扫描指定文件夹，识别包含脚本标志位的文件，重命名并移动到/p2文件夹"
            read -p "请输入文件夹路径: " folder_path
            echo ""
            moveProcessedFiles "$folder_path"
            ;;
        5)
            echo ""
            echo "👀 功能: 查看单个文件（纯查看，不修改）"
            echo "说明: 查看单个文件（纯查看，不修改）（纯查看，不做任何修改）"
            read -p "请输入文件路径: " folder_path
            echo ""
            view_original_names "$folder_path"
            ;;
        6)
            echo ""
            echo "👀 功能: 批量查看文件夹中文件的原始文件名"
            echo "说明: 递归遍历文件夹，查看所有文件的原始名称（纯查看，不做任何修改）"
            read -p "请输入文件夹路径: " folder_path
            echo ""
            batch_view_original_names "$folder_path"
            ;;
        0)
            echo "👋 再见!"
            exit 0
            ;;
        *)
            echo "❌ 无效选择，请重新运行脚本"
            exit 1
            ;;
    esac
    
    
}


#========================================================================================================================
# DDDDD END>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#========================================================================================================================


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






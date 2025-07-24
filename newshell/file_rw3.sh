#!/bin/bash

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

# 功能5：获取一个带序号的文件名
# 返回: 生成的文件名（通过echo输出）
function getFileName() {
    # 文件前缀
    local filePrefix="fgg"
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

# 功能7：给视频文件末尾追加1100字节信息
# 参数1: 文件夹路径
function processVideoFiles() {
    local folderPath="$1"
    
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
    
    echo "🎬 开始处理视频文件，文件夹路径: '$folderPath'"
    echo "📏 条件: 视频文件且大小 > 100MB"
    echo "🔄 正在递归扫描文件..."
    echo ""
    
    local total_files=0
    local video_files=0
    local processed_files=0
    local skipped_files=0
    local min_size_bytes=$((100 * 1024 * 1024))  # 100MB in bytes
    
    # 递归遍历文件夹中的所有文件
    while IFS= read -r -d '' file_path; do
        ((total_files++))
        local filename=$(basename "$file_path")
        local file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
        
        # 显示当前处理的文件
        echo "🔍 检查文件: '$filename'"
        
        # 检查是否为视频文件
        if isVideoFileFunction "$file_path"; then
            ((video_files++))
            echo "   ✅ 识别为视频文件"
            
            # 检查文件大小
            if [ -n "$file_size" ] && [ "$file_size" -gt "$min_size_bytes" ]; then
                local size_mb=$((file_size / 1024 / 1024))
                echo "   📏 文件大小: ${size_mb}MB (符合条件)"
                echo "   📝 开始追加文件名到末尾..."
                
                # 调用write_fixed_bytes函数
                if write_fixed_bytes "$filename" "$file_path"; then
                    ((processed_files++))
                    echo "   🎉 成功处理: '$filename'"
                else
                    echo "   ❌ 处理失败: '$filename'"
                fi
            else
                ((skipped_files++))
                local size_mb=$((file_size / 1024 / 1024))
                echo "   ⏭️  跳过: 文件大小 ${size_mb}MB < 100MB"
            fi
        else
            echo "   ⏭️  跳过: 非视频文件"
        fi
        
        echo ""
        
    done < <(find "$folderPath" -type f -print0 2>/dev/null)
    
    echo "🎉 视频文件处理完成!"
    echo "📊 统计信息:"
    echo "   - 总文件数: $total_files"
    echo "   - 视频文件数: $video_files"
    echo "   - 已处理文件数: $processed_files"
    echo "   - 跳过文件数: $skipped_files"
    echo ""
}


# 主程序
main() {
    echo "🛠️  请选择功能："
    echo "1) 向文件末尾写入固定1100字节数据 (100字节标志位 + 1000字节内容)"
    echo "2) 读取文件末尾1100字节数据并移除 (验证标志位)"
    echo "3) 批量处理文件夹中的文件（追加文件名到末尾）"
    echo "4) 批量还原文件名（从文件末尾读取并重命名）"
    echo "5) 生成带序号的文件名"
    echo "6) 检测文件是否为视频文件"
    echo "7) 批量处理视频文件（递归扫描，追加文件名）"
    echo "8) 退出"
    
    read -p "请输入选择 (1-8): " choice
    
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
            echo ""
            echo "🔢 功能5: 生成带序号的文件名"
            echo ""
            filename=$(getFileName)
            if [ $? -eq 0 ]; then
                echo ""
                echo "🎉 成功生成文件名: '$filename'"
                echo "💡 提示: 可以在其他脚本中调用此函数获取唯一的文件名"
            else
                echo ""
                echo "❌ 生成文件名失败"
            fi
            ;;
        6)
            echo ""
            echo "🎬 功能6: 检测文件是否为视频文件"
            read -p "请输入文件路径: " test_file_path
            echo ""
            if isVideoFileFunction "$test_file_path"; then
                echo "✅ '$test_file_path' 是视频文件"
                # 显示文件信息
                if [ -f "$test_file_path" ]; then
                    local file_size=$(stat -c%s "$test_file_path" 2>/dev/null || stat -f%z "$test_file_path" 2>/dev/null)
                    if [ -n "$file_size" ]; then
                        local size_mb=$((file_size / 1024 / 1024))
                        echo "📏 文件大小: ${size_mb}MB"
                    fi
                fi
            else
                echo "❌ '$test_file_path' 不是视频文件"
            fi
            ;;
        7)
            echo ""
            echo "🎬 功能7: 批量处理视频文件"
            echo "说明: 递归扫描指定文件夹，对大于100MB的视频文件追加文件名到末尾"
            read -p "请输入文件夹路径: " video_folder_path
            echo ""
            processVideoFiles "$video_folder_path"
            ;;
        8)
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
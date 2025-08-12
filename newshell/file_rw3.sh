#!/bin/bash

# 通用路径列表解析函数
function parse_path_list() {
    local file_path_list_string="$1"
    local -n result_array=$2  # 使用nameref传递数组引用
    
    result_array=()  # 清空结果数组
    
    # 处理大括号扩展
    if [[ "$file_path_list_string" == *"{"*".."*"}"* ]]; then
        echo "🔧 检测到大括号语法，手动展开路径..." >&2
        
        # 提取大括号内容
        if [[ "$file_path_list_string" =~ \{([0-9]+)\.\.([0-9]+)\} ]]; then
            local start_num="${BASH_REMATCH[1]}"
            local end_num="${BASH_REMATCH[2]}"
            local base_path="${file_path_list_string%\{*\}*}"  # 获取大括号前的部分
            local suffix_path="${file_path_list_string#*\}}"   # 获取大括号后的部分
            
            # 重新构建路径数组
            for ((i=start_num; i<=end_num; i++)); do
                result_array+=("${base_path}${i}${suffix_path}")
            done
            
            echo "   ✅ 成功展开为 ${#result_array[@]} 个路径 (${base_path}${start_num}${suffix_path} 到 ${base_path}${end_num}${suffix_path})" >&2
        fi
    else
        # 处理路径列表 - 支持引号和换行分隔
        echo "🔧 解析路径列表..." >&2
        
        # 首先尝试按换行分割
        if [[ "$file_path_list_string" == *$'\n'* ]]; then
            echo "   检测到换行符，按行分割路径" >&2
            while IFS= read -r line; do
                line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')  # 去除前后空格
                if [ -n "$line" ]; then
                    result_array+=("$line")
                fi
            done <<< "$file_path_list_string"
        else
            # 按空格分割，但正确处理引号
            echo "   按空格分割路径，支持引号包围" >&2
            
            # 使用eval和printf来正确处理引号
            local temp_file=$(mktemp)
            printf '%s\n' "$file_path_list_string" > "$temp_file"
            
            # 使用bash的read内建命令正确解析引号
            local current_path=""
            local in_quotes=false
            local quote_char=""
            local i=0
            
            while [ $i -lt ${#file_path_list_string} ]; do
                local char="${file_path_list_string:$i:1}"
                
                if [ "$in_quotes" = false ]; then
                    if [ "$char" = '"' ] || [ "$char" = "'" ]; then
                        in_quotes=true
                        quote_char="$char"
                    elif [ "$char" = ' ' ] || [ "$char" = $'\t' ]; then
                        # 空格或制表符，结束当前路径
                        if [ -n "$current_path" ]; then
                            result_array+=("$current_path")
                            current_path=""
                        fi
                    else
                        current_path="${current_path}${char}"
                    fi
                else
                    if [ "$char" = "$quote_char" ]; then
                        in_quotes=false
                        quote_char=""
                    else
                        current_path="${current_path}${char}"
                    fi
                fi
                
                ((i++))
            done
            
            # 添加最后一个路径
            if [ -n "$current_path" ]; then
                result_array+=("$current_path")
            fi
            
            rm -f "$temp_file"
        fi
        
        # 去除空元素
        local temp_array=()
        for path in "${result_array[@]}"; do
            if [ -n "$path" ]; then
                temp_array+=("$path")
            fi
        done
        result_array=("${temp_array[@]}")
        
        echo "   ✅ 成功解析为 ${#result_array[@]} 个路径" >&2
    fi
}

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

# 功能3：遍历文件夹并处理文件 - 优化版（修复路径解析问题）
function process_folders() {
    local file_path_list_string="$1"
    local file_suffix_string="tmpfile"
    
    # 检查参数
    if [ -z "$file_path_list_string" ]; then
        echo "❌ 错误: 文件路径列表不能为空"
        echo "用法: process_folders <文件路径列表>"
        echo "示例: process_folders \"/Users/cc/Desktop/test/oppp/v{1..40}\""
        echo "      process_folders \"/v30\""
        echo "      process_folders \"/path/with spaces\" \"/another/path\""
        echo "      process_folders $'/path1\\n/path2\\n/path with spaces'"
        return 1
    fi
    
    echo "🔍 开始处理文件夹列表: $file_path_list_string"
    echo "🚫 跳过条件: 存在后缀为 '$file_suffix_string' 的文件"
    echo ""
    
    # 使用新的路径解析函数
    local path_array=()
    parse_path_list "$file_path_list_string" path_array
    
    local processed_count=0
    local skipped_count=0
    
    # 遍历每个路径
    for path in "${path_array[@]}"; do
        echo "📁 处理文件夹: '$path'"
        
        # 检查文件夹是否存在
        if [ ! -d "$path" ]; then
            echo "   ⚠️  警告: 文件夹 '$path' 不存在，跳过"
            echo ""
            continue
        fi
        
        # 使用while read循环安全处理包含空格和特殊字符的文件名
        local has_tmp_file=false
        local files_processed=0
        local files_deleted=0
        
        # 第一遍：检查是否存在以指定后缀结尾的文件
        while IFS= read -r -d '' file_path; do
            local filename
            filename=$(basename "$file_path")
            if [[ "$filename" == *"$file_suffix_string" ]]; then
                has_tmp_file=true
                echo "   🚫 发现后缀文件: '$filename'，跳过此文件夹"
                break
            fi
        done < <(find "$path" -maxdepth 1 -type f -print0 2>/dev/null)
        
        if [ "$has_tmp_file" = true ]; then
            ((skipped_count++))
            echo ""
            continue
        fi
        
        # 检查文件夹是否为空
        local file_count
        file_count=$(find "$path" -maxdepth 1 -type f 2>/dev/null | wc -l)
        if [ "$file_count" -eq 0 ]; then
            echo "   📝 文件夹为空，跳过"
            echo ""
            continue
        fi
        
        # 第二遍：处理文件夹中的文件
        echo "   ✅ 开始处理文件夹中的文件"
        
        while IFS= read -r -d '' file_path; do
            local filename
            filename=$(basename "$file_path")
            
            # 调试信息：显示正在处理的文件
            echo "   🔍 处理文件: '$filename'"
            
            if [ "$filename" = "url" ]; then
                echo "   🗑️  删除文件: '$file_path'"
                if rm -f "$file_path"; then
                    ((files_deleted++))
                    echo "   ✅ 成功删除: '$file_path'"
                else
                    echo "   ❌ 删除失败: '$file_path'"
                fi
            else
                echo "   📝 使用write_fixed_bytes给文件 '$file_path' 末尾追加文件名 '$filename'"
                write_fixed_bytes "$filename" "$file_path"
                if [ $? -eq 0 ]; then
                    ((files_processed++))
                else
                    echo "   ❌ 追加数据失败: '$file_path'"
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

# 功能4：遍历文件夹并还原文件名（与功能3相反）- 优化版（修复路径解析问题）
function restore_file_names() {
    local file_path_list_string="$1"
    
    # 检查参数
    if [ -z "$file_path_list_string" ]; then
        echo "❌ 错误: 文件路径列表不能为空"
        echo "用法: restore_file_names <文件路径列表>"
        echo "示例: restore_file_names \"/Users/cc/Desktop/test/oppp/v{1..40}\""
        echo "      restore_file_names \"/v30\""
        echo "      restore_file_names \"/path/with spaces\" \"/another/path\""
        echo "      restore_file_names $'/path1\\n/path2\\n/path with spaces'"
        return 1
    fi
    
    echo "🔄 开始还原文件名，处理文件夹列表: $file_path_list_string"
    echo "📖 操作: 读取文件末尾1100字节作为新文件名"
    echo ""
    
    # 使用新的路径解析函数
    local path_array=()
    parse_path_list "$file_path_list_string" path_array
    
    local processed_count=0
    
    # 遍历每个路径
    for path in "${path_array[@]}"; do
        echo "📁 处理文件夹: '$path'"
        
        # 检查文件夹是否存在
        if [ ! -d "$path" ]; then
            echo "   ⚠️  警告: 文件夹 '$path' 不存在，跳过"
            echo ""
            continue
        fi
        
        # 检查文件夹是否为空
        local file_count
        file_count=$(find "$path" -maxdepth 1 -type f 2>/dev/null | wc -l)
        if [ "$file_count" -eq 0 ]; then
            echo "   📝 文件夹为空，跳过"
            echo ""
            continue
        fi
        
        # 处理文件夹中的文件
        echo "   ✅ 开始还原文件夹中的文件名"
        local files_processed=0
        local files_failed=0
        
        # 使用while read循环安全处理包含空格和特殊字符的文件名
        while IFS= read -r -d '' file_path; do
            local original_filename
            original_filename=$(basename "$file_path")
            local file_dir
            file_dir=$(dirname "$file_path")
            
            # 调试信息：显示正在处理的文件
            echo "   🔍 处理文件: '$original_filename'"
            
            # 调用功能2读取末尾1100字节并获取字符串
            local get_name_string
            local error_temp_file
            error_temp_file=$(mktemp)
            get_name_string=$(read_and_remove_fixed_bytes "$file_path" 2>"$error_temp_file")
            local read_result=$?
            
            if [ $read_result -eq 0 ] && [ -n "$get_name_string" ]; then
                # 构建新文件路径
                local new_file_path="$file_dir/$get_name_string"
                
                echo "   📝 还原文件名: '$original_filename' -> '$get_name_string'"
                
                # 检查目标文件是否已存在
                if [ -f "$new_file_path" ] && [ "$file_path" != "$new_file_path" ]; then
                    echo "   ⚠️  警告: 目标文件 '$get_name_string' 已存在，添加时间戳后缀"
                    local timestamp
                    timestamp=$(date +"%Y%m%d_%H%M%S")
                    new_file_path="$file_dir/${get_name_string}_${timestamp}"
                fi
                
                # 重命名文件
                if mv "$file_path" "$new_file_path"; then
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
    local indexFile="/Users/codew/Desktop/indexFXY"
    
    echo "🔢 开始生成文件名..." >&2
    
    # 检查索引文件是否存在，不存在则创建并初始化为1
    if [ ! -f "$indexFile" ]; then
        echo "📝 索引文件不存在，创建并初始化: '$indexFile'" >&2
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
        echo "❌ 错误: 无法读取索引文件 '$indexFile'" >&2
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
    local file_suffix_string_allLowercase
    file_suffix_string_allLowercase=$(echo "$file_suffix_string" | tr '[:upper:]' '[:lower:]')
    
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

# 功能7：给视频文件末尾追加1100字节信息 - 优化版
# 参数1: 文件夹路径
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
    
    echo "🎬 开始处理视频文件，文件夹路径: '$folderPath'"
    echo "📏 条件: 视频文件且大小 > 100MB"
    echo "🚫 跳过条件: 存在后缀为 '$file_suffix_string' 的文件"
    echo "🔄 正在递归扫描文件..."
    echo ""
    
    local total_files=0
    local video_files=0
    local processed_files=0
    local skipped_files=0
    local skipped_folders=0
    local min_size_bytes=$((100 * 1024 * 1024))  # 100MB in bytes
    
    # 递归处理文件夹的内部函数
    function process_directory() {
        local current_dir="$1"
        local relative_path="${current_dir#$folderPath}"
        [ -z "$relative_path" ] && relative_path="/"
        
        local current_dirname
        current_dirname=$(basename "$current_dir")
        echo "📁 进入文件夹: '$current_dirname' $relative_path"
        
        # 检查当前文件夹是否存在以file_suffix_string为后缀的文件
        local has_tmp_file=false
        while IFS= read -r -d '' file_path; do
            local filename
            filename=$(basename "$file_path")
            if [[ "$filename" == *"$file_suffix_string" ]]; then
                has_tmp_file=true
                echo "   🚫 发现后缀文件: '$filename'，跳过此文件夹及其子文件夹"
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
            local filename
            filename=$(basename "$file_path")
            local file_size
            file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
            
            # 显示当前处理的文件
            echo "   🔍 检查文件: '$filename'"
            
            # 检查是否为视频文件
            if isVideoFileFunction "$file_path"; then
                ((video_files++))
                echo "      ✅ 识别为视频文件"
                
                # 检查文件大小
                if [ -n "$file_size" ] && [ "$file_size" -gt "$min_size_bytes" ]; then
                    local size_mb=$((file_size / 1024 / 1024))
                    echo "      📏 文件大小: ${size_mb}MB (符合条件)"
                    echo "      📝 开始追加文件名到末尾..."
                    
                    # 调用write_fixed_bytes函数
                    if write_fixed_bytes "$filename" "$file_path"; then
                        ((processed_files++))
                        echo "      🎉 成功处理: '$filename'"
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
    
    echo "🎉 视频文件处理完成!"
    echo "📊 统计信息:"
    echo "   - 总文件数: $total_files"
    echo "   - 视频文件数: $video_files"
    echo "   - 已处理文件数: $processed_files"
    echo "   - 跳过文件数: $skipped_files"
    echo "   - 跳过文件夹数: $skipped_folders"
    echo ""
}

# 功能8：识别脚本默认追加的文件并移动到指定文件夹 - 优化版
# 参数1: 文件夹路径
function moveProcessedFiles() {
    local folderPath="$1"
    local target_folder="/p2"
    
    # 检查参数
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
    
    echo "🔍 开始识别并移动脚本处理过的文件"
    echo "📁 扫描文件夹: '$folderPath'"
    echo "🎯 目标文件夹: '$target_folder'"
    echo "🔄 正在递归扫描文件..."
    echo ""
    
    # 检查目标文件夹是否存在，不存在则创建
    if [ ! -d "$target_folder" ]; then
        echo "📝 目标文件夹不存在，正在创建: '$target_folder'"
        if mkdir -p "$target_folder"; then
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
    
    # 递归遍历文件夹中的所有文件
    while IFS= read -r -d '' file_path; do
        ((total_files++))
        local filename
        filename=$(basename "$file_path")
        local relative_path="${file_path#$folderPath/}"
        
        # 显示当前处理的文件及其相对路径
        echo "🔍 检查文件: '$relative_path'"
        
        # 检查文件是否可读
        if [ ! -r "$file_path" ]; then
            echo "   ❌ 文件不可读，跳过"
            echo ""
            continue
        fi
        
        # 获取文件大小 - 使用更可靠的方法
        local file_size
        if command -v stat >/dev/null 2>&1; then
            # 优先使用stat命令（支持Linux和macOS）
            file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
        else
            # 备用方法
            file_size=$(wc -c < "$file_path" 2>/dev/null)
        fi
        
        # 检查文件是否至少有1100字节
        if [ -z "$file_size" ] || [ "$file_size" -lt 1100 ]; then
            echo "   ⏭️  跳过: 文件大小不足1100字节 (当前: ${file_size:-0} 字节)"
            echo ""
            continue
        fi
        
        echo "   📏 文件大小: $file_size 字节"
        
        # 创建临时文件
        local temp_file
        temp_file=$(mktemp)
        local mark_temp_file
        mark_temp_file=$(mktemp)
        
        # 确保临时文件创建成功
        if [ -z "$temp_file" ] || [ -z "$mark_temp_file" ] || [ ! -f "$temp_file" ] || [ ! -f "$mark_temp_file" ]; then
            echo "   ❌ 创建临时文件失败"
            rm -f "$temp_file" "$mark_temp_file" 2>/dev/null
            echo ""
            continue
        fi
        
        # 读取文件末尾1100字节
        if ! tail -c 1100 "$file_path" > "$temp_file" 2>/dev/null; then
            echo "   ❌ 读取文件末尾数据失败"
            rm -f "$temp_file" "$mark_temp_file"
            echo ""
            continue
        fi
        
        # 检查提取的数据大小
        local extracted_size
        extracted_size=$(wc -c < "$temp_file" 2>/dev/null)
        if [ -z "$extracted_size" ] || [ "$extracted_size" -lt 100 ]; then
            echo "   ❌ 提取的数据不足100字节"
            rm -f "$temp_file" "$mark_temp_file"
            echo ""
            continue
        fi
        
        # 提取前100字节作为标志位
        if ! dd if="$temp_file" of="$mark_temp_file" bs=1 count=100 2>/dev/null; then
            echo "   ❌ 提取标志位失败"
            rm -f "$temp_file" "$mark_temp_file"
            echo ""
            continue
        fi
        
        # 将标志位转换为字符串 - 更安全的方法
        local mark_string
        mark_string=$(cat "$mark_temp_file" 2>/dev/null | tr -d '\0' | head -c 100)
        
        # 调试信息：显示标志位内容（前20个字符）
        local debug_mark="${mark_string:0:20}"
        echo "   🔍 检测到标志位: '${debug_mark}...'"
        
        # 验证标志位
        if [ "$mark_string" = "FKY996" ]; then
            ((processed_files++))
            echo "   ✅ 检测到脚本处理标志: '$mark_string'"
            
            # 调用getFileName获取新文件名
            local new_name_string
            new_name_string=$(getFileName 2>/dev/null)
            local get_name_result=$?
            
            if [ $get_name_result -eq 0 ] && [ -n "$new_name_string" ]; then
                echo "   🏷️  生成新文件名: '$new_name_string'"
                
                local file_dir
                file_dir=$(dirname "$file_path")
                local temp_new_path="$file_dir/$new_name_string"
                
                # 检查新文件名是否与原文件名相同
                if [ "$filename" = "$new_name_string" ]; then
                    echo "   ℹ️  文件名无需更改，直接移动"
                    temp_new_path="$file_path"
                else
                    # 第一步：重命名文件
                    echo "   📝 重命名文件: '$filename' -> '$new_name_string'"
                    if mv "$file_path" "$temp_new_path"; then
                        echo "   ✅ 成功重命名文件"
                    else
                        ((failed_files++))
                        echo "   ❌ 重命名文件失败"
                        rm -f "$temp_file" "$mark_temp_file"
                        echo ""
                        continue
                    fi
                fi
                
                # 第二步：移动文件到目标文件夹
                local final_target_path="$target_folder/$new_name_string"
                
                # 检查目标位置是否已有同名文件
                if [ -f "$final_target_path" ]; then
                    echo "   ⚠️  目标位置已存在同名文件，添加时间戳后缀"
                    local timestamp
                    timestamp=$(date +"%Y%m%d_%H%M%S_%N" 2>/dev/null || date +"%Y%m%d_%H%M%S")
                    local name_without_ext="${new_name_string%.*}"
                    local ext="${new_name_string##*.}"
                    if [ "$name_without_ext" = "$new_name_string" ]; then
                        # 没有扩展名
                        final_target_path="$target_folder/${new_name_string}_${timestamp}"
                    else
                        # 有扩展名
                        final_target_path="$target_folder/${name_without_ext}_${timestamp}.${ext}"
                    fi
                fi
                
                local final_target_basename
                final_target_basename=$(basename "$final_target_path")
                echo "   📦 移动文件到: '$final_target_basename'"
                if mv "$temp_new_path" "$final_target_path"; then
                    ((moved_files++))
                    echo "   🎉 成功移动文件"
                else
                    ((failed_files++))
                    echo "   ❌ 移动文件失败"
                    # 如果重命名了但移动失败，尝试恢复原文件名
                    if [ "$temp_new_path" != "$file_path" ]; then
                        echo "   🔄 尝试恢复原文件名"
                        mv "$temp_new_path" "$file_path" 2>/dev/null
                    fi
                fi
            else
                ((failed_files++))
                echo "   ❌ 生成新文件名失败 (返回码: $get_name_result)"
            fi
        else
            echo "   ⏭️  跳过: 非脚本处理文件"
        fi
        
        # 清理临时文件
        rm -f "$temp_file" "$mark_temp_file"
        echo ""
        
    done < <(find "$folderPath" -type f -print0 2>/dev/null)
    
    echo "🎉 文件移动处理完成!"
    echo "📊 统计信息:"
    echo "   - 总文件数: $total_files"
    echo "   - 识别到的处理文件数: $processed_files"
    echo "   - 成功移动文件数: $moved_files"
    echo "   - 失败文件数: $failed_files"
    echo "   - 目标文件夹: '$target_folder'"
    echo ""
}

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
    local file_size
    file_size=$(wc -c < "$file_path")
    
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
    local temp_file
    temp_file=$(mktemp)
    tail -c 1100 "$file_path" > "$temp_file"
    
    # 使用dd分离前100字节（标志位）和后1000字节（内容数据）
    local mark_temp_file
    mark_temp_file=$(mktemp)
    local content_temp_file
    content_temp_file=$(mktemp)
    
    # 读取前100字节（标志位）
    dd if="$temp_file" of="$mark_temp_file" bs=1 count=100 2>/dev/null
    
    # 读取后1000字节（内容数据）
    dd if="$temp_file" of="$content_temp_file" bs=1 skip=100 count=1000 2>/dev/null
    
    # 将100字节标志位还原为字符串（去除null字符）
    local mark_string
    mark_string=$(cat "$mark_temp_file" | tr -d '\0')
    
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
    local content_string
    content_string=$(cat "$content_temp_file" | tr -d '\0')
    
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



# 功能10：批量查看文件夹中文件的原始文件名 - 优化版
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
    
    # 展开路径列表
    local path_array=()
    
    # 处理大括号扩展
    if [[ "$file_path_list_string" == *"{"*".."*"}"* ]]; then
        echo "🔧 检测到大括号语法，手动展开路径..."
        
        # 提取大括号内容
        if [[ "$file_path_list_string" =~ \{([0-9]+)\.\.([0-9]+)\} ]]; then
            local start_num="${BASH_REMATCH[1]}"
            local end_num="${BASH_REMATCH[2]}"
            local base_path="${file_path_list_string%\{*\}*}"  # 获取大括号前的部分
            local suffix_path="${file_path_list_string#*\}}"   # 获取大括号后的部分
            
            # 重新构建路径数组
            for ((i=start_num; i<=end_num; i++)); do
                path_array+=("${base_path}${i}${suffix_path}")
            done
            
            echo "   ✅ 成功展开为 ${#path_array[@]} 个路径 (${base_path}${start_num}${suffix_path} 到 ${base_path}${end_num}${suffix_path})"
        fi
    else
        # 处理空格分隔的路径列表，使用IFS正确分割
        IFS=' ' read -ra path_array <<< "$file_path_list_string"
        # 去除空元素
        local temp_array=()
        for path in "${path_array[@]}"; do
            if [ -n "$path" ]; then
                temp_array+=("$path")
            fi
        done
        path_array=("${temp_array[@]}")
    fi
    
    local processed_count=0
    local success_count=0
    local error_count=0
    
    # 遍历每个路径
    for path in "${path_array[@]}"; do
        echo "📁 处理文件夹: '$path'"
        
        # 检查文件夹是否存在
        if [ ! -d "$path" ]; then
            echo "   ⚠️  警告: 文件夹 '$path' 不存在，跳过"
            echo ""
            continue
        fi
        
        # 检查文件夹是否为空
        local file_count
        file_count=$(find "$path" -maxdepth 1 -type f 2>/dev/null | wc -l)
        if [ "$file_count" -eq 0 ]; then
            echo "   📝 文件夹为空，跳过"
            echo ""
            continue
        fi
        
        # 处理文件夹中的文件
        echo "   👁️  开始查看文件夹中的文件原始名称"
        local files_success=0
        local files_failed=0
        
        # 使用while read循环安全处理包含空格和特殊字符的文件名
        while IFS= read -r -d '' file_path; do
            local current_filename
            current_filename=$(basename "$file_path")
            
            # 调试信息：显示正在处理的文件
            echo "     🔍 查看文件: '$current_filename'"
            
            # 调用view_original_names函数查看原始文件名
            local original_name_string
            local error_temp_file
            error_temp_file=$(mktemp)
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
main() {
    echo "🛠️  请选择功能："
    echo "1) 向文件末尾写入固定1100字节数据 (100字节标志位 + 1000字节内容)"
    echo "2) 读取文件末尾1100字节数据并移除 (验证标志位)"
    echo "3) 批量处理文件夹中的文件（追加文件名到末尾）"
    echo "4) 批量还原文件名（从文件末尾读取并重命名）"
    echo "5) 生成带序号的文件名"
    echo "6) 检测文件是否为视频文件"
    echo "7) 批量处理视频文件（递归扫描，追加文件名）"
    echo "8) 识别并移动脚本处理过的文件"
    echo "9) 查看单个文件（纯查看，不修改）"
    echo "10) 功能10：批量查看文件夹中文件的原始文件名（纯查看，不修改）"
    

    echo "0) 退出"
    
    read -p "请输入选择 (1-9): " choice
    
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
            echo ""
            echo "🔍 功能8: 识别并移动脚本处理过的文件"
            echo "说明: 递归扫描指定文件夹，识别包含脚本标志位的文件，重命名并移动到/p2文件夹"
            read -p "请输入文件夹路径: " folder_path
            echo ""
            moveProcessedFiles "$folder_path"
            ;;
        9)
            echo ""
            echo "👀 功能9: 查看单个文件（纯查看，不修改）"
            echo "说明: 查看单个文件（纯查看，不修改）（纯查看，不做任何修改）"
            read -p "请输入文件路径: " folder_path
            echo ""
            view_original_names "$folder_path"
            ;; 
        10)
            echo ""
            echo "👀 功能10: 批量查看文件夹中文件的原始文件名"
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
    
    echo ""
    read -p "按回车键继续..."
    echo ""
    main  # 递归调用主菜单
}

# 脚本入口点
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
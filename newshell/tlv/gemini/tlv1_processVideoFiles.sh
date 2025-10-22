#!/bin/bash

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
# 功能6：根据文件后缀判断是否为视频文件（未修改）
# ============================================================================
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
    local length_hex=$(tail -c 104 "$file_path" | head -c 4 | xxd -p)
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


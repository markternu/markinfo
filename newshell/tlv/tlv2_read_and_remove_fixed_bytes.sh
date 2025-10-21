function read_and_remove_fixed_bytes() {
    local file_path="$1"
    
    # ========================================================================
    # 参数检查
    # ========================================================================
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
    
    # 检查文件是否至少有104字节（Type + Length的最小大小）
    if [ $file_size -lt 104 ]; then
        echo "❌ 错误: 文件大小不足104字节 (当前: $file_size 字节)" >&2
        echo "   TLV 最小结构需要: Type(100B) + Length(4B) = 104字节" >&2
        return 1
    fi
    
    echo "🔍 开始读取并移除文件末尾 TLV 数据: '$file_path'" >&2
    echo "" >&2
    
    # ========================================================================
    # 第一步：读取 Length 字段（获取文件名长度）
    # ========================================================================
    echo "📖 [步骤1/4] 读取 Length 字段..." >&2
    
    # 直接从文件读取末尾4字节作为 Length 字段
    # 使用 xxd 将二进制转换为十六进制字符串
    local length_hex=$(tail -c 4 "$file_path" | xxd -p)
    
    # 将十六进制转换为十进制
    local name_length=$((16#$length_hex))
    
    echo "   文件名长度: $name_length 字节" >&2
    
    # 长度合理性检查
    if [ $name_length -lt 0 ]; then
        echo "❌ 错误: 长度字段为负数 ($name_length)，数据损坏" >&2
        return 1
    fi
    
    if [ $name_length -gt $((file_size - 104)) ]; then
        echo "❌ 错误: 长度字段异常 ($name_length 字节)，超过文件剩余大小" >&2
        echo "   文件大小: $file_size 字节" >&2
        echo "   Type+Length: 104 字节" >&2
        echo "   剩余空间: $((file_size - 104)) 字节" >&2
        return 1
    fi
    
    echo "   ✅ 长度字段读取成功" >&2
    
    # ========================================================================
    # 第二步：读取 Type 字段（标志位验证）
    # ========================================================================
    echo "📖 [步骤2/4] 读取并验证 Type 字段..." >&2
    
    # 计算完整TLV块的大小（需要先有 name_length）
    local total_tlv_size=$((100 + 4 + name_length))
    
    # 从文件末尾读取完整TLV块，然后提取前100字节作为 Type 字段
    local mark=$(tail -c $total_tlv_size "$file_path" | head -c 100 | tr -d '\0')
    
    echo "   检测到的标志位: '$mark'" >&2
    echo "   期望的标志位: 'FKY996'" >&2
    
    # 验证标志位
    if [ "$mark" != "FKY996" ]; then
        echo "   ❌ 标志位不匹配" >&2
        echo "" >&2
        echo "❌ 错误: 文件非通过本脚本追加写入生成的文件" >&2
        echo "   无法通过本功能读取并切除文件末尾数据" >&2
        return 1
    fi
    
    echo "   ✅ 标志位验证通过" >&2
    
    # ========================================================================
    # 第三步：读取 Value 字段（文件名内容）
    # ========================================================================
    echo "📖 [步骤3/4] 读取 Value 字段 ($name_length 字节)..." >&2
    
    echo "   TLV 总大小: $total_tlv_size 字节" >&2
    echo "   ├─ Type:   100 字节" >&2
    echo "   ├─ Length: 4 字节" >&2
    echo "   └─ Value:  $name_length 字节" >&2
    
    # 直接从文件读取 Value 字段
    # 方法：读取末尾 total_tlv_size 字节，然后跳过前104字节
    local content_string=$(tail -c $total_tlv_size "$file_path" | dd bs=1 skip=104 2>/dev/null)
    
    echo "   ✅ 文件名读取成功" >&2
    
    # ========================================================================
    # 第四步：删除TLV数据（截断文件）
    # ========================================================================
    echo "🗑️  [步骤4/4] 移除 TLV 数据..." >&2
    
    # 计算新文件大小（移除末尾TLV数据）
    local new_size=$((file_size - total_tlv_size))
    
    echo "   文件大小变化:" >&2
    echo "   ├─ 原始大小: $file_size 字节" >&2
    echo "   ├─ 移除数据: $total_tlv_size 字节" >&2
    echo "   └─ 新大小:   $new_size 字节" >&2
    
    # 检查新大小是否合理
    if [ $new_size -lt 0 ]; then
        echo "❌ 错误: 计算出的新文件大小为负数，数据异常" >&2
        return 1
    fi
    
    # 创建临时文件
    local new_temp_file=$(mktemp)
    
    if [ -z "$new_temp_file" ] || [ ! -f "$new_temp_file" ]; then
        echo "❌ 错误: 无法创建临时文件" >&2
        return 1
    fi
    
    # 将原文件除了末尾TLV数据的部分复制到临时文件
    # head -c $new_size 读取前 new_size 字节
    if ! head -c $new_size "$file_path" > "$new_temp_file"; then
        echo "❌ 错误: 复制文件内容失败" >&2
        rm -f "$new_temp_file"
        return 1
    fi
    
    # 用临时文件替换原文件
    if ! mv "$new_temp_file" "$file_path"; then
        echo "❌ 错误: 替换文件失败" >&2
        rm -f "$new_temp_file"
        return 1
    fi
    
    echo "   ✅ TLV 数据已成功移除" >&2
    
    # ========================================================================
    # 完成输出
    # ========================================================================
    echo "" >&2
    echo "🎉 TLV 数据读取并移除完成!" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "📊 处理结果:" >&2
    echo "   ├─ 标志位验证: '$mark' ✅" >&2
    echo "   ├─ 读取文件名: '$content_string'" >&2
    echo "   ├─ 移除字节数: $total_tlv_size 字节" >&2
    echo "   ├─ 文件新大小: $(wc -c < "$file_path") 字节" >&2
    echo "   └─ 数据结构:   Type(100B) + Length(4B) + Value(${name_length}B)" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    
    # 将读取到的文件名内容输出到 stdout（供调用者获取）
    echo "$content_string"
    return 0
}

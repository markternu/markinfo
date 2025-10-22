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
    
    # 检查文件是否至少有104字节（Type + Length的最小大小）
    if [ $file_size -lt 104 ]; then
        echo "❌ 错误: 文件大小不足104字节 (当前: $file_size 字节)" >&2
        echo "   TLV 最小结构需要: Type(100B) + Length(4B) = 104字节" >&2
        return 1
    fi
    
    echo "🔍 开始查看文件末尾的原始文件名信息" >&2
    echo "📁 文件路径: '$file_path'" >&2
    echo "📏 文件大小: $file_size 字节" >&2
    echo "" >&2
    
    # ========================================================================
    # 第一步：读取 Length 字段（获取文件名长度）
    # ========================================================================
    # 使用 xxd 命令将文件末尾的 4 字节转换为十六进制
    local length_hex=$(tail -c 4 "$file_path" | xxd -p)
    local name_length=$((16#$length_hex))  # 十六进制转为十进制
    
    if [ $name_length -lt 0 ]; then
        echo "❌ 错误: 长度字段为负数 ($name_length)，数据损坏" >&2
        return 1
    fi
    
    # 检查长度字段的合理性
    if [ $name_length -gt $((file_size - 104)) ]; then
        echo "❌ 错误: 长度字段异常 ($name_length 字节)，超过文件剩余大小" >&2
        return 1
    fi
    
    echo "   文件名长度: $name_length 字节" >&2
    echo "   ✅ 长度字段读取成功" >&2
    
    # ========================================================================
    # 第二步：读取 Type 字段（标志位验证）
    # ========================================================================
    # 计算整个 TLV 数据的大小
    local total_tlv_size=$((100 + 4 + name_length))
    
    # 读取前 100 字节作为 Type 字段（标志位）
    local mark=$(tail -c $total_tlv_size "$file_path" | head -c 100 | tr -d '\0')
    
    echo "   检测到的标志位: '$mark'" >&2
    echo "   期望的标志位: 'FKY996'" >&2
    
    if [ "$mark" != "FKY996" ]; then
        echo "❌ 标志位不匹配" >&2
        return 1
    fi
    
    echo "   ✅ 标志位验证通过" >&2
    
    # ========================================================================
    # 第三步：读取 Value 字段（文件名内容）
    # ========================================================================
    # 读取文件名内容（根据 Length 字段的值）
    local content_string=$(tail -c $total_tlv_size "$file_path" | dd bs=1 skip=104 2>/dev/null)
    
    echo "   文件名读取成功: '$content_string'" >&2
    
    # 返回文件名内容
    echo "$content_string"
    return 0
}


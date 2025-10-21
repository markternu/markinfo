#!/bin/bash

# ============================================================================
# TLV 数据结构方案 (Type-Length-Value) - 修复版
# ============================================================================
# 存储结构（从文件末尾往前）：
#   [原始文件内容] [Type: 100B] [Length: 4B] [Value: NB]
#                                              ↑
#                                          文件末尾
# 读取顺序：
#   1. 从文件末尾读取 Value
#   2. 往前读取 Length (4字节)
#   3. 再往前读取 Type (100字节)
# ============================================================================

# 功能1：向文件末尾追加 TLV 格式数据
# 参数1: 要写入的字符串（文件名）
# 参数2: 目标文件路径
# 返回: 0=成功, 1=失败
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
    
    echo "🔧 开始写入 TLV 数据到文件: '$file_path'"
    
    # ========================================================================
    # 第一步：写入 Type 字段（100字节标志位）
    # ========================================================================
    echo "📝 [Type] 写入100字节标志位 '$mark_string'"
    
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
    
    # ========================================================================
    # 第二步：写入 Length 字段（4字节长度信息）
    # ========================================================================
    echo "📝 [Length] 写入文件名长度字段 (4字节)"
    
    # 计算文件名的实际字节数（UTF-8 编码）
    local name_size=$(printf "%s" "$name" | wc -c)
    echo "   文件名实际字节数: $name_size 字节"
    
    # 检查长度是否超过32位无符号整数最大值（4294967295）
    if [ $name_size -gt 4294967295 ]; then
        echo "❌ 错误: 文件名过长 ($name_size 字节)，超过4GB限制" >&2
        return 1
    fi
    
    # 将长度转换为4字节大端序（Big-Endian）整数
    # 格式：32位无符号整数，高字节在前
    printf "%08x" "$name_size" | xxd -r -p >> "$file_path"
    
    echo "   ✅ Length 字段写入完成 (4字节, 值=$name_size)"
    
    # ========================================================================
    # 第三步：写入 Value 字段（文件名原始内容）
    # ========================================================================
    echo "📝 [Value] 写入文件名内容 ($name_size 字节)"
    
    # 直接写入文件名，保留原始 UTF-8 编码，不做任何转换
    printf "%s" "$name" >> "$file_path"
    
    echo "   ✅ Value 字段写入完成"
    
    # ========================================================================
    # 完成统计
    # ========================================================================
    local total_bytes=$((100 + 4 + name_size))
    
    echo ""
    echo "🎉 TLV 数据写入完成!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 写入统计:"
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
# 功能2：从文件末尾读取 TLV 格式数据（修复版）
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
    
    # 最小文件大小检查（至少需要 Type + Length = 104 字节）
    if [ $file_size -lt 104 ]; then
        echo "❌ 错误: 文件太小 ($file_size 字节)，无法包含完整 TLV 数据" >&2
        return 1
    fi
    
    echo "🔍 开始读取文件末尾 TLV 数据: '$file_path'" >&2
    echo "" >&2
    
    # ========================================================================
    # 第一步：读取 Length 字段（倒数第4字节之前的4字节）
    # ========================================================================
    echo "📖 [Length] 读取长度字段..." >&2
    
    # 先读取文件末尾104字节的数据块（包含完整的 Type + Length + 部分Value）
    local tail_block=$(tail -c 104 "$file_path" | head -c 104)
    
    # 从这104字节中提取 Length 字段（第101-104字节）
    local length_hex=$(printf "%s" "$tail_block" | tail -c 4 | xxd -p)
    local name_length=$((16#$length_hex))
    
    echo "   文件名长度: $name_length 字节" >&2
    
    # 长度合理性检查
    if [ $name_length -lt 0 ] || [ $name_length -gt $((file_size - 104)) ]; then
        echo "❌ 错误: 长度字段异常 ($name_length 字节)，可能数据损坏" >&2
        return 1
    fi
    
    echo "   ✅ 长度字段读取成功" >&2
    
    # ========================================================================
    # 第二步：读取 Type 字段（标志位验证）
    # ========================================================================
    echo "📖 [Type] 读取并验证标志位..." >&2
    
    # 从 tail_block 中提取前100字节作为 Type 字段
    local mark=$(printf "%s" "$tail_block" | head -c 100 | tr -d '\0')
    
    echo "   标志位内容: '$mark'" >&2
    
    if [ "$mark" != "FKY996" ]; then
        echo "❌ 错误: 标志位不匹配 (期望='FKY996', 实际='$mark')" >&2
        echo "   文件可能未经处理或数据已损坏" >&2
        return 1
    fi
    
    echo "   ✅ 标志位验证通过" >&2
    
    # ========================================================================
    # 第三步：读取 Value 字段（文件名内容）
    # ========================================================================
    echo "📖 [Value] 读取文件名内容 ($name_length 字节)..." >&2
    
    # 读取完整的 TLV 块（Type + Length + Value）
    local total_tlv_size=$((100 + 4 + name_length))
    local full_tlv=$(tail -c $total_tlv_size "$file_path")
    
    # 从完整块中提取 Value（跳过前104字节的 Type + Length）
    local file_name=$(printf "%s" "$full_tlv" | tail -c +105)
    
    echo "   ✅ 文件名读取成功" >&2
    echo "" >&2
    
    # ========================================================================
    # 输出结果
    # ========================================================================
    echo "🎉 TLV 数据读取完成!" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "📊 读取结果:" >&2
    echo "   ├─ [Type]   标志位: FKY996 ✅" >&2
    echo "   ├─ [Length] 文件名长度: $name_length 字节" >&2
    echo "   └─ [Value]  文件名内容: '$file_name'" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    
    # 将文件名输出到 stdout（供调用者获取）
    echo "$file_name"
    
    return 0
}


# ============================================================================
# 功能3：验证文件是否包含有效的 TLV 数据（修复版）
# 参数1: 文件路径
# 返回: 0=包含有效TLV数据, 1=不包含或数据无效
# ============================================================================
function verify_tlv_data() {
    local file_path="$1"
    
    if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
        return 1
    fi
    
    local file_size=$(wc -c < "$file_path")
    
    # 文件太小，无法包含 TLV 数据
    if [ $file_size -lt 104 ]; then
        return 1
    fi
    
    # 读取文件末尾104字节
    local tail_block=$(tail -c 104 "$file_path" | head -c 100)
    
    # 提取标志位（前100字节）
    local mark=$(printf "%s" "$tail_block" | tr -d '\0')
    
    # 验证标志位
    if [ "$mark" = "FKY996" ]; then
        return 0  # 包含有效 TLV 数据
    else
        return 1  # 不包含有效 TLV 数据
    fi
}


# ============================================================================
# 功能4：移除文件末尾的 TLV 数据（修复版）
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
    
    local file_size=$(wc -c < "$file_path")
    
    if [ $file_size -lt 104 ]; then
        echo "❌ 错误: 文件太小，无 TLV 数据" >&2
        return 1
    fi
    
    # 先验证是否包含 TLV 数据
    if ! verify_tlv_data "$file_path"; then
        echo "❌ 错误: 文件不包含有效的 TLV 数据" >&2
        return 1
    fi
    
    echo "🗑️  正在移除 TLV 数据..."
    
    # 读取 Length 字段
    local tail_block=$(tail -c 104 "$file_path")
    local length_hex=$(printf "%s" "$tail_block" | tail -c 4 | xxd -p)
    local name_length=$((16#$length_hex))
    
    # 计算需要删除的总字节数
    local tlv_total_size=$((100 + 4 + name_length))
    
    # 计算原始文件大小
    local original_size=$((file_size - tlv_total_size))
    
    echo "   TLV 数据大小: $tlv_total_size 字节"
    echo "   原始文件大小: $original_size 字节"
    
    # 使用 truncate 截断文件
    truncate -s $original_size "$file_path"
    
    echo "✅ TLV 数据已移除，文件已恢复"
    
    return 0
}


# ============================================================================
# 功能5：批量验证和修复（可选的辅助函数）
# 参数1: 文件路径
# 返回: 打印 TLV 信息摘要
# ============================================================================
function inspect_tlv_data() {
    local file_path="$1"
    
    if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
        echo "❌ 文件不存在"
        return 1
    fi
    
    echo "🔍 检查文件: $file_path"
    
    if verify_tlv_data "$file_path"; then
        echo "   ✅ 包含有效 TLV 标记"
        
        # 读取详细信息
        local file_size=$(wc -c < "$file_path")
        local tail_block=$(tail -c 104 "$file_path")
        local length_hex=$(printf "%s" "$tail_block" | tail -c 4 | xxd -p)
        local name_length=$((16#$length_hex))
        local tlv_size=$((100 + 4 + name_length))
        
        echo "   📊 TLV 大小: $tlv_size 字节"
        echo "   📊 原始文件: $((file_size - tlv_size)) 字节"
        echo "   📝 文件名长度: $name_length 字节"
    else
        echo "   ⚠️  未找到 TLV 标记"
    fi
}


# ============================================================================
# 使用示例
# ============================================================================
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "📚 TLV 工具函数库已加载"
    echo ""
    echo "可用函数:"
    echo "  1. write_fixed_bytes <文件名> <文件路径>  - 写入 TLV 数据"
    echo "  2. read_fixed_bytes <文件路径>           - 读取 TLV 数据"
    echo "  3. verify_tlv_data <文件路径>            - 验证 TLV 数据"
    echo "  4. remove_tlv_data <文件路径>            - 移除 TLV 数据"
    echo "  5. inspect_tlv_data <文件路径>           - 检查 TLV 信息"
fi

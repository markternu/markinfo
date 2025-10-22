#!/bin/bash

# ============================================================================
# 功能2：读取文件末尾 V-L-T 数据并移除（V-L-T版本）
# 参数1: 文件路径
# 返回: 0=成功, 1=失败
# 输出: 读取到的原始文件名（通过 echo 到 stdout）
# 特点: 读取后删除 V-L-T 数据，恢复文件原始状态
# 数据结构: [Value NB][Length 4B][Type 100B]
# ============================================================================
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
    
    # 检查文件是否至少有104字节（V-L-T最小结构：Length(4B) + Type(100B)）
    if [ $file_size -lt 104 ]; then
        echo "❌ 错误: 文件大小不足104字节 (当前: $file_size 字节)" >&2
        echo "   V-L-T 最小结构需要: Length(4B) + Type(100B) = 104字节" >&2
        return 1
    fi
    
    echo "🔍 开始读取并移除文件末尾 V-L-T 数据: '$file_path'" >&2
    echo "" >&2
    
    # ========================================================================
    # 步骤1：验证 Type 字段（末尾100字节）- V-L-T 核心优势！
    # ========================================================================
    echo "📖 [步骤1/4] 验证 Type 字段 (末尾100字节)..." >&2
    
    # 读取文件末尾100字节
    local mark=$(tail -c 100 "$file_path" 2>/dev/null | tr -d '\0' 2>/dev/null)
    
    if [ -z "$mark" ]; then
        echo "❌ 错误: 读取 Type 字段失败" >&2
        return 1
    fi
    
    echo "   检测到的标志位: '$mark'" >&2
    echo "   期望的标志位: 'FKY996'" >&2
    
    # 快速验证：如果不是 FKY996，立即返回
    if [ "$mark" != "FKY996" ]; then
        echo "   ❌ 标志位不匹配" >&2
        echo "" >&2
        echo "❌ 错误: 文件非通过本脚本追加写入生成的文件" >&2
        echo "   无法通过本功能读取并切除文件末尾数据" >&2
        return 1
    fi
    
    echo "   ✅ 标志位验证通过" >&2
    
    # ========================================================================
    # 步骤2：读取 Length 字段（倒数101-104字节）
    # ========================================================================
    echo "📖 [步骤2/4] 读取 Length 字段..." >&2
    
    # 读取末尾104字节，提取前4字节作为 Length
    local length_hex=$(tail -c 104 "$file_path" 2>/dev/null | head -c 4 2>/dev/null | xxd -p 2>/dev/null | tr -d '\n')
    
    if [ -z "$length_hex" ]; then
        echo "❌ 错误: 读取 Length 字段失败" >&2
        return 1
    fi
    
    # 将十六进制转换为十进制
    local name_length=$((16#$length_hex))
    
    echo "   文件名长度: $name_length 字节" >&2
    
    # 长度合理性检查
    local total_vlt_size=$((name_length + 4 + 100))
    
    if [ $name_length -lt 0 ]; then
        echo "❌ 错误: 长度字段为负数 ($name_length)，数据损坏" >&2
        return 1
    fi
    
    if [ $file_size -lt $total_vlt_size ]; then
        echo "❌ 错误: 长度字段异常 ($name_length 字节)，超过文件剩余大小" >&2
        echo "   文件大小: $file_size 字节" >&2
        echo "   VLT总大小: $total_vlt_size 字节" >&2
        return 1
    fi
    
    echo "   ✅ 长度字段有效" >&2
    
    # ========================================================================
    # 步骤3：读取 Value 字段（原始文件名）
    # ========================================================================
    echo "📖 [步骤3/4] 读取 Value 字段 (原始文件名)..." >&2
    
    echo "   VLT 总大小: $total_vlt_size 字节" >&2
    echo "   ├─ Value:  $name_length 字节" >&2
    echo "   ├─ Length: 4 字节" >&2
    echo "   └─ Type:   100 字节" >&2
    
    # 读取完整的 V-L-T 块，提取前 name_length 字节（Value）
    local content_string=$(tail -c $total_vlt_size "$file_path" 2>/dev/null | head -c $name_length 2>/dev/null)
    
    if [ -z "$content_string" ]; then
        echo "❌ 错误: 读取 Value 字段失败或文件名为空" >&2
        return 1
    fi
    
    echo "   ✅ 文件名读取成功: '$content_string'" >&2
    
    # ========================================================================
    # 步骤4：删除 V-L-T 数据（截断文件）
    # ========================================================================
    echo "🗑️  [步骤4/4] 移除 V-L-T 数据..." >&2
    
    # 计算新文件大小（移除末尾 V-L-T 数据）
    local new_size=$((file_size - total_vlt_size))
    
    echo "   文件大小变化:" >&2
    echo "   ├─ 原始大小: $file_size 字节" >&2
    echo "   ├─ 移除数据: $total_vlt_size 字节" >&2
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
    
    # 将原文件除了末尾 V-L-T 数据的部分复制到临时文件
    if ! head -c $new_size "$file_path" > "$new_temp_file" 2>/dev/null; then
        echo "❌ 错误: 复制文件内容失败" >&2
        rm -f "$new_temp_file"
        return 1
    fi
    
    # 用临时文件替换原文件
    if ! mv "$new_temp_file" "$file_path" 2>/dev/null; then
        echo "❌ 错误: 替换文件失败" >&2
        rm -f "$new_temp_file"
        return 1
    fi
    
    echo "   ✅ V-L-T 数据已成功移除" >&2
    
    # ========================================================================
    # 完成输出
    # ========================================================================
    echo "" >&2
    echo "🎉 V-L-T 数据读取并移除完成!" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "📊 处理结果:" >&2
    echo "   ├─ 标志位验证: '$mark' ✅" >&2
    echo "   ├─ 读取文件名: '$content_string'" >&2
    echo "   ├─ 移除字节数: $total_vlt_size 字节" >&2
    echo "   ├─ 文件新大小: $(wc -c < "$file_path") 字节" >&2
    echo "   └─ 数据结构:   Value(${name_length}B) + Length(4B) + Type(100B)" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    
    # 将读取到的文件名内容输出到 stdout（供调用者获取）
    echo "$content_string"
    return 0
}


# ============================================================================
# 使用示例
# ============================================================================
# # 示例1：读取并移除，然后重命名文件
# original_name=$(read_and_remove_fixed_bytes "/path/to/file")
# if [ $? -eq 0 ]; then
#     mv "/path/to/file" "/path/to/$original_name"
# fi
#
# # 示例2：仅读取和移除，不重命名
# read_and_remove_fixed_bytes "/path/to/file"

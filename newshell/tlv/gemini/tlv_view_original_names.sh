#!/bin/bash

# ============================================================================
# 功能9：查看文件末尾 V-L-T 数据的原始文件名（V-L-T版本）
# 参数1: 文件路径
# 返回: 0=成功, 1=失败
# 输出: 读取到的原始文件名（通过 echo）
# 特点: 只读取，不修改文件
# 数据结构: [Value NB][Length 4B][Type 100B]
# ============================================================================
function view_original_names() {
    local file_path="$1"
    
    # ========================================================================
    # 参数检查
    # ========================================================================
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
    
    # 检查文件是否至少有104字节（V-L-T最小结构：Length(4B) + Type(100B)）
    if [ $file_size -lt 104 ]; then
        echo "❌ 错误: 文件大小不足104字节 (当前: $file_size 字节)" >&2
        echo "   V-L-T 最小结构需要: Length(4B) + Type(100B) = 104字节" >&2
        return 1
    fi
    
    echo "🔍 开始查看文件末尾的原始文件名信息" >&2
    echo "📂 文件路径: '$file_path'" >&2
    echo "📏 文件大小: $file_size 字节" >&2
    echo "" >&2
    
    # ========================================================================
    # 步骤1：验证 Type 字段（末尾100字节）- V-L-T 核心优势！
    # ========================================================================
    echo "📖 [步骤1/3] 验证 Type 字段 (末尾100字节)..." >&2
    
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
        echo "   ❌ 标志位不匹配 (检测到: '$mark'，期望: 'FKY996')" >&2
        echo "" >&2
        echo "❌ 错误: 文件非通过本脚本追加写入生成的文件" >&2
        echo "   无法读取末尾的 V-L-T 数据" >&2
        return 1
    fi
    
    echo "   ✅ 标志位验证通过" >&2
    
    # ========================================================================
    # 步骤2：读取 Length 字段（倒数101-104字节）
    # ========================================================================
    echo "📖 [步骤2/3] 读取 Length 字段..." >&2
    
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
        echo "   剩余空间: $((file_size - 104)) 字节" >&2
        return 1
    fi
    
    echo "   ✅ 长度字段有效" >&2
    
    # ========================================================================
    # 步骤3：读取 Value 字段（原始文件名）
    # ========================================================================
    echo "📖 [步骤3/3] 读取 Value 字段 (原始文件名)..." >&2
    
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
    
    echo "   ✅ 文件名读取成功" >&2
    
    # ========================================================================
    # 输出结果
    # ========================================================================
    echo "" >&2
    echo "🎉 V-L-T 数据读取完成!" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "📋 读取结果:" >&2
    echo "   ├─ [Type]   标志位: '$mark' ✅" >&2
    echo "   ├─ [Length] 文件名长度: $name_length 字节" >&2
    echo "   └─ [Value]  原始文件名: '$content_string'" >&2
    echo "" >&2
    echo "📊 数据结构: Value(${name_length}B) + Length(4B) + Type(100B)" >&2
    echo "⚠️  注意: 本操作仅查看，未修改文件" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    
    # 将读取到的原始文件名输出到 stdout（供调用者获取）
    echo "$content_string"
    return 0
}


# ============================================================================
# 使用示例
# ============================================================================
# view_original_names "/path/to/file"
#
# 或者捕获返回值：
# original_name=$(view_original_names "/path/to/file")
# if [ $? -eq 0 ]; then
#     echo "原始文件名: $original_name"
# fi

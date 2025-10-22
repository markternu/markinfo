#!/bin/bash

# ============================================================================
# batch_view_original_names 完整函数套件（V-L-T 版本）
# ============================================================================
# 包含的函数:
#   1. view_original_names       - 查看单个文件的原始文件名（依赖函数，已重构）
#   2. batch_view_original_names - 批量查看文件夹中文件的原始文件名（主函数）
# ============================================================================
# 数据结构 (V-L-T):
#   [Value]  N字节：  文件名实际内容（UTF-8编码）
#   [Length] 4字节：  文件名长度 N（32位无符号整数，大端序）
#   [Type]   100字节：标志位 "FKY996" + null填充
# ============================================================================


#========================================================================================================================
# 依赖函数：view_original_names（V-L-T版本 - 已重构）
#========================================================================================================================

# ============================================================================
# 功能9：查看文件末尾 V-L-T 数据的原始文件名（✅ V-L-T版本）
# 参数1: 文件路径
# 返回: 0=成功, 1=失败
# 输出: 读取到的原始文件名（通过 echo）
# 特点: 只读取，不修改文件
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
    
    # 检查文件是否至少有104字节（L + T = 104字节）
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


#========================================================================================================================
# 主函数：batch_view_original_names（✅ 已适配 V-L-T 版本）
#========================================================================================================================

# ============================================================================
# 功能10：批量查看文件夹中文件的原始文件名（✅ 已适配 V-L-T 格式）
# 参数1: 文件路径列表字符串 (如 "/path/v{1..40}" 或 "/v30")
# ============================================================================
# 更新说明：
#   - 调用 view_original_names（已升级为 V-L-T 版本）
#   - 支持任意长度文件名，无限制
#   - 完美支持中文、特殊字符等UTF-8编码
#   - 只读取，不修改文件（纯查看模式）
# ============================================================================
function batch_view_original_names() {
    local file_path_list_string="$1"
    
    # 检查参数
    if [ -z "$file_path_list_string" ]; then
        echo "❌ 错误: 文件路径列表不能为空"
        echo "用法: batch_view_original_names <文件路径列表>"
        echo "示例: batch_view_original_names \"/Users/cc/Desktop/test/oppp/v{1..40}\" 或 batch_view_original_names \"/v30\""
        return 1
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "👁️  批量查看原始文件名工具（V-L-T版本）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 处理路径: $file_path_list_string"
    echo "📖 操作说明: 读取文件末尾 V-L-T 数据获取原始文件名（纯查看，不做任何修改）"
    echo "🔧 数据格式: Value(NB) + Length(4B) + Type(100B)"
    echo "✨ V-L-T 优势: 先验证末尾100字节标志位，快速判断文件是否被处理"
    echo ""
    
    # 展开路径列表 (处理 {1..40} 这样的bash扩展)
    local path_array
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
    
    echo "📊 总共需要处理 ${#path_array[@]} 个文件夹"
    echo ""
    
    local processed_folders=0
    local total_success=0
    local total_failed=0
    local total_no_vlt=0
    
    # 遍历每个路径
    for path in "${path_array[@]}"; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
        echo "   👁️  开始查看文件夹中的文件原始名称"
        echo ""
        local files_success=0
        local files_failed=0
        local files_no_vlt=0
        
        # 使用while read循环安全处理包含空格的文件名
        while IFS= read -r -d '' file_path; do
            local current_filename=$(basename "$file_path")
            
            # 调试信息：显示正在处理的文件
            echo "     🔍 查看文件: '$current_filename'"
            
            # ✅ 调用 view_original_names 函数查看原始文件名
            local original_name_string
            local error_temp_file=$(mktemp)
            original_name_string=$(view_original_names "$file_path" 2>"$error_temp_file")
            local view_result=$?
            
            if [ $view_result -eq 0 ] && [ -n "$original_name_string" ]; then
                # 成功读取
                ((files_success++))
                echo "        ✅ 当前文件名: '$current_filename'"
                echo "        📝 原始文件名: '$original_name_string'"
                
                # 显示映射关系
                if [ "$current_filename" = "$original_name_string" ]; then
                    echo "        ℹ️  文件名未更改"
                else
                    echo "        ➡️  映射关系: '$original_name_string' → '$current_filename'"
                fi
            else
                # 检查是否是标志位不匹配（文件未被处理）
                if grep -q "标志位不匹配" "$error_temp_file" 2>/dev/null; then
                    ((files_no_vlt++))
                    echo "        ⏭️  跳过: 文件未被处理（无 V-L-T 标记）"
                else
                    # 其他错误
                    ((files_failed++))
                    echo "        ❌ 读取原始文件名失败: '$current_filename'"
                    # 显示详细的错误信息
                    if [ -s "$error_temp_file" ]; then
                        echo "           详细错误信息:"
                        sed 's/^/             /' "$error_temp_file" | head -5
                    fi
                fi
            fi
            
            # 清理临时文件
            rm -f "$error_temp_file"
            echo ""
            
        done < <(find "$path" -maxdepth 1 -type f -print0 2>/dev/null)
        
        echo "   📊 文件夹处理完成"
        echo "      ├─ 成功查看: $files_success 个文件"
        echo "      ├─ 无标记:   $files_no_vlt 个文件"
        echo "      └─ 失败:     $files_failed 个文件"
        ((processed_folders++))
        ((total_success += files_success))
        ((total_no_vlt += files_no_vlt))
        ((total_failed += files_failed))
        echo ""
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 批量查看完成!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 统计信息:"
    echo "   ├─ 总文件夹数:      ${#path_array[@]}"
    echo "   ├─ 已处理文件夹:    $processed_folders"
    echo "   ├─ 成功查看文件:    $total_success"
    echo "   ├─ 无V-L-T标记:     $total_no_vlt"
    echo "   ├─ 失败文件:        $total_failed"
    echo "   └─ V-L-T数据格式:   Value(NB) + Length(4B) + Type(100B)"
    echo ""
    echo "✨ V-L-T 优势说明:"
    echo "   - 快速验证: 只需读取末尾100字节即可判断文件是否被处理"
    echo "   - 无需遍历: 不需要读取整个文件，效率极高"
    echo "   - 安全可靠: 标志位在末尾，不会被误识别"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}


# ============================================================================
# 使用示例
# ============================================================================
#
# # 示例1: 单个文件夹
# batch_view_original_names "/path/to/folder"
#
# # 示例2: 多个文件夹（使用大括号扩展）
# batch_view_original_names "/path/to/v{1..40}"
#
# # 示例3: 多个独立路径
# batch_view_original_names "/path1 /path2 /path3"
#
# # 示例4: 完整路径
# batch_view_original_names "/Users/cc/Desktop/test/oppp/v{1..40}"
#
# ============================================================================


# ============================================================================
# 函数依赖关系
# ============================================================================
# batch_view_original_names (主函数)
#     │
#     └─→ view_original_names (查看单个文件的V-L-T数据)
#             │
#             └─ 系统命令: wc, tail, head, xxd, tr
# ============================================================================


# ============================================================================
# 修改记录
# ============================================================================
# v1.0: 初始版本（固定1100字节，T-L-V结构）
# v2.0: 升级为 V-L-T 格式
#   - 调用 view_original_names（V-L-T版本）
#   - 支持任意长度文件名（无限制）
#   - 完美支持中文、特殊字符
#   - 快速验证：先读末尾100字节判断是否被处理
#   - 新增统计：区分"成功"、"无标记"、"失败"三种状态
#   - 主函数逻辑无需大改，自动继承 V-L-T 的所有优势
# ============================================================================


# ============================================================================
# V-L-T 结构的优势（在此函数中的体现）
# ============================================================================
# 1. 快速判断文件是否被处理：
#    - 旧版（T-L-V）: 需要先读取末尾104字节，提取前100字节验证
#    - 新版（V-L-T）: 直接读取末尾100字节即可验证 ✅
#
# 2. 错误处理更清晰：
#    - 标志位不匹配 → 文件未被处理（正常情况，不算错误）
#    - 其他错误 → 文件损坏或读取失败（真正的错误）
#
# 3. 统计信息更准确：
#    - 成功查看: 文件有V-L-T标记且读取成功
#    - 无标记:   文件未被处理（末尾100字节不是"FKY996"）
#    - 失败:     文件有标记但读取失败（数据损坏等）
# ============================================================================

#!/bin/bash

# ============================================================================
# 功能5：获取一个带序号的文件名
# 返回: 生成的文件名（通过echo输出）
# ============================================================================
function getFileName() {
    # 文件前缀
    local filePrefix="dom"
    local indexFile="/indexFXY"
    
    echo "🔢 开始生成文件名..." >&2
    
    # 检查索引文件是否存在，不存在则创建并初始化为1
    if [ ! -f "$indexFile" ]; then
        echo "📁 索引文件不存在，创建并初始化: $indexFile" >&2
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
    echo "📝 操作流程: 验证标志位 → 读取原始文件名 → 生成新序号文件名 → 移动"
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
        echo "   📖 [步骤1/5] 验证 Type 字段 (末尾100字节)..."
        
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
        echo "   📖 [步骤2/5] 读取 Length 字段..."
        
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
        
        echo "      原始文件名长度: $name_length 字节"
        
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
        # 步骤3：读取 Value 字段（原始文件名）
        # ====================================================================
        echo "   📖 [步骤3/5] 读取 Value 字段 (原始文件名)..."
        
        echo "      VLT 总大小: $total_vlt_size 字节"
        echo "      ├─ Value:  $name_length 字节"
        echo "      ├─ Length: 4 字节"
        echo "      └─ Type:   100 字节"
        
        # 读取完整的 V-L-T 块，提取前 name_length 字节（Value）
        local original_name_string=$(tail -c $total_vlt_size "$file_path" 2>/dev/null | head -c $name_length 2>/dev/null)
        
        if [ -z "$original_name_string" ]; then
            ((failed_files++))
            echo "   ❌ 提取原始文件名失败：文件名为空"
            echo ""
            continue
        fi
        
        echo "      📄 读取到的原始文件名: '$original_name_string'"
        echo "      ✅ Value 字段读取成功"
        
        # ====================================================================
        # 步骤4：生成新的序号文件名（关键步骤！）
        # ====================================================================
        echo "   🔢 [步骤4/5] 生成新序号文件名..."
        
        local new_name_string
        local error_temp_file=$(mktemp)
        
        # 调用 getFileName 函数生成新文件名（如 dom1, dom2, dom3...）
        new_name_string=$(getFileName 2>"$error_temp_file")
        local get_name_result=$?
        
        if [ $get_name_result -ne 0 ] || [ -z "$new_name_string" ]; then
            ((failed_files++))
            echo "   ❌ 生成新文件名失败 (返回码: $get_name_result)"
            
            # 显示详细错误信息
            if [ -s "$error_temp_file" ]; then
                echo "      详细错误信息:"
                sed 's/^/        /' "$error_temp_file"
            fi
            rm -f "$error_temp_file"
            echo ""
            continue
        fi
        
        rm -f "$error_temp_file"
        
        echo "      🏷️  生成的新文件名: '$new_name_string'"
        echo "      📝 文件名映射: '$original_name_string' → '$new_name_string'"
        
        # ====================================================================
        # 步骤5：重命名并移动文件
        # ====================================================================
        echo "   📦 [步骤5/5] 重命名并移动文件..."
        
        local file_dir=$(dirname "$file_path")
        local temp_new_path="$file_dir/$new_name_string"
        
        # 重命名为新的序号文件名
        echo "      📝 重命名: '$filename' → '$new_name_string'"
        if ! mv "$file_path" "$temp_new_path" 2>/dev/null; then
            ((failed_files++))
            echo "   ❌ 重命名文件失败"
            echo ""
            continue
        fi
        
        echo "      ✅ 成功重命名文件"
        
        # 移动到目标文件夹
        local final_target_path="$target_folder/$new_name_string"
        
        # 检查目标位置是否已有同名文件（理论上不应该，因为是序号）
        if [ -f "$final_target_path" ]; then
            echo "      ⚠️  警告: 目标位置已存在 '$new_name_string'，添加时间戳后缀"
            local timestamp=$(date +"%Y%m%d_%H%M%S_%N" 2>/dev/null || date +"%Y%m%d_%H%M%S")
            final_target_path="$target_folder/${new_name_string}_${timestamp}"
            echo "         新文件名: '$(basename "$final_target_path")'"
        fi
        
        echo "      📦 移动到: '$(basename "$final_target_path")'"
        if mv "$temp_new_path" "$final_target_path" 2>/dev/null; then
            ((moved_files++))
            echo "   🎉 成功移动文件"
            echo "      ✅ 完整流程: '$filename' (原名: '$original_name_string') → '$new_name_string' → '$target_folder/'"
        else
            ((failed_files++))
            echo "   ❌ 移动文件失败"
            
            # 移动失败，尝试恢复原文件名
            echo "      🔄 尝试恢复原文件名"
            mv "$temp_new_path" "$file_path" 2>/dev/null
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
    echo "🏷️  文件命名: dom1, dom2, dom3... (按处理顺序)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}


# ============================================================================
# 使用示例
# ============================================================================
# moveProcessedFiles "/path/to/source/folder"

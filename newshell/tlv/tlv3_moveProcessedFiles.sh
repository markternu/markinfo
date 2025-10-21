#!/bin/bash

# ============================================================================
# 功能8：识别脚本默认追加的文件并移动到指定文件夹（TLV版本）
# 参数1: 文件夹路径
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
    echo "📦 脚本处理文件识别与移动工具 (TLV版本)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 扫描文件夹: '$folderPath'"
    echo "🎯 目标文件夹: '$target_folder'"
    echo "🔍 识别条件: 文件末尾包含有效的 TLV 标记 (FKY996)"
    echo "📝 操作流程: 读取文件名 → 重命名 → 移动到目标位置"
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
        
        # 检查文件是否至少有104字节（TLV最小结构：Type(100B) + Length(4B)）
        if [ -z "$file_size" ] || [ "$file_size" -lt 104 ]; then
            echo "   ⏭️  跳过: 文件大小不足104字节 (当前: ${file_size:-0} 字节)"
            echo ""
            continue
        fi
        
        echo "   📏 文件大小: $file_size 字节"
        
        # ====================================================================
        # 步骤1：读取 Length 字段（文件末尾4字节）
        # ====================================================================
        echo "   📖 [步骤1/4] 读取 Length 字段..."
        
        # 读取文件末尾4字节并转换为十六进制
        local length_hex=$(tail -c 4 "$file_path" 2>/dev/null | xxd -p 2>/dev/null)
        
        if [ -z "$length_hex" ]; then
            echo "   ❌ 读取 Length 字段失败"
            echo ""
            continue
        fi
        
        # 将十六进制转换为十进制
        local name_length=$((16#$length_hex))
        
        echo "      文件名长度: $name_length 字节"
        
        # 长度合理性检查
        if [ $name_length -lt 0 ] || [ $name_length -gt $((file_size - 104)) ]; then
            echo "   ⏭️  跳过: 长度字段异常 ($name_length 字节)，非 TLV 格式文件"
            echo ""
            continue
        fi
        
        # ====================================================================
        # 步骤2：计算并读取完整 TLV 块
        # ====================================================================
        echo "   📖 [步骤2/4] 读取完整 TLV 块..."
        
        local total_tlv_size=$((100 + 4 + name_length))
        echo "      TLV 总大小: $total_tlv_size 字节"
        echo "      ├─ Type:   100 字节"
        echo "      ├─ Length: 4 字节"
        echo "      └─ Value:  $name_length 字节"
        
        # 创建临时文件存储 TLV 块
        local temp_file=$(mktemp)
        
        if [ -z "$temp_file" ] || [ ! -f "$temp_file" ]; then
            echo "   ❌ 创建临时文件失败"
            echo ""
            continue
        fi
        
        # 读取文件末尾的完整 TLV 块
        if ! tail -c $total_tlv_size "$file_path" > "$temp_file" 2>/dev/null; then
            echo "   ❌ 读取 TLV 块失败"
            rm -f "$temp_file"
            echo ""
            continue
        fi
        
        # 检查提取的数据大小
        local extracted_size=$(wc -c < "$temp_file" 2>/dev/null)
        if [ -z "$extracted_size" ] || [ "$extracted_size" -lt $total_tlv_size ]; then
            echo "   ❌ 提取的数据不完整"
            rm -f "$temp_file"
            echo ""
            continue
        fi
        
        # ====================================================================
        # 步骤3：验证 Type 字段（标志位）
        # ====================================================================
        echo "   📖 [步骤3/4] 验证 Type 字段..."
        
        # 从 TLV 块中提取前100字节作为 Type 字段
        local mark=$(head -c 100 "$temp_file" 2>/dev/null | tr -d '\0' 2>/dev/null)
        
        # 显示标志位（用于调试）
        local debug_mark="${mark:0:20}"
        echo "      检测到标志位: '${debug_mark}...'"
        
        # 验证标志位
        if [ "$mark" != "FKY996" ]; then
            echo "   ⏭️  跳过: 标志位不匹配 (期望='FKY996', 实际='$mark')"
            rm -f "$temp_file"
            echo ""
            continue
        fi
        
        echo "      ✅ 标志位验证通过"
        ((processed_files++))
        
        # ====================================================================
        # 步骤4：提取 Value 字段（文件名）
        # ====================================================================
        echo "   📖 [步骤4/4] 提取文件名..."
        
        # 从 TLV 块中跳过前104字节（Type + Length），读取 Value
        local new_name_string=$(dd if="$temp_file" bs=1 skip=104 2>/dev/null)
        
        # 清理临时文件
        rm -f "$temp_file"
        
        if [ -z "$new_name_string" ]; then
            ((failed_files++))
            echo "   ❌ 提取文件名失败：文件名为空"
            echo ""
            continue
        fi
        
        echo "      🏷️  原始文件名: '$new_name_string'"
        
        # ====================================================================
        # 步骤5：重命名文件（如果需要）
        # ====================================================================
        local file_dir=$(dirname "$file_path")
        local temp_new_path="$file_dir/$new_name_string"
        
        # 检查新文件名是否与原文件名相同
        if [ "$filename" = "$new_name_string" ]; then
            echo "   ℹ️  文件名无需更改，直接移动"
            temp_new_path="$file_path"
        else
            # 需要重命名
            echo "   📝 重命名文件: '$filename' -> '$new_name_string'"
            if mv "$file_path" "$temp_new_path" 2>/dev/null; then
                echo "      ✅ 成功重命名文件"
            else
                ((failed_files++))
                echo "   ❌ 重命名文件失败"
                echo ""
                continue
            fi
        fi
        
        # ====================================================================
        # 步骤6：移动文件到目标文件夹
        # ====================================================================
        local final_target_path="$target_folder/$new_name_string"
        
        # 检查目标位置是否已有同名文件
        if [ -f "$final_target_path" ]; then
            echo "   ⚠️  目标位置已存在同名文件，添加时间戳后缀"
            local timestamp=$(date +"%Y%m%d_%H%M%S_%N" 2>/dev/null || date +"%Y%m%d_%H%M%S")
            local name_without_ext="${new_name_string%.*}"
            local ext="${new_name_string##*.}"
            
            if [ "$name_without_ext" = "$new_name_string" ]; then
                # 没有扩展名
                final_target_path="$target_folder/${new_name_string}_${timestamp}"
            else
                # 有扩展名
                final_target_path="$target_folder/${name_without_ext}_${timestamp}.${ext}"
            fi
            
            echo "      新文件名: '$(basename "$final_target_path")'"
        fi
        
        echo "   📦 移动文件到: '$(basename "$final_target_path")'"
        if mv "$temp_new_path" "$final_target_path" 2>/dev/null; then
            ((moved_files++))
            echo "   🎉 成功移动文件"
        else
            ((failed_files++))
            echo "   ❌ 移动文件失败"
            
            # 如果重命名了但移动失败，尝试恢复原文件名
            if [ "$temp_new_path" != "$file_path" ] && [ -f "$temp_new_path" ]; then
                echo "   🔄 尝试恢复原文件名"
                mv "$temp_new_path" "$file_path" 2>/dev/null
            fi
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
    echo "✅ 所有符合 TLV 格式的文件已处理完毕"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}


# ============================================================================
# 使用示例
# ============================================================================
# moveProcessedFiles "/path/to/source/folder"

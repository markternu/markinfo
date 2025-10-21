#!/bin/bash

# ============================================================================
# 紧急还原脚本 - 清理旧版本脚本写入的错误数据
# ============================================================================
# 功能: 删除文件末尾由旧脚本写入的乱码数据
# 原理: 查找标志位 "FKY996"，从该位置截断文件
# ============================================================================

# 标志位
MARKER="FKY996"

# ============================================================================
# 功能1: 检测并移除单个文件的错误数据
# 参数1: 文件路径
# 返回: 0=成功还原, 1=未找到标记或失败, 2=文件未被修改
# ============================================================================
function restore_single_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo "   ❌ 文件不存在: $file_path" >&2
        return 1
    fi
    
    local filename=$(basename "$file_path")
    local file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
    
    echo "   🔍 检查文件: '$filename' (${file_size} 字节)"
    
    # 检查文件是否足够大（至少包含标志位）
    if [ $file_size -lt 6 ]; then
        echo "      ⏭️  跳过: 文件太小，不可能包含标记"
        return 2
    fi
    
    # 方案1: 使用 grep 查找标志位在文件中的位置
    # 注意: grep -b 会显示字节偏移量
    local marker_positions=$(grep -abo "$MARKER" "$file_path" 2>/dev/null | tail -1 | cut -d: -f1)
    
    if [ -z "$marker_positions" ]; then
        echo "      ⏭️  跳过: 未找到标志位 '$MARKER'，文件可能未被处理"
        return 2
    fi
    
    # 找到最后一个标志位的位置
    local marker_offset=$marker_positions
    
    echo "      📍 找到标志位位置: 字节偏移 $marker_offset"
    
    # 计算原始文件大小（标志位之前的所有内容）
    local original_size=$marker_offset
    
    if [ $original_size -le 0 ]; then
        echo "      ⚠️  警告: 标志位在文件开头，无法还原"
        return 1
    fi
    
    # 计算将要删除的字节数
    local bytes_to_remove=$((file_size - original_size))
    
    echo "      📊 原始大小: $original_size 字节"
    echo "      🗑️  删除数据: $bytes_to_remove 字节"
    
    # 备份原文件（可选）
    # cp "$file_path" "${file_path}.backup"
    
    # 截断文件到标志位之前的位置
    if truncate -s $original_size "$file_path" 2>/dev/null; then
        echo "      ✅ 还原成功: 文件已恢复到 $original_size 字节"
        return 0
    else
        echo "      ❌ 还原失败: truncate 命令执行失败" >&2
        return 1
    fi
}


# ============================================================================
# 功能2: 批量还原视频文件（递归处理文件夹）
# 参数1: 文件夹路径
# ============================================================================
function restore_video_files() {
    local folderPath="$1"
    
    # 检查参数
    if [ -z "$folderPath" ]; then
        echo "❌ 错误: 文件夹路径不能为空"
        echo "用法: restore_video_files <文件夹路径>"
        return 1
    fi
    
    # 检查文件夹是否存在
    if [ ! -d "$folderPath" ]; then
        echo "❌ 错误: 文件夹 '$folderPath' 不存在"
        return 1
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 视频文件紧急还原工具"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 目标文件夹: '$folderPath'"
    echo "🔍 标志位: '$MARKER'"
    echo "⚠️  操作: 删除标志位及其后的所有数据"
    echo ""
    echo "🔄 开始递归扫描..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    local total_files=0
    local video_files=0
    local restored_files=0
    local skipped_files=0
    local failed_files=0
    local total_bytes_removed=0
    
    # 视频文件扩展名列表
    local video_extensions="mp4|avi|wmv|mov|mkv|flv|webm|m4v|3gp|3g2|mpg|mpeg|m2v|m4p|divx|xvid|asf|rm|rmvb|vob|ts|mts|m2ts|f4v|ogv|ogg|dv|amv"
    
    # 递归查找所有视频文件
    while IFS= read -r -d '' file_path; do
        ((total_files++))
        
        local filename=$(basename "$file_path")
        local extension="${filename##*.}"
        extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
        
        # 检查是否为视频文件
        if echo "$extension" | grep -qE "^($video_extensions)$"; then
            ((video_files++))
            
            # 记录文件原始大小
            local size_before=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
            
            # 尝试还原文件
            restore_single_file "$file_path"
            local result=$?
            
            if [ $result -eq 0 ]; then
                # 还原成功
                ((restored_files++))
                local size_after=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
                local bytes_removed=$((size_before - size_after))
                total_bytes_removed=$((total_bytes_removed + bytes_removed))
            elif [ $result -eq 1 ]; then
                # 还原失败
                ((failed_files++))
            else
                # 文件未被修改（没有标记）
                ((skipped_files++))
            fi
            
            echo ""
        fi
    done < <(find "$folderPath" -type f -print0 2>/dev/null)
    
    # 输出统计信息
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 视频文件还原完成!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 统计信息:"
    echo "   ├─ 扫描文件总数:    $total_files"
    echo "   ├─ 视频文件数:      $video_files"
    echo "   ├─ 成功还原:        $restored_files"
    echo "   ├─ 跳过(无标记):    $skipped_files"
    echo "   └─ 失败:            $failed_files"
    echo ""
    echo "💾 数据清理统计:"
    echo "   ├─ 总删除字节:      $total_bytes_removed 字节"
    echo "   ├─ 删除大小(MB):    $((total_bytes_removed / 1024 / 1024)) MB"
    echo "   └─ 平均每文件:      $((restored_files > 0 ? total_bytes_removed / restored_files : 0)) 字节"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ $failed_files -gt 0 ]; then
        echo "⚠️  警告: 有 $failed_files 个文件还原失败，请手动检查"
    fi
}


# ============================================================================
# 功能3: 交互式安全模式（逐个确认）
# 参数1: 文件夹路径
# ============================================================================
function restore_video_files_interactive() {
    local folderPath="$1"
    
    if [ -z "$folderPath" ] || [ ! -d "$folderPath" ]; then
        echo "❌ 错误: 无效的文件夹路径"
        return 1
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 视频文件还原工具 (交互模式)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 目标文件夹: '$folderPath'"
    echo ""
    
    local video_extensions="mp4|avi|wmv|mov|mkv|flv|webm|m4v|3gp|3g2|mpg|mpeg|m2v|m4p|divx|xvid|asf|rm|rmvb|vob|ts|mts|m2ts|f4v|ogv|ogg|dv|amv"
    
    # 查找包含标志位的视频文件
    while IFS= read -r -d '' file_path; do
        local filename=$(basename "$file_path")
        local extension="${filename##*.}"
        extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
        
        # 检查是否为视频文件
        if echo "$extension" | grep -qE "^($video_extensions)$"; then
            # 检查是否包含标志位
            if grep -q "$MARKER" "$file_path" 2>/dev/null; then
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "📄 发现需要还原的文件:"
                echo "   文件: $filename"
                echo "   路径: $file_path"
                echo "   大小: $(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null) 字节"
                echo ""
                
                read -p "🤔 是否还原此文件? (y/n/q=退出): " choice
                
                case "$choice" in
                    y|Y)
                        restore_single_file "$file_path"
                        echo ""
                        ;;
                    q|Q)
                        echo "⏸️  用户退出"
                        return 0
                        ;;
                    *)
                        echo "   ⏭️  跳过此文件"
                        echo ""
                        ;;
                esac
            fi
        fi
    done < <(find "$folderPath" -type f -print0 2>/dev/null)
    
    echo "✅ 交互式还原完成"
}


# ============================================================================
# 功能4: 预览模式（只检测不修改）
# 参数1: 文件夹路径
# ============================================================================
function preview_affected_files() {
    local folderPath="$1"
    
    if [ -z "$folderPath" ] || [ ! -d "$folderPath" ]; then
        echo "❌ 错误: 无效的文件夹路径"
        return 1
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 预览模式 - 检测受影响的文件"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 目标文件夹: '$folderPath'"
    echo ""
    
    local count=0
    local video_extensions="mp4|avi|wmv|mov|mkv|flv|webm|m4v|3gp|3g2|mpg|mpeg|m2v|m4p|divx|xvid|asf|rm|rmvb|vob|ts|mts|m2ts|f4v|ogv|ogg|dv|amv"
    
    while IFS= read -r -d '' file_path; do
        local filename=$(basename "$file_path")
        local extension="${filename##*.}"
        extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
        
        if echo "$extension" | grep -qE "^($video_extensions)$"; then
            if grep -q "$MARKER" "$file_path" 2>/dev/null; then
                ((count++))
                local file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
                local marker_pos=$(grep -abo "$MARKER" "$file_path" 2>/dev/null | tail -1 | cut -d: -f1)
                local bytes_to_remove=$((file_size - marker_pos))
                
                echo "📄 [$count] $filename"
                echo "   路径: $file_path"
                echo "   当前大小: $file_size 字节"
                echo "   标志位位置: $marker_pos 字节"
                echo "   将删除: $bytes_to_remove 字节"
                echo ""
            fi
        fi
    done < <(find "$folderPath" -type f -print0 2>/dev/null)
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 总计找到 $count 个需要还原的文件"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}


# ============================================================================
# 主菜单
# ============================================================================
function main_menu() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 视频文件紧急还原工具 - 主菜单"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "请选择操作模式:"
    echo "  1. 🔍 预览模式 - 只检测不修改"
    echo "  2. ⚡ 自动还原 - 批量自动处理"
    echo "  3. 🤝 交互模式 - 逐个确认还原"
    echo "  4. 📄 单文件还原"
    echo "  5. ❌ 退出"
    echo ""
    read -p "请输入选项 (1-5): " option
    
    case "$option" in
        1)
            read -p "📂 请输入文件夹路径: " folder
            preview_affected_files "$folder"
            ;;
        2)
            read -p "📂 请输入文件夹路径: " folder
            read -p "⚠️  确认要批量还原吗? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                restore_video_files "$folder"
            else
                echo "❌ 操作已取消"
            fi
            ;;
        3)
            read -p "📂 请输入文件夹路径: " folder
            restore_video_files_interactive "$folder"
            ;;
        4)
            read -p "📄 请输入文件路径: " file
            restore_single_file "$file"
            ;;
        5)
            echo "👋 再见!"
            exit 0
            ;;
        *)
            echo "❌ 无效选项"
            ;;
    esac
}


# ============================================================================
# 脚本入口
# ============================================================================
if [ $# -eq 0 ]; then
    # 无参数，显示菜单
    main_menu
else
    # 有参数，直接处理
    if [ -d "$1" ]; then
        restore_video_files "$1"
    elif [ -f "$1" ]; then
        restore_single_file "$1"
    else
        echo "❌ 错误: '$1' 不是有效的文件或文件夹"
        exit 1
    fi
fi

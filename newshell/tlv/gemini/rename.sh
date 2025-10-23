#!/bin/bash

# ======================================
# 配置变量 - 根据需要修改这里
# 运行脚本：
# bash   ./rename.sh /path/to/folder
# ======================================
namesub="com"      # 原文件名前缀（如需要改dom文件就改为 "dom"）
namechange="gom"   # 新文件名前缀

# ======================================
# 脚本主体 - 不需要修改
# ======================================

# 检查参数
if [ $# -eq 0 ]; then
    echo "使用方法: $0 <目标文件夹路径>"
    echo "示例: $0 /path/to/folder"
    exit 1
fi

folder_path="$1"

# 检查文件夹是否存在
if [ ! -d "$folder_path" ]; then
    echo "错误: 文件夹 '$folder_path' 不存在"
    exit 1
fi

# 计数器
count=0

echo "开始重命名..."
echo "原前缀: $namesub"
echo "新前缀: $namechange"
echo "目标文件夹: $folder_path"
echo "-----------------------------------"

# 遍历所有符合条件的文件
for file in "$folder_path"/${namesub}[0-9]*; do
    # 检查文件是否存在（避免通配符无匹配时的问题）
    if [ ! -e "$file" ]; then
        continue
    fi
    
    # 获取文件名（不含路径）
    filename=$(basename "$file")
    
    # 提取数字部分
    number=${filename#$namesub}
    
    # 构造新文件名
    newname="${namechange}${number}"
    newfile="$folder_path/$newname"
    
    # 重命名文件
    if [ -e "$newfile" ]; then
        echo "警告: $newname 已存在，跳过 $filename"
    else
        mv "$file" "$newfile"
        echo "$filename -> $newname"
        ((count++))
    fi
done

echo "-----------------------------------"
echo "完成！共重命名 $count 个文件"

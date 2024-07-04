#!/bin/bash

# 提示用户输入文件夹地址
read -p "请输入文件夹地址: " folder_path
# 判断文件夹是否存在
if [ ! -d "$folder_path" ]; then
    echo "错误：提供的地址不是一个有效的文件夹。"
    exit 1
fi
# 进入指定文件夹
cd "$folder_path"
# 遍历文件夹下的所有文件
for file in *; do
    # 判断文件是否是普通文件
    if [ -f "$file" ]; then
        # 获取文件名和后缀，并生成新的文件名
        filename=$(basename -- "$file")
        extension="${filename##*.}"
        new_filename="${filename%.*}"

        # 删除文件后缀并创建新文件
        mv "$file" "${new_filename}"

        # 输出处理结果
        echo "已处理文件：$file -> ${new_filename}${extension}"
    fi
done


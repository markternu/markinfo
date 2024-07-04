#!/bin/bash

# 源文件夹路径
src_folder="/var/lib/transmission/Downloads"
# 目标文件夹路径
dest_folder="/p2/"

FValue=160

ind=$(cat /i)
km="fgg"
echo "读取的值: $ind"

# 递归遍历源文件夹中的所有.txt文件，并将它们移动到目标文件夹中
function move_txt_files() {
    local folder="$1"
    local dest="$2"

    # 遍历文件夹中的文件和子文件夹
    for item in "$folder"/*; do
        if [ -f "$item" ]; then
            # 检查文件是否为.txt后缀
            if [[ "$item" == *.mp4 ]]; then
            
                file_size=$(stat -c%s "$item")
                if (( file_size > FValue * 1024 * 1024 )); then

                  ind=$(cat /i)
                  echo "当前值: $ind"
                  nfe="${km}${ind}"

                  # 移动.txt文件到目标文件夹
                  mv "$item" "$dest$nfe"
                  echo "Moved $item to $dest"

                  # 对值加一并写回/i文件
                  ((ind++))
                  echo "$ind" > /i
                fi
            fi
        elif [ -d "$item" ]; then
            # 如果是子文件夹，递归调用此函数
            move_txt_files "$item" "$dest"
        fi
    done
}


function move_txt_files_avi() {
    local folder="$1"
    local dest="$2"

  
    for item in "$folder"/*; do
        if [ -f "$item" ]; then
            
            if [[ "$item" == *.avi ]]; then
            
                file_size=$(stat -c%s "$item")
                if (( file_size > FValue * 1024 * 1024 ));
then

                  ind=$(cat /i)
                  echo "当前值: $ind"
                  nfe="${km}${ind}"

      
                  mv "$item" "$dest$nfe"
                  echo "Moved $item to $dest"

                  # add
                  ((ind++))
                  echo "$ind" > /i
                fi
            fi
        elif [ -d "$item" ]; then
            # mv
            move_txt_files_avi "$item" "$dest"
        fi
    done
}


function move_txt_files_wmv() {
    local folder="$1"
    local dest="$2"

    
    for item in "$folder"/*; do
        if [ -f "$item" ]; then
            
            if [[ "$item" == *.wmv ]]; then
            
                file_size=$(stat -c%s "$item")
                if (( file_size > FValue * 1024 * 1024 ));
then

                  ind=$(cat /i)
                  echo "当前值: $ind"
                  nfe="${km}${ind}"

      
                  mv "$item" "$dest$nfe"
                  echo "Moved $item to $dest"

                  # add
                  ((ind++))
                  echo "$ind" > /i
                fi
            fi
        elif [ -d "$item" ]; then
            # mv
            move_txt_files_wmv "$item" "$dest"
        fi
    done
}



# Use aVi
move_txt_files_avi "$src_folder" "$dest_folder"
# Use _wmv
move_txt_files_wmv "$src_folder" "$dest_folder"
# 调用函数，开始移动.txt文件
move_txt_files "$src_folder" "$dest_folder"


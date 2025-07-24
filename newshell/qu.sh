#!/bin/bash

# 功能1：去掉文件夹下所有文件的文件后缀
function1() {
    read -p "请输入目标文件夹路径：" dir
    if [[ ! -d "$dir" ]]; then
        echo "文件夹不存在！"
        return 1
    fi

    for file in "$dir"/*; do
        if [[ -f "$file" && "$file" == *.* ]]; then
            base="${file%.*}"
            mv "$file" "$base"
            echo "已重命名：$file -> $base"
        fi
    done
}

# 功能2：无脑给所有文件/文件夹添加指定后缀
function2() {
    read -p "请输入目标文件夹路径：" dir
    if [[ ! -d "$dir" ]]; then
        echo "文件夹不存在！"
        return 1
    fi

    read -p "请输入要添加的后缀（不要带点）：" suffix

    cd "$dir" || { echo "无法进入目录"; return 1; }

    for name in *; do
        if [[ -e "$name" ]]; then
            mv "$name" "$name.$suffix"
            echo "已重命名：$name -> $name.$suffix"
        fi
    done
}

# 主函数
main() {
    echo "请选择你要执行的功能："
    echo "1：去掉文件夹下所有文件的文件后缀"
    echo "2：给文件夹下所有无后缀的文件添加后缀"

    read -p "请输入功能编号（1或2）：" choice

    case "$choice" in
        1)
            function1
            ;;
        2)
            function2
            ;;
        *)
            echo "无效的选项！请输入1或2。"
            ;;
    esac
}

# 运行主程序
main "$@"

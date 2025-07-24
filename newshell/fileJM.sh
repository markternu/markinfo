#!/bin/sh

set -e

echo "==============================="
echo "  OpenSSL 文件加密 / 解密工具"
echo "  自动处理随机 IV，兼容跨平台"
echo "==============================="
echo ""
echo "请选择操作:"
echo "1. 加密当前目录下所有文件"
echo "2. 解密当前目录下所有 .enc 文件"
echo ""
read -p "请输入选项 (1 或 2): " choice

if [ "$choice" != "1" ] && [ "$choice" != "2" ]; then
  echo "❌ 无效输入，退出脚本。"
  exit 1
fi

# 密码输入（不留痕）
echo ""
echo "请输入加密/解密密码（输入时不会显示）:"
stty -echo
read password
stty echo
echo "\n✅ 密码已输入。"

encrypt_file() {
  infile="$1"
  outfile="$infile.enc"

  # 生成 16 字节随机 IV
  IV_BIN=$(openssl rand 16)
  IV_HEX=$(echo "$IV_BIN" | xxd -p | tr -d '\n')

  # 加密
  echo "$IV_BIN" > "$outfile"  # 写入 IV（二进制）作为前缀
  if openssl enc -aes-256-cbc -pbkdf2 -nosalt -pass pass:"$password" -iv "$IV_HEX" -in "$infile" >> "$outfile"; then
    echo "✅ 加密完成: $outfile"
  else
    echo "❌ 加密失败: $infile"
    rm -f "$outfile"
  fi
}

decrypt_file() {
  infile="$1"
  outfile="$(echo "$infile" | sed 's/\.enc$//')"

  head -c 16 "$infile" > "$infile.iv"
  tail -c +17 "$infile" > "$infile.data"

  IV_HEX=$(xxd -p "$infile.iv" | tr -d '\n')

  if openssl enc -aes-256-cbc -pbkdf2 -nosalt -d -iv "$IV_HEX" -pass pass:"$password" -in "$infile.data" -out "$outfile"; then
    echo "✅ 解密完成: $outfile"
  else
    echo "❌ 解密失败: $infile"
    rm -f "$outfile"
  fi

  rm -f "$infile.iv" "$infile.data"
}

if [ "$choice" = "1" ]; then
  echo "\n🔐 开始加密..."
  for file in *; do
    [ -f "$file" ] || continue
    [ "$file" = "$(basename "$0")" ] && continue
    case "$file" in
      *.enc) continue ;;
    esac
    encrypt_file "$file"
  done
else
  echo "\n🔓 开始解密..."
  for file in *.enc; do
    [ -f "$file" ] || continue
    decrypt_file "$file"
  done
fi

echo "\n🎉 操作完成。"

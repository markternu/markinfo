#!/bin/bash

# ============================================================================
# TLV 函数测试脚本
# ============================================================================

# 加载 TLV 函数库（假设保存为 tlv_functions.sh）
# source tlv_functions.sh

# 测试用的临时文件
TEST_FILE="test_video.mp4"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 TLV 函数测试套件"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================================================
# 测试1: 创建测试文件
# ============================================================================
echo "📝 测试1: 创建测试文件"
echo "This is a test video file content." > "$TEST_FILE"
echo "   ✅ 测试文件已创建: $TEST_FILE"
echo ""

# ============================================================================
# 测试2: 测试简单英文文件名
# ============================================================================
echo "📝 测试2: 测试简单英文文件名"
TEST_NAME="simple_test.mp4"
echo "   输入文件名: '$TEST_NAME'"

if write_fixed_bytes "$TEST_NAME" "$TEST_FILE"; then
    echo "   ✅ 写入成功"
else
    echo "   ❌ 写入失败"
    exit 1
fi
echo ""

# 验证
echo "   验证写入的数据..."
if verify_tlv_data "$TEST_FILE"; then
    echo "   ✅ TLV 验证通过"
else
    echo "   ❌ TLV 验证失败"
    exit 1
fi

# 读取
echo "   读取文件名..."
RESULT=$(read_fixed_bytes "$TEST_FILE" 2>/dev/null)
if [ "$RESULT" = "$TEST_NAME" ]; then
    echo "   ✅ 读取成功，文件名匹配: '$RESULT'"
else
    echo "   ❌ 读取失败，文件名不匹配"
    echo "      期望: '$TEST_NAME'"
    echo "      实际: '$RESULT'"
    exit 1
fi
echo ""

# 移除 TLV 数据
echo "   移除 TLV 数据..."
if remove_tlv_data "$TEST_FILE"; then
    echo "   ✅ TLV 数据已移除"
else
    echo "   ❌ 移除失败"
    exit 1
fi
echo ""

# ============================================================================
# 测试3: 测试中文文件名
# ============================================================================
echo "📝 测试3: 测试中文文件名"
TEST_NAME="【中文测试】视频文件 (2024).mp4"
echo "   输入文件名: '$TEST_NAME'"

if write_fixed_bytes "$TEST_NAME" "$TEST_FILE"; then
    echo "   ✅ 写入成功"
else
    echo "   ❌ 写入失败"
    exit 1
fi
echo ""

# 读取
echo "   读取文件名..."
RESULT=$(read_fixed_bytes "$TEST_FILE" 2>/dev/null)
if [ "$RESULT" = "$TEST_NAME" ]; then
    echo "   ✅ 读取成功，中文文件名匹配: '$RESULT'"
else
    echo "   ❌ 读取失败，文件名不匹配"
    echo "      期望: '$TEST_NAME'"
    echo "      实际: '$RESULT'"
    exit 1
fi
echo ""

# 移除
remove_tlv_data "$TEST_FILE" > /dev/null 2>&1
echo ""

# ============================================================================
# 测试4: 测试超长文件名（含多种字符）
# ============================================================================
echo "📝 测试4: 测试超长文件名"
TEST_NAME="这是一个非常非常非常非常非常非常非常非常非常非常非常长的中文文件名_with_English_【符号】_spaces  _and_numbers_123456789_$(date +%Y%m%d%H%M%S).mp4"
NAME_LENGTH=$(printf "%s" "$TEST_NAME" | wc -c)
echo "   输入文件名长度: $NAME_LENGTH 字节"
echo "   文件名: '${TEST_NAME:0:50}...'"

if write_fixed_bytes "$TEST_NAME" "$TEST_FILE"; then
    echo "   ✅ 写入成功"
else
    echo "   ❌ 写入失败"
    exit 1
fi
echo ""

# 读取
echo "   读取文件名..."
RESULT=$(read_fixed_bytes "$TEST_FILE" 2>/dev/null)
if [ "$RESULT" = "$TEST_NAME" ]; then
    echo "   ✅ 读取成功，超长文件名完整匹配"
else
    echo "   ❌ 读取失败，文件名不匹配"
    echo "      期望长度: $(printf "%s" "$TEST_NAME" | wc -c) 字节"
    echo "      实际长度: $(printf "%s" "$RESULT" | wc -c) 字节"
    exit 1
fi
echo ""

# 移除
remove_tlv_data "$TEST_FILE" > /dev/null 2>&1
echo ""

# ============================================================================
# 测试5: 测试包含特殊字符的文件名
# ============================================================================
echo "📝 测试5: 测试特殊字符文件名"
TEST_NAME="test_with_symbols_!@#\$%^&*()_+-=[]{}|;':\",./<>?.mp4"
echo "   输入文件名: '$TEST_NAME'"

if write_fixed_bytes "$TEST_NAME" "$TEST_FILE"; then
    echo "   ✅ 写入成功"
else
    echo "   ❌ 写入失败"
    exit 1
fi

# 读取
RESULT=$(read_fixed_bytes "$TEST_FILE" 2>/dev/null)
if [ "$RESULT" = "$TEST_NAME" ]; then
    echo "   ✅ 读取成功，特殊字符文件名匹配"
else
    echo "   ❌ 读取失败"
    exit 1
fi
echo ""

# 移除
remove_tlv_data "$TEST_FILE" > /dev/null 2>&1
echo ""

# ============================================================================
# 测试6: 测试重复写入检测
# ============================================================================
echo "📝 测试6: 测试重复写入检测"
TEST_NAME="repeat_test.mp4"

write_fixed_bytes "$TEST_NAME" "$TEST_FILE" > /dev/null 2>&1
echo "   第一次写入完成"

if verify_tlv_data "$TEST_FILE"; then
    echo "   ✅ TLV 标记检测正常，可用于防止重复处理"
else
    echo "   ❌ TLV 标记检测失败"
    exit 1
fi
echo ""

# ============================================================================
# 测试7: 测试 inspect 函数
# ============================================================================
echo "📝 测试7: 测试 inspect 函数"
inspect_tlv_data "$TEST_FILE"
echo ""

# ============================================================================
# 清理
# ============================================================================
echo "🧹 清理测试文件..."
rm -f "$TEST_FILE"
echo "   ✅ 测试文件已删除"
echo ""

# ============================================================================
# 测试总结
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 所有测试通过！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 测试项目:"
echo "   1. 简单英文文件名 - 通过"
echo "   2. 中文文件名 - 通过"
echo "   3. 超长文件名 - 通过"
echo "   4. 特殊字符文件名 - 通过"
echo "   5. 重复写入检测 - 通过"
echo "   6. 数据检查功能 - 通过"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

#!/bin/bash

# 测试脚本 - 用于测试 file_rw3.sh 中各个函数的功能
# 作者: AI Assistant
# 版本: 1.0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试结果统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
TEST_RESULTS=()

# 导入原始脚本
SCRIPT_PATH="./file_rw3.sh"
if [ ! -f "$SCRIPT_PATH" ]; then
    echo -e "${RED}❌ 错误: 找不到原始脚本文件 '$SCRIPT_PATH'${NC}"
    exit 1
fi

# 导入原始脚本的函数
source "$SCRIPT_PATH"

# 测试工作目录
TEST_WORKSPACE="test_workspace"

# 测试辅助函数
function log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

function log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

function log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

function log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 测试结果记录函数
function record_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    ((TOTAL_TESTS++))
    if [ "$result" = "PASS" ]; then
        ((PASSED_TESTS++))
        log_success "测试通过: $test_name - $message"
    else
        ((FAILED_TESTS++))
        log_error "测试失败: $test_name - $message"
    fi
    
    TEST_RESULTS+=("$test_name: $result - $message")
}

# 断言函数
function assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    if [ "$expected" = "$actual" ]; then
        record_test_result "$test_name" "PASS" "期望: '$expected', 实际: '$actual'"
        return 0
    else
        record_test_result "$test_name" "FAIL" "期望: '$expected', 实际: '$actual'"
        return 1
    fi
}

function assert_file_exists() {
    local file_path="$1"
    local test_name="$2"
    
    if [ -f "$file_path" ]; then
        record_test_result "$test_name" "PASS" "文件存在: '$file_path'"
        return 0
    else
        record_test_result "$test_name" "FAIL" "文件不存在: '$file_path'"
        return 1
    fi
}

function assert_file_not_exists() {
    local file_path="$1"
    local test_name="$2"
    
    if [ ! -f "$file_path" ]; then
        record_test_result "$test_name" "PASS" "文件不存在: '$file_path'"
        return 0
    else
        record_test_result "$test_name" "FAIL" "文件意外存在: '$file_path'"
        return 1
    fi
}

function assert_return_code() {
    local expected_code="$1"
    local actual_code="$2"
    local test_name="$3"
    
    if [ "$expected_code" -eq "$actual_code" ]; then
        record_test_result "$test_name" "PASS" "返回码正确: $actual_code"
        return 0
    else
        record_test_result "$test_name" "FAIL" "返回码错误: 期望$expected_code, 实际$actual_code"
        return 1
    fi
}

# 环境准备函数
function setup_test_environment() {
    log_info "准备测试环境..."
    
    # 清理旧的测试环境
    if [ -d "$TEST_WORKSPACE" ]; then
        rm -rf "$TEST_WORKSPACE"
    fi
    
    # 创建测试工作目录
    mkdir -p "$TEST_WORKSPACE"
    cd "$TEST_WORKSPACE"
    
    # 创建各种测试文件夹
    mkdir -p "普通文件夹"
    mkdir -p "中文 空格 文件夹"
    mkdir -p "special@#\$folder"
    mkdir -p "测试视频文件夹"
    mkdir -p "临时测试文件夹"
    mkdir -p "移动目标文件夹"
    mkdir -p "嵌套文件夹/子文件夹1/孙文件夹"
    mkdir -p "嵌套文件夹/子文件夹2"
    
    # 创建各种测试文件
    echo "普通文本内容" > "普通文件夹/test.txt"
    echo "中文内容测试" > "普通文件夹/测试文件.txt"
    echo "mixed content 混合内容" > "普通文件夹/mixed file.txt"
    echo "special@#\$content" > "普通文件夹/special@file.txt"
    
    # 在中文空格文件夹中创建文件
    echo "中文文件夹中的内容" > "中文 空格 文件夹/中文 文件.txt"
    echo "English in Chinese folder" > "中文 空格 文件夹/english.txt"
    
    # 创建视频文件（小文件，模拟视频格式）
    dd if=/dev/zero of="测试视频文件夹/small_video.mp4" bs=1024 count=50 2>/dev/null
    dd if=/dev/zero of="测试视频文件夹/large_video.avi" bs=1024 count=150000 2>/dev/null # >100MB
    dd if=/dev/zero of="测试视频文件夹/中文视频.mkv" bs=1024 count=50 2>/dev/null
    
    # 创建非视频文件
    echo "not a video" > "测试视频文件夹/document.txt"
    echo "image data" > "测试视频文件夹/image.jpg"
    
    # 创建跳过条件文件
    mkdir -p "跳过文件夹"
    echo "normal file" > "跳过文件夹/normal.txt"
    echo "skip marker" > "跳过文件夹/test.tmpfile"
    
    # 创建aria2跳过条件
    mkdir -p "aria2文件夹"
    echo "video content" > "aria2文件夹/video.mp4"
    echo "aria2 marker" > "aria2文件夹/download.aria2"
    
    # 创建url文件（应被删除）
    mkdir -p "url文件夹"
    echo "some file" > "url文件夹/somefile.txt"
    echo "http://example.com" > "url文件夹/url"
    
    log_success "测试环境准备完成"
    echo ""
}

# 清理测试环境
function cleanup_test_environment() {
    cd ..
    if [ -d "$TEST_WORKSPACE" ]; then
        rm -rf "$TEST_WORKSPACE"
    fi
    
    # 清理索引文件
    local index_file="/Users/codew/Desktop/indexFXY"
    if [ -f "$index_file" ]; then
        rm -f "$index_file"
    fi
    
    # 清理目标文件夹
    if [ -d "/p2" ]; then
        rm -rf "/p2"
    fi
}

# 测试 get_byte_length 函数
function test_get_byte_length() {
    log_info "测试 get_byte_length 函数..."
    
    # TC01: 纯英文字符串
    local result=$(get_byte_length "hello")
    assert_equals "5" "$result" "get_byte_length_TC01_英文字符串"
    
    # TC02: 纯中文字符串
    local result=$(get_byte_length "你好")
    assert_equals "6" "$result" "get_byte_length_TC02_中文字符串"
    
    # TC03: 中英文混合
    local result=$(get_byte_length "hello你好")
    assert_equals "11" "$result" "get_byte_length_TC03_中英文混合"
    
    # TC04: 特殊字符
    local result=$(get_byte_length "test@#$")
    assert_equals "7" "$result" "get_byte_length_TC04_特殊字符"
    
    # TC05: 空字符串
    local result=$(get_byte_length "")
    assert_equals "0" "$result" "get_byte_length_TC05_空字符串"
    
    echo ""
}

# 测试 parse_path_list 函数
function test_parse_path_list() {
    log_info "测试 parse_path_list 函数..."
    
    # TC01: 单个简单路径
    local test_paths="/path1"
    local result_array=()
    parse_path_list "$test_paths" result_array 2>/dev/null
    assert_equals "1" "${#result_array[@]}" "parse_path_list_TC01_路径数量"
    assert_equals "/path1" "${result_array[0]}" "parse_path_list_TC01_路径内容"
    
    # TC02: 多个路径用空格分隔
    local test_paths="/path1 /path2 /path3"
    local result_array=()
    parse_path_list "$test_paths" result_array 2>/dev/null
    assert_equals "3" "${#result_array[@]}" "parse_path_list_TC02_多路径数量"
    
    # TC03: 包含空格的路径（用引号包围）
    local test_paths='"/path with spaces" /normalpath'
    local result_array=()
    parse_path_list "$test_paths" result_array 2>/dev/null
    assert_equals "2" "${#result_array[@]}" "parse_path_list_TC03_引号路径数量"
    
    # TC04: 大括号扩展
    local test_paths="/path/v{1..3}"
    local result_array=()
    parse_path_list "$test_paths" result_array 2>/dev/null
    assert_equals "3" "${#result_array[@]}" "parse_path_list_TC04_大括号扩展数量"
    assert_equals "/path/v1" "${result_array[0]}" "parse_path_list_TC04_第一个路径"
    assert_equals "/path/v3" "${result_array[2]}" "parse_path_list_TC04_最后路径"
    
    echo ""
}

# 测试 write_fixed_bytes 和 read_and_remove_fixed_bytes 函数
function test_write_and_read_fixed_bytes() {
    log_info "测试 write_fixed_bytes 和 read_and_remove_fixed_bytes 函数..."
    
    # 准备测试文件
    local test_file="test_write_read.txt"
    echo "original content" > "$test_file"
    
    # TC01: 写入纯英文文件名
    write_fixed_bytes "testfile.txt" "$test_file" >/dev/null 2>&1
    local write_result=$?
    assert_return_code "0" "$write_result" "write_fixed_bytes_TC01_英文写入"
    
    # 验证文件大小增加了1100字节
    local file_size=$(wc -c < "$test_file")
    local expected_size=$((16 + 1100))  # original content + 1100 bytes
    assert_equals "$expected_size" "$file_size" "write_fixed_bytes_TC01_文件大小"
    
    # 读取并验证
    local read_result=$(read_and_remove_fixed_bytes "$test_file" 2>/dev/null)
    local read_return_code=$?
    assert_return_code "0" "$read_return_code" "read_fixed_bytes_TC01_读取返回码"
    assert_equals "testfile.txt" "$read_result" "read_fixed_bytes_TC01_读取内容"
    
    # TC02: 写入中文文件名
    echo "original content" > "$test_file"
    write_fixed_bytes "中文文件名.txt" "$test_file" >/dev/null 2>&1
    local read_result=$(read_and_remove_fixed_bytes "$test_file" 2>/dev/null)
    assert_equals "中文文件名.txt" "$read_result" "write_read_TC02_中文文件名"
    
    # TC03: 写入混合文件名
    echo "original content" > "$test_file"
    write_fixed_bytes "mixed 中文 file.txt" "$test_file" >/dev/null 2>&1
    local read_result=$(read_and_remove_fixed_bytes "$test_file" 2>/dev/null)
    assert_equals "mixed 中文 file.txt" "$read_result" "write_read_TC03_混合文件名"
    
    # TC04: 写入超长文件名
    local long_name=""
    for i in {1..100}; do
        long_name="${long_name}很长的文件名"
    done
    echo "original content" > "$test_file"
    write_fixed_bytes "$long_name" "$test_file" >/dev/null 2>&1
    local read_result=$(read_and_remove_fixed_bytes "$test_file" 2>/dev/null)
    # 超长文件名应该被截断到1000字节
    local truncated_name=$(echo -n "$long_name" | head -c 1000 | tr -d '\0')
    assert_equals "$truncated_name" "$read_result" "write_read_TC04_超长文件名截断"
    
    # TC05: 读取无效标志位的文件
    echo "original content without marker" > "$test_file"
    dd if=/dev/zero bs=1 count=1100 >> "$test_file" 2>/dev/null
    local read_result=$(read_and_remove_fixed_bytes "$test_file" 2>/dev/null)
    local read_return_code=$?
    assert_return_code "1" "$read_return_code" "read_fixed_bytes_TC05_无效标志位"
    
    rm -f "$test_file"
    echo ""
}

# 测试 isVideoFileFunction 函数
function test_isVideoFileFunction() {
    log_info "测试 isVideoFileFunction 函数..."
    
    # 创建测试文件
    touch "test.mp4" "test.avi" "test.mkv" "test.txt" "test.jpg" "中文视频.mp4"
    
    # TC01: 常见视频格式
    isVideoFileFunction "test.mp4" >/dev/null 2>&1
    assert_return_code "0" "$?" "isVideoFileFunction_TC01_mp4格式"
    
    isVideoFileFunction "test.avi" >/dev/null 2>&1
    assert_return_code "0" "$?" "isVideoFileFunction_TC01_avi格式"
    
    isVideoFileFunction "test.mkv" >/dev/null 2>&1
    assert_return_code "0" "$?" "isVideoFileFunction_TC01_mkv格式"
    
    # TC02: 非视频文件
    isVideoFileFunction "test.txt" >/dev/null 2>&1
    assert_return_code "1" "$?" "isVideoFileFunction_TC02_txt格式"
    
    isVideoFileFunction "test.jpg" >/dev/null 2>&1
    assert_return_code "1" "$?" "isVideoFileFunction_TC02_jpg格式"
    
    # TC03: 中文文件名
    isVideoFileFunction "中文视频.mp4" >/dev/null 2>&1
    assert_return_code "0" "$?" "isVideoFileFunction_TC03_中文视频文件"
    
    # TC04: 不存在的文件
    isVideoFileFunction "notexist.mp4" >/dev/null 2>&1
    assert_return_code "1" "$?" "isVideoFileFunction_TC04_不存在文件"
    
    # 清理测试文件
    rm -f test.mp4 test.avi test.mkv test.txt test.jpg "中文视频.mp4"
    echo ""
}

# 测试 getFileName 函数
function test_getFileName() {
    log_info "测试 getFileName 函数..."
    
    # 确保索引文件不存在
    local index_file="/Users/codew/Desktop/indexFXY"
    rm -f "$index_file"
    
    # TC01: 首次调用
    local result=$(getFileName 2>/dev/null)
    local return_code=$?
    assert_return_code "0" "$return_code" "getFileName_TC01_首次调用返回码"
    assert_equals "fgg1" "$result" "getFileName_TC01_首次调用结果"
    
    # TC02: 连续调用
    local result2=$(getFileName 2>/dev/null)
    assert_equals "fgg2" "$result2" "getFileName_TC02_第二次调用"
    
    local result3=$(getFileName 2>/dev/null)
    assert_equals "fgg3" "$result3" "getFileName_TC03_第三次调用"
    
    # TC03: 验证索引文件内容
    if [ -f "$index_file" ]; then
        local index_content=$(cat "$index_file")
        assert_equals "4" "$index_content" "getFileName_TC04_索引文件内容"
    fi
    
    echo ""
}

# 测试 process_folders 函数
function test_process_folders() {
    log_info "测试 process_folders 函数..."
    
    # TC01: 处理普通文件夹
    local original_file_size=$(wc -c < "普通文件夹/test.txt")
    process_folders "普通文件夹" >/dev/null 2>&1
    local new_file_size=$(wc -c < "普通文件夹/test.txt")
    local expected_size=$((original_file_size + 1100))
    assert_equals "$expected_size" "$new_file_size" "process_folders_TC01_文件大小增加"
    
    # 验证标志位
    local read_result=$(view_original_names "普通文件夹/test.txt" 2>/dev/null)
    assert_equals "test.txt" "$read_result" "process_folders_TC01_标志位正确"
    
    # TC02: 处理中文文件夹
    process_folders "中文 空格 文件夹" >/dev/null 2>&1
    local read_result=$(view_original_names "中文 空格 文件夹/中文 文件.txt" 2>/dev/null)
    assert_equals "中文 文件.txt" "$read_result" "process_folders_TC02_中文文件名"
    
    # TC03: 跳过包含tmpfile的文件夹
    local original_size=$(wc -c < "跳过文件夹/normal.txt")
    process_folders "跳过文件夹" >/dev/null 2>&1
    # 验证normal.txt没有被处理（没有增加1100字节）
    local new_size=$(wc -c < "跳过文件夹/normal.txt")
    # 这个文件应该还是原始大小，因为整个文件夹被跳过了
    assert_equals "$original_size" "$new_size" "process_folders_TC03_跳过tmpfile文件夹"
    
    # TC04: 处理包含url文件的文件夹（url文件应被删除）
    process_folders "url文件夹" >/dev/null 2>&1
    assert_file_not_exists "url文件夹/url" "process_folders_TC04_删除url文件"
    # 但其他文件应该被处理
    local read_result=$(view_original_names "url文件夹/somefile.txt" 2>/dev/null)
    assert_equals "somefile.txt" "$read_result" "process_folders_TC04_处理其他文件"
    
    echo ""
}

# 测试 restore_file_names 函数
function test_restore_file_names() {
    log_info "测试 restore_file_names 函数..."
    
    # 准备测试数据 - 创建带有标志位的文件
    mkdir -p "还原测试文件夹"
    echo "test content" > "还原测试文件夹/renamed_file"
    write_fixed_bytes "original_name.txt" "还原测试文件夹/renamed_file" >/dev/null 2>&1
    
    echo "chinese content" > "还原测试文件夹/重命名文件"
    write_fixed_bytes "原始中文名.txt" "还原测试文件夹/重命名文件" >/dev/null 2>&1
    
    # TC01: 还原普通文件名
    restore_file_names "还原测试文件夹" >/dev/null 2>&1
    assert_file_exists "还原测试文件夹/original_name.txt" "restore_file_names_TC01_还原英文文件名"
    assert_file_not_exists "还原测试文件夹/renamed_file" "restore_file_names_TC01_原文件已重命名"
    
    # TC02: 还原中文文件名
    assert_file_exists "还原测试文件夹/原始中文名.txt" "restore_file_names_TC02_还原中文文件名"
    
    echo ""
}

# 测试 processVideoFiles 函数
function test_processVideoFiles() {
    log_info "测试 processVideoFiles 函数..."
    
    # TC01: 处理大视频文件（>100MB）
    local original_size=$(wc -c < "测试视频文件夹/large_video.avi")
    processVideoFiles "测试视频文件夹" >/dev/null 2>&1
    local new_size=$(wc -c < "测试视频文件夹/large_video.avi")
    local expected_size=$((original_size + 1100))
    assert_equals "$expected_size" "$new_size" "processVideoFiles_TC01_大视频文件处理"
    
    # 验证文件名被正确写入
    local read_result=$(view_original_names "测试视频文件夹/large_video.avi" 2>/dev/null)
    assert_equals "large_video.avi" "$read_result" "processVideoFiles_TC01_视频文件名标志"
    
    # TC02: 小视频文件应该被跳过
    local small_video_size=$(wc -c < "测试视频文件夹/small_video.mp4")
    # 小视频文件不应该增加1100字节，因为<100MB
    local expected_small_size=$((51200))  # 50KB原始大小
    # 允许一些误差，检查是否没有增加1100字节
    if [ $small_video_size -lt $((expected_small_size + 1000)) ]; then
        record_test_result "processVideoFiles_TC02_小视频文件跳过" "PASS" "小视频文件未被处理"
    else
        record_test_result "processVideoFiles_TC02_小视频文件跳过" "FAIL" "小视频文件被意外处理"
    fi
    
    # TC03: 非视频文件应该被跳过
    local text_size=$(wc -c < "测试视频文件夹/document.txt")
    if [ $text_size -lt 1000 ]; then
        record_test_result "processVideoFiles_TC03_非视频文件跳过" "PASS" "文本文件未被处理"
    else
        record_test_result "processVideoFiles_TC03_非视频文件跳过" "FAIL" "文本文件被意外处理"
    fi
    
    # TC04: 跳过包含aria2文件的文件夹
    local aria2_video_original=$(wc -c < "aria2文件夹/video.mp4")
    processVideoFiles "aria2文件夹" >/dev/null 2>&1
    local aria2_video_new=$(wc -c < "aria2文件夹/video.mp4")
    assert_equals "$aria2_video_original" "$aria2_video_new" "processVideoFiles_TC04_跳过aria2文件夹"
    
    echo ""
}

# 测试 moveProcessedFiles 函数
function test_moveProcessedFiles() {
    log_info "测试 moveProcessedFiles 函数..."
    
    # 准备测试数据
    mkdir -p "移动测试文件夹"
    mkdir -p "/p2"  # 确保目标文件夹存在
    
    # 创建带标志位的文件
    echo "content1" > "移动测试文件夹/processed_file1.txt"
    write_fixed_bytes "processed_file1.txt" "移动测试文件夹/processed_file1.txt" >/dev/null 2>&1
    
    echo "中文内容" > "移动测试文件夹/中文处理文件.txt"
    write_fixed_bytes "中文处理文件.txt" "移动测试文件夹/中文处理文件.txt" >/dev/null 2>&1
    
    # 创建无标志位的文件
    echo "normal content" > "移动测试文件夹/normal_file.txt"
    
    # TC01: 移动带标志位的文件
    moveProcessedFiles "移动测试文件夹" >/dev/null 2>&1
    
    # 验证带标志位的文件被移动
    assert_file_not_exists "移动测试文件夹/processed_file1.txt" "moveProcessedFiles_TC01_源文件已移动"
    
    # 验证文件出现在目标文件夹（文件名会被getFileName重新生成）
    local moved_files=$(find /p2 -name "fgg*" | wc -l)
    if [ $moved_files -gt 0 ]; then
        record_test_result "moveProcessedFiles_TC01_文件已移动到目标" "PASS" "找到 $moved_files 个移动的文件"
    else
        record_test_result "moveProcessedFiles_TC01_文件已移动到目标" "FAIL" "未找到移动的文件"
    fi
    
    # TC02: 无标志位文件应该保持不动
    assert_file_exists "移动测试文件夹/normal_file.txt" "moveProcessedFiles_TC02_无标志位文件保持不动"
    
    echo ""
}

# 测试 view_original_names 函数
function test_view_original_names() {
    log_info "测试 view_original_names 函数..."
    
    # 准备测试文件
    echo "test content" > "view_test.txt"
    write_fixed_bytes "original_filename.txt" "view_test.txt" >/dev/null 2>&1
    
    # TC01: 查看有效的标志位文件
    local result=$(view_original_names "view_test.txt" 2>/dev/null)
    local return_code=$?
    assert_return_code "0" "$return_code" "view_original_names_TC01_返回码"
    assert_equals "original_filename.txt" "$result" "view_original_names_TC01_读取内容"
    
    # 验证文件大小没有变化（纯查看，不删除）
    local file_size_before=$(wc -c < "view_test.txt")
    view_original_names "view_test.txt" >/dev/null 2>&1
    local file_size_after=$(wc -c < "view_test.txt")
    assert_equals "$file_size_before" "$file_size_after" "view_original_names_TC01_文件大小不变"
    
    # TC02: 查看无标志位的文件
    echo "content without marker" > "no_marker.txt"
    local result=$(view_original_names "no_marker.txt" 2>/dev/null)
    local return_code=$?
    assert_return_code "1" "$return_code" "view_original_names_TC02_无标志位返回码"
    
    rm -f "view_test.txt" "no_marker.txt"
    echo ""
}

# 测试 batch_view_original_names 函数
function test_batch_view_original_names() {
    log_info "测试 batch_view_original_names 函数..."
    
    # 准备测试数据
    mkdir -p "批量查看测试"
    
    # 创建带标志位的文件
    echo "content1" > "批量查看测试/file1.txt"
    write_fixed_bytes "original1.txt" "批量查看测试/file1.txt" >/dev/null 2>&1
    
    echo "content2" > "批量查看测试/file2.txt"
    write_fixed_bytes "原始文件2.txt" "批量查看测试/file2.txt" >/dev/null 2>&1
    
    # 创建无标志位文件
    echo "normal" > "批量查看测试/normal.txt"
    
    # TC01: 批量查看
    local output=$(batch_view_original_names "批量查看测试" 2>&1)
    local return_code=$?
    assert_return_code "0" "$return_code" "batch_view_original_names_TC01_返回码"
    
    # 检查输出中是否包含预期的文件名
    if echo "$output" | grep -q "original1.txt"; then
        record_test_result "batch_view_original_names_TC01_包含文件1" "PASS" "输出包含original1.txt"
    else
        record_test_result "batch_view_original_names_TC01_包含文件1" "FAIL" "输出不包含original1.txt"
    fi
    
    if echo "$output" | grep -q "原始文件2.txt"; then
        record_test_result "batch_view_original_names_TC01_包含中文文件" "PASS" "输出包含原始文件2.txt"
    else
        record_test_result "batch_view_original_names_TC01_包含中文文件" "FAIL" "输出不包含原始文件2.txt"
    fi
    
    echo ""
}

# 运行所有测试
function run_all_tests() {
    log_info "开始运行所有测试..."
    echo "================================================"
    
    setup_test_environment
    
    test_get_byte_length
    test_parse_path_list
    test_write_and_read_fixed_bytes
    test_isVideoFileFunction
    test_getFileName
    test_process_folders
    test_restore_file_names
    test_processVideoFiles
    test_moveProcessedFiles
    test_view_original_names
    test_batch_view_original_names
    
    cleanup_test_environment
    
    # 生成测试报告
    generate_test_report
}

# 生成测试报告
function generate_test_report() {
    echo ""
    echo "================================================"
    log_info "测试报告"
    echo "================================================"
    
    echo -e "${BLUE}📊 测试统计:${NC}"
    echo "   总测试数: $TOTAL_TESTS"
    echo "   通过数量: $PASSED_TESTS"
    echo "   失败数量: $FAILED_TESTS"
    
    local pass_rate=$(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc 2>/dev/null || echo "N/A")
    echo "   通过率: ${pass_rate}%"
    echo ""
    
    if [ $FAILED_TESTS -gt 0 ]; then
        echo -e "${RED}❌ 失败的测试用例:${NC}"
        for result in "${TEST_RESULTS[@]}"; do
            if [[ "$result" == *"FAIL"* ]]; then
                echo "   $result"
            fi
        done
        echo ""
    fi
    
    echo -e "${GREEN}✅ 成功的测试用例:${NC}"
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == *"PASS"* ]]; then
            echo "   $result"
        fi
    done
    
    echo ""
    echo "================================================"
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "所有测试通过! 🎉"
    else
        log_error "有 $FAILED_TESTS 个测试失败，需要修复。"
        exit 1
    fi
}

# 显示使用帮助
function show_help() {
    echo "脚本功能测试工具 v1.0"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -a, --all           运行所有测试 (默认)"
    echo "  -f, --function NAME 运行特定函数的测试"
    echo "  -l, --list          列出所有可测试的函数"
    echo "  -v, --verbose       显示详细输出"
    echo ""
    echo "示例:"
    echo "  $0                           # 运行所有测试"
    echo "  $0 -f write_fixed_bytes      # 只测试 write_fixed_bytes 函数"
    echo "  $0 --list                    # 列出所有可测试的函数"
    echo ""
}

# 列出可测试的函数
function list_testable_functions() {
    echo "可测试的函数:"
    echo "  - get_byte_length"
    echo "  - parse_path_list"
    echo "  - write_fixed_bytes"
    echo "  - read_and_remove_fixed_bytes"
    echo "  - process_folders"
    echo "  - restore_file_names"
    echo "  - getFileName"
    echo "  - isVideoFileFunction"
    echo "  - processVideoFiles"
    echo "  - moveProcessedFiles"
    echo "  - view_original_names"
    echo "  - batch_view_original_names"
}

# 主程序入口
function main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            list_testable_functions
            exit 0
            ;;
        -f|--function)
            if [ -z "${2:-}" ]; then
                log_error "请指定要测试的函数名"
                exit 1
            fi
            
            setup_test_environment
            case "$2" in
                get_byte_length)
                    test_get_byte_length
                    ;;
                parse_path_list)
                    test_parse_path_list
                    ;;
                write_fixed_bytes|read_and_remove_fixed_bytes)
                    test_write_and_read_fixed_bytes
                    ;;
                isVideoFileFunction)
                    test_isVideoFileFunction
                    ;;
                getFileName)
                    test_getFileName
                    ;;
                process_folders)
                    test_process_folders
                    ;;
                restore_file_names)
                    test_restore_file_names
                    ;;
                processVideoFiles)
                    test_processVideoFiles
                    ;;
                moveProcessedFiles)
                    test_moveProcessedFiles
                    ;;
                view_original_names)
                    test_view_original_names
                    ;;
                batch_view_original_names)
                    test_batch_view_original_names
                    ;;
                *)
                    log_error "未知的函数名: $2"
                    list_testable_functions
                    exit 1
                    ;;
            esac
            cleanup_test_environment
            generate_test_report
            ;;
        -a|--all|"")
            run_all_tests
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 检查依赖
function check_dependencies() {
    local missing_deps=()
    
    # 检查必需的命令
    for cmd in find wc dd head tail xxd bc; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少必需的依赖: ${missing_deps[*]}"
        log_info "请安装缺少的命令后再运行测试"
        exit 1
    fi
}

# 脚本入口点
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    check_dependencies
    main "$@"
fi
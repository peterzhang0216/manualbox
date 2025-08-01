#!/bin/bash

# ManualBox 代码质量检查脚本
# 用于自动化代码质量检查和修复

echo "🔧 ManualBox 代码质量检查开始..."
echo "================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# 错误计数
ERROR_COUNT=0
WARNING_COUNT=0

# 函数：打印带颜色的消息
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 函数：检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_status $RED "❌ $1 未安装"
        return 1
    else
        print_status $GREEN "✅ $1 已安装"
        return 0
    fi
}

# 1. 检查必要工具
echo -e "\n${BLUE}📋 检查必要工具...${NC}"
check_command "swiftlint" || echo "请运行: brew install swiftlint"
check_command "xcodebuild"

# 2. SwiftLint 检查
echo -e "\n${BLUE}🔍 运行 SwiftLint 检查...${NC}"
if command -v swiftlint &> /dev/null; then
    swiftlint lint --reporter json > swiftlint_report.json 2>/dev/null
    
    if [ -f "swiftlint_report.json" ]; then
        # 统计错误和警告
        LINT_ERRORS=$(cat swiftlint_report.json | jq -r '.[] | select(.severity == "error") | .rule_id' | wc -l | tr -d ' ')
        LINT_WARNINGS=$(cat swiftlint_report.json | jq -r '.[] | select(.severity == "warning") | .rule_id' | wc -l | tr -d ' ')
        
        ERROR_COUNT=$((ERROR_COUNT + LINT_ERRORS))
        WARNING_COUNT=$((WARNING_COUNT + LINT_WARNINGS))
        
        if [ "$LINT_ERRORS" -gt 0 ]; then
            print_status $RED "❌ SwiftLint: $LINT_ERRORS 个错误"
        else
            print_status $GREEN "✅ SwiftLint: 无错误"
        fi
        
        if [ "$LINT_WARNINGS" -gt 0 ]; then
            print_status $YELLOW "⚠️  SwiftLint: $LINT_WARNINGS 个警告"
        fi
        
        # 显示前10个问题
        if [ "$LINT_ERRORS" -gt 0 ] || [ "$LINT_WARNINGS" -gt 0 ]; then
            echo -e "\n${YELLOW}📝 主要问题（前10个）:${NC}"
            cat swiftlint_report.json | jq -r '.[:10] | .[] | "• \(.file | split("/") | last):\(.line) - \(.reason)"'
        fi
        
        rm -f swiftlint_report.json
    fi
else
    print_status $YELLOW "⚠️  SwiftLint 未安装，跳过检查"
fi

# 3. 编译检查
echo -e "\n${BLUE}🔨 编译检查...${NC}"
BUILD_LOG=$(xcodebuild -project ManualBox.xcodeproj -scheme ManualBox -configuration Debug clean build 2>&1)
BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    print_status $GREEN "✅ 编译成功"
else
    print_status $RED "❌ 编译失败"
    ERROR_COUNT=$((ERROR_COUNT + 1))
    
    # 提取编译错误
    echo -e "\n${YELLOW}📝 编译错误:${NC}"
    echo "$BUILD_LOG" | grep -E "error:|warning:" | head -10
fi

# 4. 重复代码检查
echo -e "\n${BLUE}🔍 重复代码检查...${NC}"
DUPLICATE_STRUCTS=$(grep -r "struct SyncHistoryRow\|struct RecommendationRow" ManualBox/ --include="*.swift" | wc -l | tr -d ' ')
if [ "$DUPLICATE_STRUCTS" -gt 2 ]; then
    print_status $RED "❌ 发现重复结构体定义: $DUPLICATE_STRUCTS 个"
    ERROR_COUNT=$((ERROR_COUNT + 1))
    grep -r "struct SyncHistoryRow\|struct RecommendationRow" ManualBox/ --include="*.swift"
else
    print_status $GREEN "✅ 无重复结构体定义"
fi

# 5. 导入语句检查
echo -e "\n${BLUE}📦 导入语句检查...${NC}"
MISSING_IMPORTS=$(grep -r "ErrorContext\|RecoveryResult" ManualBox/ --include="*.swift" -l | wc -l | tr -d ' ')
if [ "$MISSING_IMPORTS" -gt 0 ]; then
    print_status $YELLOW "⚠️  可能需要更新导入语句的文件: $MISSING_IMPORTS 个"
    WARNING_COUNT=$((WARNING_COUNT + 1))
fi

# 6. 测试运行
echo -e "\n${BLUE}🧪 运行测试...${NC}"
TEST_LOG=$(xcodebuild test -project ManualBox.xcodeproj -scheme ManualBox -destination 'platform=macOS' 2>&1)
TEST_EXIT_CODE=$?

if [ $TEST_EXIT_CODE -eq 0 ]; then
    print_status $GREEN "✅ 所有测试通过"
else
    print_status $RED "❌ 测试失败"
    WARNING_COUNT=$((WARNING_COUNT + 1))
    
    # 提取测试失败信息
    echo "$TEST_LOG" | grep -E "FAIL|failed|error" | head -5
fi

# 7. 生成质量报告
echo -e "\n${BLUE}📊 生成质量报告...${NC}"

QUALITY_SCORE=100
QUALITY_SCORE=$((QUALITY_SCORE - ERROR_COUNT * 10))
QUALITY_SCORE=$((QUALITY_SCORE - WARNING_COUNT * 2))
QUALITY_SCORE=$((QUALITY_SCORE < 0 ? 0 : QUALITY_SCORE))

if [ $QUALITY_SCORE -ge 90 ]; then
    GRADE="A - 优秀"
    GRADE_COLOR=$GREEN
elif [ $QUALITY_SCORE -ge 80 ]; then
    GRADE="B - 良好"
    GRADE_COLOR=$BLUE
elif [ $QUALITY_SCORE -ge 70 ]; then
    GRADE="C - 一般"
    GRADE_COLOR=$YELLOW
else
    GRADE="D - 需要改进"
    GRADE_COLOR=$RED
fi

# 生成报告文件
REPORT_FILE="quality_report_$(date +%Y%m%d_%H%M%S).md"
cat > "$REPORT_FILE" << EOF
# ManualBox 代码质量报告

**生成时间**: $(date)
**质量评分**: $QUALITY_SCORE/100 ($GRADE)

## 📊 问题统计

- **错误**: $ERROR_COUNT 个
- **警告**: $WARNING_COUNT 个

## 🔍 检查项目

- ✅ SwiftLint 代码风格检查
- ✅ 编译错误检查  
- ✅ 重复代码检查
- ✅ 导入语句检查
- ✅ 单元测试执行

## 📋 改进建议

$(if [ $ERROR_COUNT -gt 0 ]; then echo "1. 🔴 优先修复 $ERROR_COUNT 个错误"; fi)
$(if [ $WARNING_COUNT -gt 0 ]; then echo "2. 🟡 处理 $WARNING_COUNT 个警告"; fi)
$(if [ $QUALITY_SCORE -lt 80 ]; then echo "3. 📈 整体质量需要提升"; fi)

---
生成工具: ManualBox Quality Check Script
EOF

# 8. 最终报告
echo -e "\n${BLUE}📈 质量检查完成!${NC}"
echo "================================="
print_status $GRADE_COLOR "🎯 质量评分: $QUALITY_SCORE/100 ($GRADE)"
echo -e "${YELLOW}📋 问题统计:${NC}"
echo "   • 错误: $ERROR_COUNT 个"
echo "   • 警告: $WARNING_COUNT 个"
echo -e "${BLUE}📄 详细报告已保存到: $REPORT_FILE${NC}"

# 设置退出码
if [ $ERROR_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi

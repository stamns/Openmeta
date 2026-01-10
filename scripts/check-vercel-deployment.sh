#!/bin/bash

# Vercel 部署前检查脚本
# 验证所有必要的文件和配置是否正确

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 计数器
PASS=0
FAIL=0
WARN=0

print_pass() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASS++))
}

print_fail() {
    echo -e "${RED}✗ $1${NC}"
    ((FAIL++))
}

print_warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARN++))
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 检查文件是否存在
check_file() {
    if [ -f "$1" ]; then
        print_pass "$1"
    else
        print_fail "$1"
    fi
}

# 检查目录是否存在
check_dir() {
    if [ -d "$1" ]; then
        print_pass "$1"
    else
        print_fail "$1"
    fi
}

# 验证 JSON
check_json() {
    if python3 -m json.tool "$1" > /dev/null 2>&1; then
        print_pass "$1: JSON 格式有效"
    else
        print_fail "$1: JSON 格式无效"
    fi
}

# 检查 Git 状态
check_git() {
    if command -v git &> /dev/null; then
        print_pass "Git 已安装"
    else
        print_fail "Git 未安装"
        return
    fi

    if git rev-parse --git-dir > /dev/null 2>&1; then
        print_pass "Git 仓库初始化"
    else
        print_fail "Git 仓库未初始化"
    fi
}

# 主检查流程
main() {
    print_header "Vercel 部署前检查清单"

    echo "项目结构检查："
    check_file "vercel.json"
    check_file "requirements.txt"
    check_file ".gitignore"
    check_file ".env.example"
    check_file "backend/api/index.py"
    check_file "backend/app/main.py"
    check_file "backend/app/settings.py"
    check_file "backend/app/services/pansou.py"
    check_dir "frontend/src"
    check_file "frontend/package.json"
    check_file "frontend/vite.config.js"
    check_file "frontend/index.html"

    echo ""
    echo "配置文件验证："
    check_json "vercel.json"
    check_json "frontend/package.json"

    echo ""
    echo "文档检查："
    check_file "README.md"
    check_file "docs/vercel-deployment.md"
    check_file "docs/frontend-deployment.md"
    check_file ".env.example"

    echo ""
    echo "脚本检查："
    check_file "scripts/deploy-vercel.sh"
    check_file "scripts/check-vercel-deployment.sh"

    # 检查脚本权限
    if [ -x "scripts/deploy-vercel.sh" ]; then
        print_pass "scripts/deploy-vercel.sh 可执行"
    else
        print_fail "scripts/deploy-vercel.sh 不可执行"
    fi

    if [ -x "scripts/check-vercel-deployment.sh" ]; then
        print_pass "scripts/check-vercel-deployment.sh 可执行"
    else
        print_fail "scripts/check-vercel-deployment.sh 不可执行"
    fi

    echo ""
    echo "Git 状态："
    check_git

    echo ""
    echo "Vercel 配置验证："

    # 检查 vercel.json 关键配置
    if grep -q '"backend/api/index.py"' vercel.json; then
        print_pass "vercel.json 包含 Python 函数配置"
    else
        print_fail "vercel.json 缺少 Python 函数配置"
    fi

    if grep -q '"frontend/package.json"' vercel.json; then
        print_pass "vercel.json 包含前端构建配置"
    else
        print_fail "vercel.json 缺少前端构建配置"
    fi

    if grep -q '"/api/(.*)"' vercel.json; then
        print_pass "vercel.json 包含 API 路由配置"
    else
        print_fail "vercel.json 缺少 API 路由配置"
    fi

    if grep -q '"/health"' vercel.json; then
        print_pass "vercel.json 包含健康检查路由配置"
    else
        print_fail "vercel.json 缺少健康检查路由配置"
    fi

    if grep -q 'maxDuration' vercel.json; then
        print_pass "vercel.json 包含函数超时配置"
    else
        print_warn "vercel.json 未配置函数超时（建议设置 maxDuration）"
    fi

    echo ""
    print_header "检查结果汇总"

    echo -e "${GREEN}通过: $PASS${NC}"
    echo -e "${RED}失败: $FAIL${NC}"
    echo -e "${YELLOW}警告: $WARN${NC}"

    if [ $FAIL -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ 所有必需检查通过！可以开始部署。${NC}"
        echo ""
        echo "下一步："
        echo "  1. 在 Vercel Dashboard 中配置环境变量"
        echo "  2. 运行部署脚本: ./scripts/deploy-vercel.sh"
        echo "  3. 或推送代码到 GitHub 触发自动部署"
        return 0
    else
        echo ""
        echo -e "${RED}❌ 发现 $FAIL 个问题，请修复后重试。${NC}"
        return 1
    fi
}

# 运行主函数
main

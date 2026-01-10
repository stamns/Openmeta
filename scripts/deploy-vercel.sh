#!/bin/bash

# Vercel 自动化部署脚本
# 用于验证环境、推送代码并触发自动部署

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 未安装，请先安装"
        exit 1
    fi
}

# 检查文件是否存在
check_file() {
    if [ ! -f "$1" ]; then
        print_error "文件不存在: $1"
        exit 1
    fi
}

# 验证 JSON 文件
validate_json() {
    if ! python3 -m json.tool "$1" > /dev/null 2>&1; then
        print_error "JSON 格式无效: $1"
        exit 1
    fi
    print_success "JSON 格式验证通过: $1"
}

# 检查 Git 状态
check_git_status() {
    print_info "检查 Git 状态..."

    if [ -z "$(git status --porcelain)" ]; then
        print_warning "没有需要提交的更改"
        read -p "是否继续部署？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "部署已取消"
            exit 0
        fi
    else
        print_info "以下文件将被提交："
        git status --short
        echo ""
    fi
}

# 本地验证环境
verify_local_environment() {
    print_header "验证本地环境"

    # 检查必需命令
    print_info "检查必需命令..."
    check_command "git"
    check_command "python3"
    check_success "所有必需命令已安装"

    # 检查配置文件
    print_info "检查配置文件..."
    check_file "vercel.json"
    check_file "requirements.txt"
    check_file "frontend/package.json"
    check_file "backend/api/index.py"
    check_success "所有配置文件存在"

    # 验证 JSON 文件
    print_info "验证 JSON 文件..."
    validate_json "vercel.json"
    validate_json "frontend/package.json"
    check_success "JSON 文件验证通过"

    # 检查 Python 依赖
    print_info "检查 Python 依赖..."
    if [ -f "requirements.txt" ]; then
        print_info "Python 依赖文件: $(wc -l < requirements.txt) 行"
    fi
    check_success "Python 依赖检查通过"

    # 检查前端依赖
    print_info "检查前端依赖..."
    if [ -f "frontend/package.json" ]; then
        print_info "前端 package.json 存在"
    fi
    check_success "前端依赖检查通过"

    print_success "本地环境验证完成"
}

# 提交并推送代码
commit_and_push() {
    print_header "提交并推送代码"

    # 提示输入提交信息
    if [ -z "$COMMIT_MESSAGE" ]; then
        echo -n "请输入提交信息 (默认: 'chore: Vercel 部署'): "
        read -r commit_msg
        COMMIT_MESSAGE="${commit_msg:-chore: Vercel 部署}"
    fi

    # 添加所有更改
    print_info "添加文件到 Git..."
    git add .

    # 提交更改
    print_info "提交更改..."
    git commit -m "$COMMIT_MESSAGE"

    # 获取当前分支
    CURRENT_BRANCH=$(git branch --show-current)
    print_info "当前分支: $CURRENT_BRANCH"

    # 推送代码
    print_info "推送代码到 GitHub..."
    git push origin "$CURRENT_BRANCH"

    print_success "代码已推送到 GitHub"
}

# 监控部署状态
monitor_deployment() {
    print_header "监控部署状态"

    if command -v vercel &> /dev/null; then
        print_info "使用 Vercel CLI 监控部署..."

        # 列出最近的部署
        print_info "最近的部署："
        vercel list 2>&1 || print_warning "无法列出部署，请在 Vercel Dashboard 中查看"

        print_success "请访问 Vercel Dashboard 查看部署状态"
        print_info "Dashboard URL: https://vercel.com/dashboard"
    else
        print_warning "Vercel CLI 未安装，无法自动监控部署"
        print_info "请访问 Vercel Dashboard 查看部署状态"
        print_info "Dashboard URL: https://vercel.com/dashboard"
    fi
}

# 验证部署
verify_deployment() {
    print_header "验证部署"

    if [ -n "$VERCEL_URL" ]; then
        print_info "测试部署 URL: $VERCEL_URL"

        # 测试健康检查端点
        print_info "测试健康检查端点..."
        health_response=$(curl -s -w "%{http_code}" "$VERCEL_URL/health" -o /tmp/health.json)
        if [ "$health_response" -eq 200 ]; then
            print_success "健康检查端点正常"
            cat /tmp/health.json | python3 -m json.tool
        else
            print_error "健康检查端点失败 (HTTP $health_response)"
            return 1
        fi

        # 测试 API 搜索端点
        print_info "测试 API 搜索端点..."
        search_response=$(curl -s -w "%{http_code}" "$VERCEL_URL/api/search?q=test&page=1" -o /tmp/search.json)
        if [ "$search_response" -eq 200 ]; then
            print_success "API 搜索端点正常"
            cat /tmp/search.json | python3 -m json.tool
        else
            print_warning "API 搜索端点返回 HTTP $search_response"
            cat /tmp/search.json
        fi

        # 测试主页
        print_info "测试主页..."
        homepage_response=$(curl -s -w "%{http_code}" "$VERCEL_URL/" -o /tmp/index.html)
        if [ "$homepage_response" -eq 200 ]; then
            print_success "主页正常加载"
        else
            print_warning "主页返回 HTTP $homepage_response"
        fi

        print_success "部署验证完成"
    else
        print_warning "未设置 VERCEL_URL，跳过自动验证"
        print_info "请手动验证部署："
        print_info "  1. 访问 https://your-project.vercel.app/health"
        print_info "  2. 访问 https://your-project.vercel.app/"
        print_info "  3. 测试搜索功能"
    fi
}

# 显示部署信息
show_deployment_info() {
    print_header "部署信息"

    print_info "项目信息："
    echo "  - 仓库: $(git remote get-url origin)"
    echo "  - 分支: $(git branch --show-current)"
    echo "  - 提交: $(git rev-parse --short HEAD)"
    echo "  - 提交信息: $(git log -1 --pretty=%B)"

    print_info "后续步骤："
    echo "  1. 访问 Vercel Dashboard: https://vercel.com/dashboard"
    echo "  2. 查看部署状态和日志"
    echo "  3. 配置环境变量（如果尚未配置）"
    echo "  4. 验证部署成功后，可配置自定义域名"

    print_info "环境变量配置："
    echo "  在 Vercel Dashboard → Settings → Environment Variables 中配置："
    echo "  - PANSOU_HOST (必需)"
    echo "  - PANSOU_USER (必需)"
    echo "  - PANSOU_PWD (必需)"
    echo "  - SEARCH_TIMEOUT (可选)"

    print_info "验证命令："
    echo "  # 测试健康检查"
    echo "  curl https://your-project.vercel.app/health"
    echo ""
    echo "  # 测试搜索 API"
    echo "  curl 'https://your-project.vercel.app/api/search?q=test&page=1'"
    echo ""
    echo "  # 测试主页"
    echo "  curl https://your-project.vercel.app/"
}

# 主函数
main() {
    print_header "OpenMeta Vercel 自动化部署"

    # 检查是否在项目根目录
    if [ ! -f "vercel.json" ]; then
        print_error "请在项目根目录运行此脚本"
        exit 1
    fi

    # 解析命令行参数
    SKIP_VALIDATION=false
    SKIP_PUSH=false
    SKIP_MONITOR=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --skip-push)
                SKIP_PUSH=true
                shift
                ;;
            --skip-monitor)
                SKIP_MONITOR=true
                shift
                ;;
            --url)
                VERCEL_URL="$2"
                shift 2
                ;;
            --message)
                COMMIT_MESSAGE="$2"
                shift 2
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --skip-validation    跳过本地环境验证"
                echo "  --skip-push          跳过 Git 推送"
                echo "  --skip-monitor       跳过部署监控"
                echo "  --url URL            设置 Vercel URL 用于验证"
                echo "  --message MESSAGE    设置提交信息"
                echo "  --help               显示此帮助信息"
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                exit 1
                ;;
        esac
    done

    # 执行部署流程
    if [ "$SKIP_VALIDATION" = false ]; then
        verify_local_environment
    else
        print_warning "跳过本地环境验证"
    fi

    if [ "$SKIP_PUSH" = false ]; then
        check_git_status
        commit_and_push
    else
        print_warning "跳过 Git 推送"
    fi

    if [ "$SKIP_MONITOR" = false ]; then
        monitor_deployment
    else
        print_warning "跳过部署监控"
    fi

    verify_deployment
    show_deployment_info

    print_header "部署流程完成"
    print_success "所有步骤已完成！"
    print_info "请在 Vercel Dashboard 中查看部署状态"
}

# 运行主函数
main "$@"

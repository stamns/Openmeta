#!/bin/bash

################################################################################
# Vercel 部署自动化脚本
# 功能：
#   1. 本地环境验证
#   2. 代码检查
#   3. 推送到 GitHub（触发自动部署）
#   4. 监控部署状态
################################################################################

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查 Git 仓库状态
check_git_status() {
    log_info "检查 Git 仓库状态..."

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "不是 Git 仓库"
        exit 1
    fi

    # 检查是否有未提交的更改
    if ! git diff-index --quiet HEAD --; then
        log_warning "检测到未提交的更改"
        git status --short
        read -p "是否继续部署？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "部署取消"
            exit 0
        fi
    fi

    log_success "Git 仓库状态正常"
}

# 检查环境变量
check_env_vars() {
    log_info "检查环境变量..."

    # 检查本地 .env 文件（仅用于验证）
    if [ -f ".env" ]; then
        source .env

        if [ -z "$PANSOU_HOST" ] || [ -z "$PANSOU_USER" ] || [ -z "$PANSOU_PWD" ]; then
            log_warning "本地 .env 文件缺少必需的环境变量"
            log_info "请确保在 Vercel Dashboard 中配置了以下环境变量："
            echo "  - PANSOU_HOST"
            echo "  - PANSOU_USER"
            echo "  - PANSOU_PWD"
        else
            log_success "本地环境变量已配置"
        fi
    else
        log_warning "未找到 .env 文件（本地开发不需要，但请确保 Vercel 已配置）"
    fi
}

# 验证配置文件
validate_configs() {
    log_info "验证配置文件..."

    # 检查 vercel.json
    if [ -f "vercel.json" ]; then
        if python3 -m json.tool vercel.json >/dev/null 2>&1; then
            log_success "vercel.json 语法正确"
        else
            log_error "vercel.json 语法错误"
            exit 1
        fi
    else
        log_error "未找到 vercel.json"
        exit 1
    fi

    # 检查 frontend/package.json
    if [ -f "frontend/package.json" ]; then
        if python3 -m json.tool frontend/package.json >/dev/null 2>&1; then
            log_success "frontend/package.json 语法正确"
        else
            log_error "frontend/package.json 语法错误"
            exit 1
        fi
    else
        log_error "未找到 frontend/package.json"
        exit 1
    fi

    # 检查 backend/requirements.txt
    if [ ! -f "backend/requirements.txt" ]; then
        log_error "未找到 backend/requirements.txt"
        exit 1
    fi
    log_success "backend/requirements.txt 存在"
}

# 本地构建测试
local_build_test() {
    log_info "执行本地构建测试..."

    # 测试前端构建
    log_info "构建前端..."
    cd frontend
    if command_exists npm; then
        npm install
        npm run build
        if [ -d "dist" ]; then
            log_success "前端构建成功"
        else
            log_error "前端构建失败"
            exit 1
        fi
    else
        log_warning "npm 未安装，跳过前端构建测试"
    fi
    cd ..

    # 测试 Python 导入
    log_info "测试 Python 导入..."
    cd backend
    if python3 -c "from app.main import app" 2>/dev/null; then
        log_success "Python 导入测试通过"
    else
        log_error "Python 导入测试失败"
        exit 1
    fi
    cd ..
}

# 推送到 GitHub
push_to_github() {
    log_info "推送到 GitHub..."

    # 获取当前分支
    CURRENT_BRANCH=$(git branch --show-current)

    log_info "当前分支: $CURRENT_BRANCH"

    # 推送代码
    git push origin "$CURRENT_BRANCH"

    log_success "代码已推送到 GitHub"
}

# 监控 Vercel 部署
monitor_deployment() {
    log_info "监控 Vercel 部署..."

    if ! command_exists vercel; then
        log_warning "Vercel CLI 未安装，跳过部署监控"
        log_info "请访问 Vercel Dashboard 查看部署状态"
        return
    fi

    # 获取部署 URL
    log_info "获取部署信息..."
    DEPLOYMENT_INFO=$(vercel ls 2>/dev/null | head -n 5)
    echo "$DEPLOYMENT_INFO"

    log_info "部署已触发，请访问 Vercel Dashboard 查看详细状态"
    log_info "https://vercel.com/dashboard"
}

# 部署后验证
post_deployment_check() {
    log_info "部署后验证..."

    # 提示用户手动验证
    echo ""
    log_info "请手动验证以下端点："
    echo "  1. 前端页面: https://your-project.vercel.app/"
    echo "  2. 健康检查: https://your-project.vercel.app/health"
    echo "  3. 搜索功能: https://your-project.vercel.app/api/search?q=test"
    echo ""
    read -p "是否需要打开浏览器验证？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 尝试打开浏览器（如果可用）
        if command_exists xdg-open; then
            xdg-open "https://your-project.vercel.app" 2>/dev/null || true
        elif command_exists open; then
            open "https://your-project.vercel.app" 2>/dev/null || true
        else
            log_info "请手动在浏览器中打开 URL"
        fi
    fi
}

# 主函数
main() {
    echo ""
    echo "======================================"
    echo "   Vercel 部署自动化脚本"
    echo "======================================"
    echo ""

    # 1. 检查 Git 状态
    check_git_status

    # 2. 检查环境变量
    check_env_vars

    # 3. 验证配置文件
    validate_configs

    # 4. 本地构建测试
    local_build_test

    # 5. 推送到 GitHub
    push_to_github

    # 6. 监控部署
    monitor_deployment

    # 7. 部署后验证
    post_deployment_check

    echo ""
    log_success "部署流程完成！"
    echo ""
    log_info "下一步："
    echo "  1. 访问 Vercel Dashboard 查看部署状态"
    echo "  2. 等待部署完成后测试应用程序"
    echo "  3. 查看日志以排查问题（如有）"
    echo ""
}

# 执行主函数
main "$@"

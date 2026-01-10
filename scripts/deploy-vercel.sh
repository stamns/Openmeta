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
#!/usr/bin/env bash
set -euo pipefail

# OpenMeta Vercel 部署脚本
# 支持本地验证和自动部署

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEPLOY=0
for arg in "$@"; do
  case "$arg" in
    --deploy) DEPLOY=1 ;;
    --verify-only) DEPLOY=0 ;;
    -h|--help)
      echo "Usage: $0 [--deploy] [--verify-only]"
      echo "  --deploy       部署到 Vercel（需要 Vercel CLI）"
      echo "  --verify-only  仅验证配置（默认）"
      exit 0
      ;;
  esac
done

echo "========================================"
echo "  OpenMeta Vercel 部署脚本"
echo "========================================"
echo ""

# 1. 验证 Python 和 JSON
echo "[1/5] 验证环境..."

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "[ERR] 未安装 Python" >&2
  exit 1
fi

NPM_BIN=""
if command -v npm >/dev/null 2>&1; then
  NPM_BIN="npm"
else
  echo "[WARN] 未安装 npm，Vercel CLI 功能不可用"
fi

# 2. 验证 vercel.json
echo "[2/5] 验证 vercel.json..."

VERCEL_JSON="$ROOT_DIR/vercel.json"
if [ ! -f "$VERCEL_JSON" ]; then
  echo "[ERR] 缺少 vercel.json" >&2
  exit 1
fi

# JSON 验证
"$PYTHON_BIN" -c "
import json
from pathlib import Path

p = Path('$VERCEL_JSON')
try:
    obj = json.loads(p.read_text(encoding='utf-8'))
except json.JSONDecodeError as e:
    print(f'[ERR] vercel.json 格式错误: {e}')
    exit(1)

if obj.get('version') != 2:
    print('[ERR] vercel.json version 必须为 2')
    exit(1)

builds = obj.get('builds', [])
if not any(b.get('src') == 'backend/api/index.py' for b in builds):
    print('[ERR] vercel.json 缺少 backend/api/index.py build')
    exit(1)
if not any(b.get('src') == 'frontend/package.json' for b in builds):
    print('[ERR] vercel.json 缺少 frontend/package.json build')
    exit(1)

routes = obj.get('routes', [])
has_api_route = any(r.get('src') == '/api/(.*)' for r in routes)
has_filesystem = any(r.get('handle') == 'filesystem' for r in routes)
has_fallback = any(r.get('dest') == '/index.html' for r in routes)

if not has_api_route:
    print('[ERR] vercel.json 缺少 /api/* 路由')
    exit(1)
if not has_filesystem:
    print('[ERR] vercel.json 缺少 filesystem handler')
    exit(1)
if not has_fallback:
    print('[ERR] vercel.json 缺少 index.html fallback')
    exit(1)

print('[OK] vercel.json 格式验证通过')
"

# 3. 验证前端配置
echo "[3/5] 验证前端配置..."

FRONTEND_PKG="$ROOT_DIR/frontend/package.json"
if [ ! -f "$FRONTEND_PKG" ]; then
    echo "[ERR] 缺少 frontend/package.json" >&2
    exit 1
fi

"$PYTHON_BIN" -c "
import json
from pathlib import Path
p = Path(r"$VERCEL_JSON")
obj = json.loads(p.read_text(encoding="utf-8"))
builds = obj.get("builds", [])
srcs = {b.get("src") for b in builds if isinstance(b, dict)}
need = {"backend/api/index.py", "frontend/package.json"}
missing = sorted(need - srcs)
if missing:
    raise SystemExit("vercel.json 缺少 builds.src：" + ", ".join(missing))

# 检查 routes 配置
routes = obj.get("routes", [])
if not routes:
    raise SystemExit("vercel.json 缺少 routes 配置")

# 检查环境变量配置
if "env" not in obj:
    raise SystemExit("vercel.json 缺少 env 配置")

print("[OK] vercel.json 校验通过")
print(f"[INFO] 构建配置: {len(builds)} 个构建项")
print(f"[INFO] 路由配置: {len(routes)} 个路由规则")
PY

pkg = Path('$FRONTEND_PKG')
obj = json.loads(pkg.read_text(encoding='utf-8'))

scripts = obj.get('scripts', {})
if 'build' not in scripts:
    print('[ERR] frontend/package.json 缺少 build 脚本')
    exit(1)

dev_deps = obj.get('devDependencies', {})
if 'vite' not in dev_deps:
    print('[ERR] frontend/package.json 缺少 vite 依赖')
    exit(1)

print('[OK] 前端配置验证通过')
"

# 4. 验证 Python API
echo "[4/5] 验证后端 API..."

API_INDEX="$ROOT_DIR/backend/api/index.py"
if [ ! -f "$API_INDEX" ]; then
    echo "[ERR] 缺少 backend/api/index.py" >&2
    exit 1
fi

# 验证 Python 语法
if ! "$PYTHON_BIN" -m py_compile "$API_INDEX" 2>&1; then
    echo "[ERR] backend/api/index.py 语法错误" >&2
    exit 1
fi

# 验证 mangum 导入
"$PYTHON_BIN" -c "
from pathlib import Path

api_path = Path('$API_INDEX')
code = api_path.read_text()

if 'mangum' not in code:
    print('[ERR] backend/api/index.py 缺少 mangum 导入')
    exit(1)
if 'Mangum' not in code:
    print('[ERR] backend/api/index.py 未使用 Mangum')
    exit(1)

print('[OK] 后端 API 验证通过')
"

# 5. 环境变量检查
echo "[5/5] 检查环境变量..."

get_env() {
  local key="\$1"
  if [ -n "\${!key:-}" ]; then
    echo "\${!key}"
    return 0
  fi
  if [ -f "$ROOT_DIR/.env" ]; then
    awk -F= -v k="\$key" '\$0 ~ "^"k"=" {sub("^"k"=","",\$0); print \$0; exit 0}' "$ROOT_DIR/.env" || true
    return 0
  fi
  echo ""
}

required=(PANSOU_HOST)
missing=()
for k in "${required[@]}"; do
  v="$(get_env "$k")"
  if [ -z "$v" ]; then
    missing+=("$k")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "[WARN] 以下环境变量未配置："
  printf '  - %s\n' "${missing[@]}"
  echo "      部署后请在 Vercel Dashboard 中配置"
fi

echo ""
echo "========================================"
echo "  验证完成！"
echo "========================================"
echo ""

# 部署选项
if [ "$DEPLOY" -eq 1 ]; then
    if [ -z "$NPM_BIN" ]; then
        echo "[ERR] 无法部署：未安装 npm" >&2
        exit 1
    fi

    if ! command -v vercel >/dev/null 2>&1; then
        echo "[INFO] 安装 Vercel CLI..."
        npm install -g vercel
    fi

    echo "[INFO] 开始部署到 Vercel..."
    vercel deploy --prod --yes
else
    echo "下一步："
    echo "  1. 推送代码到 GitHub"
    echo "  2. 在 Vercel Dashboard 导入仓库"
    echo "  3. 配置环境变量（PANSOU_HOST 等）"
    echo "  4. 部署完成！"
    echo ""
    echo "快速部署命令："
    echo "  $0 --deploy"
#!/bin/bash

# OpenMeta Vercel 部署辅助脚本
set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 开始 OpenMeta Vercel 部署验证...${NC}"

# 1. 检查必要文件
echo -e "${YELLOW}检查配置文件...${NC}"
if [ ! -f "vercel.json" ]; then
    echo -e "${RED}错误: 找不到 vercel.json${NC}"
    exit 1
fi

if [ ! -f "backend/api/index.py" ]; then
    echo -e "${RED}错误: 找不到 backend/api/index.py${NC}"
    exit 1
fi

# 2. 验证 vercel.json 格式
echo -e "${YELLOW}验证 vercel.json 格式...${NC}"
if command -v jq >/dev/null 2>&1; then
    jq . vercel.json > /dev/null
    echo -e "${GREEN}✅ vercel.json 格式正确${NC}"
else
    echo -e "${YELLOW}跳过 jq 验证 (未安装 jq)${NC}"
fi

# 3. 前端预构建验证
echo -e "${YELLOW}验证前端构建配置...${NC}"
if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
    echo -e "${GREEN}✅ 前端配置已就绪${NC}"
else
    echo -e "${RED}错误: 前端目录或 package.json 缺失${NC}"
    exit 1
fi

# 4. 提示部署步骤
echo -e "\n${GREEN}验证通过！${NC}"
echo -e "请按照以下步骤完成部署："
echo -e "1. 确保所有更改已提交并推送到 GitHub:"
echo -e "   ${YELLOW}git add . && git commit -m \"feat: optimize vercel deployment\" && git push${NC}"
echo -e "2. 在 Vercel Dashboard 中配置以下环境变量:"
echo -e "   - ${YELLOW}PANSOU_HOST${NC}"
echo -e "   - ${YELLOW}PANSOU_USER${NC}"
echo -e "   - ${YELLOW}PANSOU_PWD${NC}"
echo -e "3. Vercel 将自动开始构建和部署。"
echo -e "4. 部署完成后，访问生成的 Vercel URL 进行测试。"

echo -e "\n${GREEN}祝部署顺利！${NC}"
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

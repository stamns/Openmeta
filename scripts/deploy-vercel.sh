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
fi

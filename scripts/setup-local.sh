#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-$ROOT_DIR/.venv}"

NO_START=0
for arg in "$@"; do
  case "$arg" in
    --no-start) NO_START=1 ;;
  esac
done

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "[ERR] 找不到 Python，可通过 PYTHON_BIN 指定，例如：PYTHON_BIN=python3" >&2
  exit 1
fi

"$PYTHON_BIN" - <<'PY'
import sys
major, minor = sys.version_info[:2]
if (major, minor) < (3, 9):
    raise SystemExit(f"Python 版本需 >= 3.9，当前：{major}.{minor}")
print(f"[OK] Python {major}.{minor}")
PY

if [ ! -d "$VENV_DIR" ]; then
  echo "[INFO] 创建虚拟环境：$VENV_DIR"
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"

python -m pip install --upgrade pip >/dev/null

REQ_FILE="$ROOT_DIR/backend/requirements.txt"
if [ -f "$REQ_FILE" ]; then
  echo "[INFO] 安装依赖：$REQ_FILE"
  pip install -r "$REQ_FILE"
else
  echo "[ERR] 未找到依赖文件：$REQ_FILE" >&2
  exit 1
fi

if [ ! -f "$ROOT_DIR/.env" ]; then
  if [ -f "$ROOT_DIR/.env.example" ]; then
    echo "[INFO] 生成 .env（从 .env.example 复制）"
    cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  else
    echo "[ERR] 缺少 .env.example，无法生成 .env" >&2
    exit 1
  fi
fi

if [ "$NO_START" -eq 1 ]; then
  echo "[OK] 初始化完成（未启动服务：--no-start）"
  exit 0
fi

get_env_from_file() {
  local key="$1"
  local file="$2"
  awk -F= -v k="$key" '$0 ~ "^"k"=" {sub("^"k"=","",$0); print $0; exit 0}' "$file" 2>/dev/null || true
}

APP_MODULE="${APP_MODULE:-backend.app.main:app}"
HOST="${BACKEND_HOST:-$(get_env_from_file BACKEND_HOST "$ROOT_DIR/.env")}"; HOST="${HOST:-0.0.0.0}"
PORT="${BACKEND_PORT:-$(get_env_from_file BACKEND_PORT "$ROOT_DIR/.env")}"; PORT="${PORT:-8000}"

python -c "import importlib; importlib.import_module('${APP_MODULE%:*}')" >/dev/null 2>&1 || {
  echo "[ERR] 无法导入 APP_MODULE=$APP_MODULE，请确认后端入口存在。" >&2
  echo "      你可以通过 APP_MODULE=xxx.yyy:app 覆盖入口，例如：APP_MODULE=backend.app.main:app" >&2
  exit 1
}

echo "[OK] 后端即将启动："
echo "     API Base： http://127.0.0.1:${PORT}"
echo "     健康检查： curl http://127.0.0.1:${PORT}/health"
echo "     搜索演示： curl 'http://127.0.0.1:${PORT}/api/search?q=%E4%B8%89%E4%BD%93'"
echo
echo "[TIP] 前端（Vue3）本地开发："
echo "     cd frontend && npm install && npm run dev"
echo "     打开： http://127.0.0.1:5173"

exec python -m uvicorn "$APP_MODULE" --reload --host "$HOST" --port "$PORT"

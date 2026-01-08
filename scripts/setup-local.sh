#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-$ROOT_DIR/.venv}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "[ERR] 找不到 Python，可通过 PYTHON_BIN 指定，例如：PYTHON_BIN=python" >&2
  exit 1
fi

NO_START=0
for arg in "$@"; do
  case "$arg" in
    --no-start) NO_START=1 ;;
  esac
done

if [ ! -d "$VENV_DIR" ]; then
  echo "[INFO] 创建虚拟环境：$VENV_DIR"
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"

python -m pip install --upgrade pip >/dev/null

REQ_FILE=""
if [ -f "$ROOT_DIR/backend/requirements.txt" ]; then
  REQ_FILE="$ROOT_DIR/backend/requirements.txt"
elif [ -f "$ROOT_DIR/requirements.txt" ]; then
  REQ_FILE="$ROOT_DIR/requirements.txt"
fi

if [ -n "$REQ_FILE" ]; then
  echo "[INFO] 安装依赖：$REQ_FILE"
  pip install -r "$REQ_FILE"
else
  echo "[WARN] 未找到 requirements.txt（已跳过依赖安装）" >&2
fi

if [ ! -f "$ROOT_DIR/.env" ]; then
  if [ -f "$ROOT_DIR/.env.example" ]; then
    echo "[INFO] 生成 .env（从 .env.example 复制）"
    cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  else
    echo "[INFO] 生成 .env（模板缺失，写入最小配置）"
    cat > "$ROOT_DIR/.env" <<'EOF'
PANSOU_HOST=http://112.124.53.114:8888
PANSOU_USER=admin
PANSOU_PWD=
LOG_LEVEL=INFO
RATE_LIMIT_PER_MINUTE=10
SEARCH_TIMEOUT=15
EOF
  fi
fi

if [ "$NO_START" -eq 1 ]; then
  echo "[INFO] 初始化完成（未启动服务：--no-start）"
  exit 0
fi

APP_MODULE="${APP_MODULE:-backend.app.main:app}"
HOST="${BACKEND_HOST:-0.0.0.0}"
PORT="${BACKEND_PORT:-8000}"

python -c "import importlib; importlib.import_module('${APP_MODULE%:*}')" >/dev/null 2>&1 || {
  echo "[ERR] 无法导入 APP_MODULE=$APP_MODULE，请确认后端入口存在。" >&2
  echo "      你可以通过 APP_MODULE=xxx.yyy:app 覆盖入口，例如：APP_MODULE=app.main:app" >&2
  exit 1
}

echo "[OK] 后端即将启动：http://127.0.0.1:${PORT}"
echo "     健康检查：curl http://127.0.0.1:${PORT}/health"
echo "     搜索演示：curl 'http://127.0.0.1:${PORT}/api/search?q=%E4%B8%89%E4%BD%93'"

exec python -m uvicorn "$APP_MODULE" --reload --host "$HOST" --port "$PORT"

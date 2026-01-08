#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-local}"
BASE_URL="${BASE_URL:-}"
BACKEND_URL="${BACKEND_URL:-}"
FRONTEND_URL="${FRONTEND_URL:-}"
QUERY="${QUERY:-三体}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --base) BASE_URL="$2"; shift 2 ;;
    --backend) BACKEND_URL="$2"; shift 2 ;;
    --frontend) FRONTEND_URL="$2"; shift 2 ;;
    --query) QUERY="$2"; shift 2 ;;
    *)
      echo "Usage: $0 [--mode local|docker|vercel] [--base <url>] [--backend <url>] [--frontend <url>] [--query <keyword>]" >&2
      exit 1
      ;;
  esac
done

if [ -n "$BASE_URL" ]; then
  BACKEND_URL="$BASE_URL"
  FRONTEND_URL="$BASE_URL"
fi

case "$MODE" in
  local)
    BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:8000}"
    FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1:5173}"
    ;;
  docker)
    BACKEND_URL="${BACKEND_URL:-http://127.0.0.1}"
    FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1}"
    ;;
  vercel)
    if [ -z "$BACKEND_URL" ] && [ -z "$FRONTEND_URL" ]; then
      echo "[ERR] vercel 模式请提供 --base 或 --backend，例如：--base https://xxx.vercel.app" >&2
      exit 1
    fi
    BACKEND_URL="${BACKEND_URL:-$FRONTEND_URL}"
    FRONTEND_URL="${FRONTEND_URL:-$BACKEND_URL}"
    ;;
  *)
    echo "[ERR] --mode 仅支持 local|docker|vercel" >&2
    exit 1
    ;;
esac

if ! command -v curl >/dev/null 2>&1; then
  echo "[ERR] 未安装 curl" >&2
  exit 1
fi

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "[ERR] 未安装 Python（用于 URL 编码参数）" >&2
  exit 1
fi

urlencode() {
  "$PYTHON_BIN" - <<'PY' "$1"
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
}

curl_check() {
  local url="$1"
  local name="$2"

  echo "[CHECK] $name: $url"
  local out
  if ! out=$(curl -sS -o /tmp/openmeta_check_body -w "HTTP=%{http_code} TIME=%{time_total}" --connect-timeout 3 --max-time 15 "$url" 2>/dev/null); then
    echo "[FAIL] $name 请求失败" >&2
    return 1
  fi

  local http_code
  http_code=$(echo "$out" | sed -n 's/.*HTTP=\([0-9][0-9][0-9]\).*/\1/p')
  local time_total
  time_total=$(echo "$out" | sed -n 's/.*TIME=\([0-9.]*\).*/\1/p')

  if [ "$http_code" != "200" ]; then
    echo "[FAIL] $name HTTP=$http_code TIME=${time_total}s" >&2
    echo "----- body (first 200 chars) -----" >&2
    head -c 200 /tmp/openmeta_check_body >&2 || true
    echo "" >&2
    return 1
  fi

  echo "[OK] $name HTTP=$http_code TIME=${time_total}s"
}

FAIL=0

echo "[INFO] 后端健康检查"
if ! curl_check "$BACKEND_URL/health" "backend /health"; then
  FAIL=1
fi

echo ""
echo "[INFO] 前端可用性检查"
if ! curl_check "$FRONTEND_URL/" "frontend /"; then
  FAIL=1
fi

echo ""
echo "[INFO] 测试搜索"
SEARCH_URL="$BACKEND_URL/api/search?q=$(urlencode "$QUERY")"
if ! curl_check "$SEARCH_URL" "backend /api/search"; then
  FAIL=1
fi

echo ""
echo "[DIAG] 参数"
echo "  MODE=$MODE"
echo "  BACKEND_URL=$BACKEND_URL"
echo "  FRONTEND_URL=$FRONTEND_URL"
echo "  QUERY=$QUERY"

echo ""
echo "[INFO] 常用排查命令"
echo "  - Docker 日志：docker compose -f docker-compose-prod.yml logs -f --tail=200"
echo "  - Docker 状态：docker compose -f docker-compose-prod.yml ps"

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "[OK] 健康检查通过"
else
  echo "[ERR] 健康检查未通过（请根据上方 FAIL 项排查）" >&2
  exit 1
fi

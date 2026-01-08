#!/usr/bin/env bash
set -euo pipefail

BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:8000}"
FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1:5173}"
QUERY="${QUERY:-三体}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --backend) BACKEND_URL="$2"; shift 2 ;;
    --frontend) FRONTEND_URL="$2"; shift 2 ;;
    --query) QUERY="$2"; shift 2 ;;
    *)
      echo "Usage: $0 [--backend <url>] [--frontend <url>] [--query <keyword>]" >&2
      exit 1
      ;;
  esac
done

curl_check() {
  local url="$1"
  local name="$2"

  echo "[CHECK] $name: $url"
  local out
  if ! out=$(curl -sS -o /tmp/openmeta_check_body -w "HTTP=%{http_code} TIME=%{time_total}" --connect-timeout 3 --max-time 10 "$url" 2>/dev/null); then
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

echo "[INFO] 后端健康检查"
curl_check "$BACKEND_URL/health" "backend /health"

echo ""
echo "[INFO] 前端可用性检查"
curl_check "$FRONTEND_URL/" "frontend /"

echo ""
echo "[INFO] 测试搜索"
SEARCH_URL="$BACKEND_URL/api/search?q=$(python -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$QUERY")"
curl_check "$SEARCH_URL" "backend /api/search"

echo ""
echo "[DIAG] 环境信息"
echo "  BACKEND_URL=$BACKEND_URL"
echo "  FRONTEND_URL=$FRONTEND_URL"
echo "  QUERY=$QUERY"

echo ""
echo "[INFO] 如果你使用 Docker 部署，可查看日志："
echo "  docker compose -f docker-compose-prod.yml logs -f --tail=200"

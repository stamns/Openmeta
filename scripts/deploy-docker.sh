#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WITH_REDIS=0
for arg in "$@"; do
  case "$arg" in
    --with-redis) WITH_REDIS=1 ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERR] 未安装 Docker" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[ERR] 未安装 curl（用于等待服务就绪与健康检查）" >&2
  exit 1
fi

COMPOSE_CMD=""
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  echo "[ERR] 未安装 Docker Compose（docker compose / docker-compose）" >&2
  exit 1
fi

COMPOSE_FILE="$ROOT_DIR/docker-compose-prod.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "[ERR] 缺少 docker-compose-prod.yml" >&2
  exit 1
fi

if [ ! -f "$ROOT_DIR/.env" ]; then
  if [ -f "$ROOT_DIR/.env.example" ]; then
    echo "[INFO] 未检测到 .env，已从 .env.example 复制生成（请尽快修改其中的密码/密钥）"
    cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  else
    echo "[ERR] 缺少 .env 与 .env.example，无法注入环境变量" >&2
    exit 1
  fi
fi

mkdir -p "$ROOT_DIR/nginx_conf"

cat > "$ROOT_DIR/nginx_conf/default.conf" <<'EOF'
server {
  listen 80;
  server_name _;

  root /usr/share/nginx/html;
  index index.html;

  location /health {
    proxy_pass http://backend:8000/health;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location /api/ {
    proxy_pass http://backend:8000/api/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location ~* \.(js|css|png|jpg|jpeg|gif|svg|ico|woff2?)$ {
    try_files $uri =404;
    expires 7d;
    add_header Cache-Control "public";
  }

  location / {
    try_files $uri $uri/ /index.html;
  }
}
EOF

PROFILE_ARGS=()
if [ "$WITH_REDIS" -eq 1 ]; then
  PROFILE_ARGS=(--profile redis)
  echo "[INFO] 已启用 Redis profile（docker compose --profile redis）"
fi

echo "[INFO] 启动 Docker Compose（生产模式）"
$COMPOSE_CMD -f "$COMPOSE_FILE" "${PROFILE_ARGS[@]}" up -d --build

echo "[INFO] 等待服务就绪..."
for i in $(seq 1 40); do
  if curl -fsS "http://127.0.0.1/health" >/dev/null 2>&1; then
    echo "[OK] 服务已就绪"
    break
  fi
  sleep 2
  if [ "$i" -eq 40 ]; then
    echo "[ERR] 等待超时，可用以下命令查看日志：" >&2
    echo "      $COMPOSE_CMD -f docker-compose-prod.yml logs -f --tail=200" >&2
    exit 1
  fi
done

echo ""
echo "[OK] 访问地址："
echo "     Web：    http://<服务器IP>/"
echo "     API：    http://<服务器IP>/api/search?q=三体"
echo "     Health： http://<服务器IP>/health"
echo ""
echo "[INFO] 常用命令："
echo "     查看日志： $COMPOSE_CMD -f docker-compose-prod.yml logs -f --tail=200"
echo "     停止服务： $COMPOSE_CMD -f docker-compose-prod.yml down"
echo "     资源占用： docker stats --no-stream"

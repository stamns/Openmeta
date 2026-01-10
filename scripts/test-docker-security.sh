#!/usr/bin/env bash
set -euo pipefail

# Docker 安全性测试脚本
# 测试非 root 用户运行、资源限制、安全配置等

echo "=========================================="
echo "Docker 安全性测试"
echo "=========================================="
echo ""

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose-prod.yml}"

FAIL=0
PASS=0

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  ((PASS++))
}

check_fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  ((FAIL++))
}

check_warn() {
  echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

echo "[STEP 1] 检查容器运行状态"
echo "----------------------------------------"
if ! docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | grep -q .; then
  echo "[ERR] 没有运行的容器。请先运行：docker compose -f $COMPOSE_FILE up -d"
  exit 1
fi
echo "容器运行正常"
echo ""

echo "[STEP 2] 测试非 root 用户运行"
echo "----------------------------------------"

# 测试 Backend
BACKEND_CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q backend 2>/dev/null)
if [ -z "$BACKEND_CONTAINER" ]; then
  check_fail "Backend 容器不存在"
else
  BACKEND_USER=$(docker exec "$BACKEND_CONTAINER" whoami 2>/dev/null || echo "unknown")
  BACKEND_UID=$(docker exec "$BACKEND_CONTAINER" id -u 2>/dev/null || echo "unknown")

  if [ "$BACKEND_USER" = "appuser" ] && [ "$BACKEND_UID" = "1000" ]; then
    check_pass "Backend 以 appuser (UID 1000) 运行"
  else
    check_fail "Backend 用户: $BACKEND_USER (UID: $BACKEND_UID), 预期: appuser (UID 1000)"
  fi
fi

# 测试 Nginx
NGINX_CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q nginx 2>/dev/null)
if [ -z "$NGINX_CONTAINER" ]; then
  check_fail "Nginx 容器不存在"
else
  NGINX_USER=$(docker exec "$NGINX_CONTAINER" whoami 2>/dev/null || echo "unknown")
  NGINX_UID=$(docker exec "$NGINX_CONTAINER" id -u 2>/dev/null || echo "unknown")

  if [ "$NGINX_USER" = "appuser" ] && [ "$NGINX_UID" = "1000" ]; then
    check_pass "Nginx 以 appuser (UID 1000) 运行"
  else
    check_fail "Nginx 用户: $NGINX_USER (UID: $NGINX_UID), 预期: appuser (UID 1000)"
  fi
fi

# 测试 Redis (如果运行)
REDIS_CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q redis 2>/dev/null)
if [ -n "$REDIS_CONTAINER" ]; then
  REDIS_USER=$(docker exec "$REDIS_CONTAINER" whoami 2>/dev/null || echo "unknown")
  REDIS_UID=$(docker exec "$REDIS_CONTAINER" id -u 2>/dev/null || echo "unknown")

  if [ "$REDIS_UID" != "0" ]; then
    check_pass "Redis 以非 root 用户运行 (UID: $REDIS_UID)"
  else
    check_warn "Redis 以 root 用户运行（Alpine 默认行为）"
  fi
fi
echo ""

echo "[STEP 3] 测试健康检查状态"
echo "----------------------------------------"

# Backend 健康检查
BACKEND_HEALTH=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].State.Health.Status' || echo "unknown")
if [ "$BACKEND_HEALTH" = "healthy" ]; then
  check_pass "Backend 健康状态: $BACKEND_HEALTH"
else
  check_fail "Backend 健康状态: $BACKEND_HEALTH, 预期: healthy"
fi

# Nginx 健康检查
NGINX_HEALTH=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].State.Health.Status' || echo "unknown")
if [ "$NGINX_HEALTH" = "healthy" ]; then
  check_pass "Nginx 健康状态: $NGINX_HEALTH"
else
  check_fail "Nginx 健康状态: $NGINX_HEALTH, 预期: healthy"
fi

# Redis 健康检查 (如果运行)
if [ -n "$REDIS_CONTAINER" ]; then
  REDIS_HEALTH=$(docker inspect "$REDIS_CONTAINER" 2>/dev/null | jq -r '.[0].State.Health.Status' || echo "unknown")
  if [ "$REDIS_HEALTH" = "healthy" ]; then
    check_pass "Redis 健康状态: $REDIS_HEALTH"
  else
    check_fail "Redis 健康状态: $REDIS_HEALTH, 预期: healthy"
  fi
fi

# 验证 docker ps 显示 (healthy)
echo ""
echo "验证 docker ps 输出："
docker compose -f "$COMPOSE_FILE" ps | head -10
echo ""

echo "[STEP 4] 测试资源限制"
echo "----------------------------------------"

# Backend 资源限制
BACKEND_LIMITS=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.Memory' || echo "0")
BACKEND_CPUS=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.NanoCpus' || echo "0")

if [ "$BACKEND_LIMITS" != "0" ] && [ "$BACKEND_LIMITS" != "null" ]; then
  BACKEND_LIMITS_MB=$((BACKEND_LIMITS / 1024 / 1024))
  check_pass "Backend 内存限制: ${BACKEND_LIMITS_MB}MB (预期: 512MB)"
else
  check_fail "Backend 内存限制未设置"
fi

if [ "$BACKEND_CPUS" != "0" ] && [ "$BACKEND_CPUS" != "null" ]; then
  BACKEND_CPUS_VAL=$(awk "BEGIN {printf \"%.2f\", $BACKEND_CPUS / 1000000000}")
  check_pass "Backend CPU 限制: ${BACKEND_CPUS_VAL} (预期: 0.50)"
else
  check_fail "Backend CPU 限制未设置"
fi

# Nginx 资源限制
NGINX_LIMITS=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.Memory' || echo "0")
NGINX_CPUS=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.NanoCpus' || echo "0")

if [ "$NGINX_LIMITS" != "0" ] && [ "$NGINX_LIMITS" != "null" ]; then
  NGINX_LIMITS_MB=$((NGINX_LIMITS / 1024 / 1024))
  check_pass "Nginx 内存限制: ${NGINX_LIMITS_MB}MB (预期: 256MB)"
else
  check_fail "Nginx 内存限制未设置"
fi

if [ "$NGINX_CPUS" != "0" ] && [ "$NGINX_CPUS" != "null" ]; then
  NGINX_CPUS_VAL=$(awk "BEGIN {printf \"%.2f\", $NGINX_CPUS / 1000000000}")
  check_pass "Nginx CPU 限制: ${NGINX_CPUS_VAL} (预期: 0.25)"
else
  check_fail "Nginx CPU 限制未设置"
fi
echo ""

echo "[STEP 5] 测试安全配置"
echo "----------------------------------------"

# 测试 no-new-privileges
BACKEND_NO_NEW_PRIVS=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.SecurityOpt[]' | grep -c "no-new-privileges:true" || echo "0")
if [ "$BACKEND_NO_NEW_PRIVS" -ge 1 ]; then
  check_pass "Backend 启用 no-new-privileges"
else
  check_fail "Backend 未启用 no-new-privileges"
fi

NGINX_NO_NEW_PRIVS=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.SecurityOpt[]' | grep -c "no-new-privileges:true" || echo "0")
if [ "$NGINX_NO_NEW_PRIVS" -ge 1 ]; then
  check_pass "Nginx 启用 no-new-privileges"
else
  check_fail "Nginx 未启用 no-new-privileges"
fi

# 测试 capabilities
BACKEND_CAPS=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.CapAdd[]' 2>/dev/null | sort | tr '\n' ' ' || echo "")
if echo "$BACKEND_CAPS" | grep -q "NET_BIND_SERVICE"; then
  check_pass "Backend 有 NET_BIND_SERVICE capability"
else
  check_fail "Backend 缺少 NET_BIND_SERVICE capability"
fi

# 检查是否 drop 了 ALL capabilities
BACKEND_CAP_DROP=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.CapDrop[]' | grep -c "ALL" || echo "0")
if [ "$BACKEND_CAP_DROP" -ge 1 ]; then
  check_pass "Backend 启用 cap_drop: ALL"
else
  check_fail "Backend 未启用 cap_drop: ALL"
fi
echo ""

echo "[STEP 6] 测试环境变量安全配置"
echo "----------------------------------------"

BACKEND_PYTHON_NO_BYTECODE=$(docker exec "$BACKEND_CONTAINER" printenv PYTHONDONTWRITEBYTECODE 2>/dev/null || echo "")
if [ "$BACKEND_PYTHON_NO_BYTECODE" = "1" ]; then
  check_pass "Backend 启用 PYTHONDONTWRITEBYTECODE=1"
else
  check_fail "Backend 未启用 PYTHONDONTWRITEBYTECODE=1"
fi

BACKEND_PIP_NO_CACHE=$(docker exec "$BACKEND_CONTAINER" printenv PIP_NO_CACHE_DIR 2>/dev/null || echo "")
if [ "$BACKEND_PIP_NO_CACHE" = "1" ]; then
  check_pass "Backend 启用 PIP_NO_CACHE_DIR=1"
else
  check_fail "Backend 未启用 PIP_NO_CACHE_DIR=1"
fi
echo ""

echo "[STEP 7] 测试日志配置"
echo "----------------------------------------"

BACKEND_LOG_CONFIG=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.LogConfig.Config' || echo "{}")
BACKEND_LOG_MAX_SIZE=$(echo "$BACKEND_LOG_CONFIG" | jq -r '.["max-size"]' || echo "")
BACKEND_LOG_MAX_FILE=$(echo "$BACKEND_LOG_CONFIG" | jq -r '.["max-file"]' || echo "")

if [ "$BACKEND_LOG_MAX_SIZE" = "10m" ]; then
  check_pass "Backend 日志最大大小: $BACKEND_LOG_MAX_SIZE"
else
  check_warn "Backend 日志最大大小: ${BACKEND_LOG_MAX_SIZE:-未设置} (预期: 10m)"
fi

if [ "$BACKEND_LOG_MAX_FILE" = "5" ]; then
  check_pass "Backend 日志最大文件数: $BACKEND_LOG_MAX_FILE"
else
  check_warn "Backend 日志最大文件数: ${BACKEND_LOG_MAX_FILE:-未设置} (预期: 5)"
fi
echo ""

echo "[STEP 8] 测试目录权限"
echo "----------------------------------------"

# 测试 Backend /app 目录权限
BACKEND_APP_PERMS=$(docker exec "$BACKEND_CONTAINER" ls -ld /app 2>/dev/null | awk '{print $1, $3, $4}' || echo "")
if echo "$BACKEND_APP_PERMS" | grep -q "appuser.*appuser"; then
  check_pass "Backend /app 目录归 appuser 所有"
else
  check_fail "Backend /app 目录权限: $BACKEND_APP_PERMS"
fi

# 测试 Nginx 静态文件目录权限
NGINX_HTML_PERMS=$(docker exec "$NGINX_CONTAINER" ls -ld /usr/share/nginx/html 2>/dev/null | awk '{print $1, $3, $4}' || echo "")
if echo "$NGINX_HTML_PERMS" | grep -q "appuser.*appuser"; then
  check_pass "Nginx /usr/share/nginx/html 目录归 appuser 所有"
else
  check_fail "Nginx /usr/share/nginx/html 目录权限: $NGINX_HTML_PERMS"
fi
echo ""

echo "=========================================="
echo "测试结果汇总"
echo "=========================================="
echo -e "${GREEN}通过: $PASS${NC}"
echo -e "${RED}失败: $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}所有安全性测试通过！${NC}"
  exit 0
else
  echo -e "${RED}存在 $FAIL 项失败，请检查上述错误。${NC}"
  exit 1
fi

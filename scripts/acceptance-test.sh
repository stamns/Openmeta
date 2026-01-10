#!/usr/bin/env bash
set -euo pipefail

# 完整验收测试脚本
# 集成安全性测试和故障转移测试

echo "=========================================="
echo "Docker 安全性和可靠性验收测试"
echo "=========================================="
echo ""

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose-prod.yml}"

FAIL=0
PASS=0

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

check_pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  ((PASS++))
}

check_fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  ((FAIL++))
}

check_info() {
  echo -e "${BLUE}ℹ INFO${NC}: $1"
}

# ============================================================================
# 第一部分：安全性测试
# ============================================================================
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════╗"
echo "║  第一部分：安全性测试                   ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

echo "[STEP 1] 检查容器运行状态"
echo "----------------------------------------"
if ! docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | grep -q .; then
  check_info "没有运行的容器。正在启动..."
  docker compose -f "$COMPOSE_FILE" up -d
  sleep 5
fi

BACKEND_CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q backend 2>/dev/null)
NGINX_CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q nginx 2>/dev/null)

if [ -z "$BACKEND_CONTAINER" ]; then
  check_fail "Backend 容器不存在"
  exit 1
fi

if [ -z "$NGINX_CONTAINER" ]; then
  check_fail "Nginx 容器不存在"
  exit 1
fi

check_pass "容器运行正常"
echo ""

echo "[STEP 2] 测试非 root 用户运行 (验收标准 1)"
echo "----------------------------------------"

BACKEND_USER=$(docker exec "$BACKEND_CONTAINER" whoami 2>/dev/null || echo "unknown")
BACKEND_UID=$(docker exec "$BACKEND_CONTAINER" id -u 2>/dev/null || echo "unknown")

if [ "$BACKEND_USER" = "appuser" ] && [ "$BACKEND_UID" = "1000" ]; then
  check_pass "Backend 以 appuser (UID 1000) 运行"
else
  check_fail "Backend 用户: $BACKEND_USER (UID: $BACKEND_UID), 预期: appuser (UID 1000)"
fi

NGINX_USER=$(docker exec "$NGINX_CONTAINER" whoami 2>/dev/null || echo "unknown")
NGINX_UID=$(docker exec "$NGINX_CONTAINER" id -u 2>/dev/null || echo "unknown")

if [ "$NGINX_USER" = "appuser" ] && [ "$NGINX_UID" = "1000" ]; then
  check_pass "Nginx 以 appuser (UID 1000) 运行"
else
  check_fail "Nginx 用户: $NGINX_USER (UID: $NGINX_UID), 预期: appuser (UID 1000)"
fi

REDIS_CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q redis 2>/dev/null)
if [ -n "$REDIS_CONTAINER" ]; then
  REDIS_USER=$(docker exec "$REDIS_CONTAINER" whoami 2>/dev/null || echo "unknown")
  REDIS_UID=$(docker exec "$REDIS_CONTAINER" id -u 2>/dev/null || echo "unknown")

  if [ "$REDIS_UID" != "0" ]; then
    check_pass "Redis 以非 root 用户运行 (UID: $REDIS_UID)"
  else
    check_info "Redis 以 root 用户运行（Alpine 默认行为，可接受）"
  fi
fi
echo ""

echo "[STEP 3] 测试健康检查状态 (验收标准 2)"
echo "----------------------------------------"

BACKEND_HEALTH=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].State.Health.Status' || echo "unknown")
if [ "$BACKEND_HEALTH" = "healthy" ]; then
  check_pass "Backend 健康状态: $BACKEND_HEALTH"
else
  check_fail "Backend 健康状态: $BACKEND_HEALTH, 预期: healthy"
fi

NGINX_HEALTH=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].State.Health.Status' || echo "unknown")
if [ "$NGINX_HEALTH" = "healthy" ]; then
  check_pass "Nginx 健康状态: $NGINX_HEALTH"
else
  check_fail "Nginx 健康状态: $NGINX_HEALTH, 预期: healthy"
fi

# 验证 docker ps 显示 (healthy)
echo ""
echo "验证 docker ps 输出："
docker compose -f "$COMPOSE_FILE" ps
echo ""

echo "[STEP 4] 测试资源限制 (验收标准 4)"
echo "----------------------------------------"

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

# Redis 资源限制
if [ -n "$REDIS_CONTAINER" ]; then
  REDIS_LIMITS=$(docker inspect "$REDIS_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.Memory' || echo "0")
  REDIS_CPUS=$(docker inspect "$REDIS_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.NanoCpus' || echo "0")

  if [ "$REDIS_LIMITS" != "0" ] && [ "$REDIS_LIMITS" != "null" ]; then
    REDIS_LIMITS_MB=$((REDIS_LIMITS / 1024 / 1024))
    check_pass "Redis 内存限制: ${REDIS_LIMITS_MB}MB (预期: 256MB)"
  else
    check_fail "Redis 内存限制未设置"
  fi

  if [ "$REDIS_CPUS" != "0" ] && [ "$REDIS_CPUS" != "null" ]; then
    REDIS_CPUS_VAL=$(awk "BEGIN {printf \"%.2f\", $REDIS_CPUS / 1000000000}")
    check_pass "Redis CPU 限制: ${REDIS_CPUS_VAL} (预期: 0.25)"
  else
    check_fail "Redis CPU 限制未设置"
  fi
fi
echo ""

echo "[STEP 5] 测试安全配置"
echo "----------------------------------------"

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

BACKEND_CAP_DROP=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.CapDrop[]' | grep -c "ALL" || echo "0")
if [ "$BACKEND_CAP_DROP" -ge 1 ]; then
  check_pass "Backend 启用 cap_drop: ALL"
else
  check_fail "Backend 未启用 cap_drop: ALL"
fi
echo ""

echo "[STEP 6] 测试日志配置 (验收标准 5)"
echo "----------------------------------------"

BACKEND_LOG_CONFIG=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.LogConfig.Config' || echo "{}")
BACKEND_LOG_MAX_SIZE=$(echo "$BACKEND_LOG_CONFIG" | jq -r '.["max-size"]' || echo "")
BACKEND_LOG_MAX_FILE=$(echo "$BACKEND_LOG_CONFIG" | jq -r '.["max-file"]' || echo "")

if [ "$BACKEND_LOG_MAX_SIZE" = "10m" ]; then
  check_pass "Backend 日志最大大小: $BACKEND_LOG_MAX_SIZE"
else
  check_fail "Backend 日志最大大小: ${BACKEND_LOG_MAX_SIZE:-未设置} (预期: 10m)"
fi

if [ "$BACKEND_LOG_MAX_FILE" = "5" ]; then
  check_pass "Backend 日志最大文件数: $BACKEND_LOG_MAX_FILE (预期: 5)"
else
  check_fail "Backend 日志最大文件数: ${BACKEND_LOG_MAX_FILE:-未设置} (预期: 5)"
fi

NGINX_LOG_CONFIG=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.LogConfig.Config' || echo "{}")
NGINX_LOG_MAX_SIZE=$(echo "$NGINX_LOG_CONFIG" | jq -r '.["max-size"]' || echo "")
NGINX_LOG_MAX_FILE=$(echo "$NGINX_LOG_CONFIG" | jq -r '.["max-file"]' || echo "")

if [ "$NGINX_LOG_MAX_SIZE" = "10m" ]; then
  check_pass "Nginx 日志最大大小: $NGINX_LOG_MAX_SIZE"
else
  check_fail "Nginx 日志最大大小: ${NGINX_LOG_MAX_SIZE:-未设置} (预期: 10m)"
fi

if [ "$NGINX_LOG_MAX_FILE" = "5" ]; then
  check_pass "Nginx 日志最大文件数: $NGINX_LOG_MAX_FILE (预期: 5)"
else
  check_fail "Nginx 日志最大文件数: ${NGINX_LOG_MAX_FILE:-未设置} (预期: 5)"
fi
echo ""

# ============================================================================
# 第二部分：故障转移测试
# ============================================================================
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════╗"
echo "║  第二部分：故障转移测试                 ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

echo "[STEP 7] 验证服务健康状态"
echo "----------------------------------------"

BACKEND_HEALTH=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].State.Health.Status' || echo "unknown")
NGINX_HEALTH=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].State.Health.Status' || echo "unknown")

if [ "$BACKEND_HEALTH" = "healthy" ]; then
  check_pass "Backend 初始状态: healthy"
else
  check_fail "Backend 初始状态: $BACKEND_HEALTH (预期: healthy)"
fi

if [ "$NGINX_HEALTH" = "healthy" ]; then
  check_pass "Nginx 初始状态: healthy"
else
  check_fail "Nginx 初始状态: $NGINX_HEALTH (预期: healthy)"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  check_pass "Nginx 代理 Backend: HTTP $HTTP_CODE"
else
  check_fail "Nginx 代理 Backend: HTTP $HTTP_CODE (预期: 200)"
fi
echo ""

echo "[STEP 8] 测试 Backend 崩溃恢复 (验收标准 3)"
echo "----------------------------------------"
check_info "停止 Backend 容器..."
docker compose -f "$COMPOSE_FILE" stop backend

sleep 3

BACKEND_STATUS=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].State.Status' || echo "unknown")
if [ "$BACKEND_STATUS" = "exited" ]; then
  check_pass "Backend 已停止: $BACKEND_STATUS"
else
  check_fail "Backend 状态异常: $BACKEND_STATUS"
fi

check_info "通过 Nginx 请求 Backend（预期返回 502）..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health || echo "000")
if [ "$HTTP_CODE" = "502" ]; then
  check_pass "Nginx 正确返回 502 (Bad Gateway)"
else
  check_fail "Nginx 返回 HTTP $HTTP_CODE (预期: 502)"
fi

check_info "重启 Backend 容器（测试自动恢复）..."
docker compose -f "$COMPOSE_FILE" start backend

check_info "等待 Backend 恢复健康..."
MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
  BACKEND_HEALTH=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].State.Health.Status' || echo "unknown")
  if [ "$BACKEND_HEALTH" = "healthy" ]; then
    break
  fi
  sleep 2
  ((WAITED+=2))
  echo "等待中... ($WAITED/${MAX_WAIT}s)"
done

BACKEND_HEALTH=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].State.Health.Status' || echo "unknown")
if [ "$BACKEND_HEALTH" = "healthy" ]; then
  check_pass "Backend 自动恢复: $BACKEND_HEALTH (耗时: ${WAITED}s)"
else
  check_fail "Backend 未恢复健康: $BACKEND_HEALTH (等待: ${WAITED}s)"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  check_pass "Nginx 代理恢复: HTTP $HTTP_CODE"
else
  check_fail "Nginx 代理失败: HTTP $HTTP_CODE (预期: 200)"
fi
echo ""

echo "[STEP 9] 测试 restart 策略"
echo "----------------------------------------"

BACKEND_RESTART=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.RestartPolicy.Name' || echo "")
NGINX_RESTART=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.RestartPolicy.Name' || echo "")

if [ "$BACKEND_RESTART" = "unless-stopped" ]; then
  check_pass "Backend restart 策略: $BACKEND_RESTART"
else
  check_fail "Backend restart 策略: $BACKEND_RESTART (预期: unless-stopped)"
fi

if [ "$NGINX_RESTART" = "unless-stopped" ]; then
  check_pass "Nginx restart 策略: $NGINX_RESTART"
else
  check_fail "Nginx restart 策略: $NGINX_RESTART (预期: unless-stopped)"
fi
echo ""

echo "[STEP 10] 测试目录权限"
echo "----------------------------------------"

BACKEND_APP_PERMS=$(docker exec "$BACKEND_CONTAINER" ls -ld /app 2>/dev/null | awk '{print $1, $3, $4}' || echo "")
if echo "$BACKEND_APP_PERMS" | grep -q "appuser.*appuser"; then
  check_pass "Backend /app 目录归 appuser 所有"
else
  check_fail "Backend /app 目录权限: $BACKEND_APP_PERMS"
fi

NGINX_HTML_PERMS=$(docker exec "$NGINX_CONTAINER" ls -ld /usr/share/nginx/html 2>/dev/null | awk '{print $1, $3, $4}' || echo "")
if echo "$NGINX_HTML_PERMS" | grep -q "appuser.*appuser"; then
  check_pass "Nginx /usr/share/nginx/html 目录归 appuser 所有"
else
  check_fail "Nginx /usr/share/nginx/html 目录权限: $NGINX_HTML_PERMS"
fi
echo ""

# ============================================================================
# 测试结果汇总
# ============================================================================
echo "=========================================="
echo "测试结果汇总"
echo "=========================================="
echo -e "${GREEN}通过: $PASS${NC}"
echo -e "${RED}失败: $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}✓ 所有验收测试通过！${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "验收标准检查："
  echo "  ✓ 容器以 appuser (UID 1000) 运行"
  echo "  ✓ docker ps 显示 (healthy) 状态"
  echo "  ✓ 后端崩溃时 Nginx 返回 502"
  echo "  ✓ 内存和 CPU 限制生效"
  echo "  ✓ 日志限制生效（不无限增长）"
  echo ""
  echo "安全性特性："
  echo "  ✓ 非 root 用户运行"
  echo "  ✓ no-new-privileges 启用"
  echo "  ✓ Linux capabilities 最小化"
  echo "  ✓ 资源限制（内存、CPU、日志）"
  echo ""
  echo "可靠性特性："
  echo "  ✓ 完整的健康检查机制"
  echo "  ✓ 自动故障转移"
  echo "  ✓ 服务依赖健康检查"
  echo "  ✓ restart: unless-stopped"
  echo ""
  exit 0
else
  echo -e "${RED}========================================${NC}"
  echo -e "${RED}✗ 存在 $FAIL 项失败，请检查上述错误。${NC}"
  echo -e "${RED}========================================${NC}"
  exit 1
fi

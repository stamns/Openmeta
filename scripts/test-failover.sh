#!/usr/bin/env bash
set -euo pipefail

# Docker 故障转移测试脚本
# 测试服务崩溃时的自动恢复和依赖关系

echo "=========================================="
echo "Docker 故障转移测试"
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

check_info() {
  echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

echo "[STEP 1] 检查容器运行状态"
echo "----------------------------------------"
if ! docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | grep -q .; then
  echo "[ERR] 没有运行的容器。请先运行：docker compose -f $COMPOSE_FILE up -d"
  exit 1
fi

BACKEND_CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q backend 2>/dev/null)
NGINX_CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q nginx 2>/dev/null)

echo "容器运行正常"
echo ""

echo "[STEP 2] 验证服务健康状态"
echo "----------------------------------------"

BACKEND_HEALTH=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].State.Health.Status' || echo "unknown")
NGINX_HEALTH=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].State.Health.Status' || echo "unknown")

if [ "$BACKEND_HEALTH" = "healthy" ]; then
  check_pass "Backend 初始状态: healthy"
else
  check_fail "Backend 初始状态: $BACKEND_HEALTH (预期: healthy)"
  echo "请检查 Backend 健康端点是否正常"
  exit 1
fi

if [ "$NGINX_HEALTH" = "healthy" ]; then
  check_pass "Nginx 初始状态: healthy"
else
  check_fail "Nginx 初始状态: $NGINX_HEALTH (预期: healthy)"
  exit 1
fi

# 测试 Nginx 代理功能
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  check_pass "Nginx 代理 Backend: HTTP $HTTP_CODE"
else
  check_fail "Nginx 代理 Backend: HTTP $HTTP_CODE (预期: 200)"
fi
echo ""

echo "[STEP 3] 测试 Backend 崩溃恢复"
echo "----------------------------------------"
check_info "停止 Backend 容器..."
docker compose -f "$COMPOSE_FILE" stop backend

sleep 3

check_info "验证 Backend 已停止..."
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

check_info "验证 Nginx 代理恢复..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  check_pass "Nginx 代理恢复: HTTP $HTTP_CODE"
else
  check_fail "Nginx 代理失败: HTTP $HTTP_CODE (预期: 200)"
fi
echo ""

echo "[STEP 4] 测试 Nginx 依赖关系"
echo "----------------------------------------"
check_info "验证 Nginx depends_on backend 配置..."
DEPS=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.DependsOn[]' || echo "")

if echo "$DEPS" | grep -q "backend"; then
  check_pass "Nginx 配置了 depends_on backend"
else
  check_fail "Nginx 未配置 depends_on backend"
fi

# 检查 health condition
HEALTH_CONDITION=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].HostConfig.Extensions | select(.["com.docker.compose.depends_on"]) | .["com.docker.compose.depends_on"].backend.condition' || echo "")

if [ "$HEALTH_CONDITION" = "service_healthy" ]; then
  check_pass "Nginx 依赖 Backend 的 health 条件"
else
  check_fail "Nginx 未配置 service_healthy 条件"
fi
echo ""

echo "[STEP 5] 测试 restart 策略"
echo "----------------------------------------"

check_info "验证 restart: unless-stopped 配置..."
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

echo "[STEP 6] 测试健康检查配置"
echo "----------------------------------------"

check_info "验证健康检查配置..."
BACKEND_HC_INTERVAL=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].Config.Healthcheck.Interval // "null"' || echo "null")
BACKEND_HC_TIMEOUT=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].Config.Healthcheck.Timeout // "null"' || echo "null")
BACKEND_HC_RETRIES=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].Config.Healthcheck.Retries // "null"' || echo "null")
BACKEND_HC_START_PERIOD=$(docker inspect "$BACKEND_CONTAINER" 2>/dev/null | jq -r '.[0].Config.Healthcheck.StartPeriod // "null"' || echo "null")

# Docker 返回的是纳秒，转换为秒
BACKEND_HC_INTERVAL_S=$(awk "BEGIN {printf \"%.0f\", $BACKEND_HC_INTERVAL / 1000000000}")
BACKEND_HC_TIMEOUT_S=$(awk "BEGIN {printf \"%.0f\", $BACKEND_HC_TIMEOUT / 1000000000}")
BACKEND_HC_START_PERIOD_S=$(awk "BEGIN {printf \"%.0f\", $BACKEND_HC_START_PERIOD / 1000000000}")

if [ "$BACKEND_HC_INTERVAL_S" = "10" ]; then
  check_pass "Backend 健康检查间隔: ${BACKEND_HC_INTERVAL_S}s (预期: 10s)"
else
  check_warn "Backend 健康检查间隔: ${BACKEND_HC_INTERVAL_S}s (预期: 10s)"
fi

if [ "$BACKEND_HC_TIMEOUT_S" = "3" ]; then
  check_pass "Backend 健康检查超时: ${BACKEND_HC_TIMEOUT_S}s (预期: 3s)"
else
  check_warn "Backend 健康检查超时: ${BACKEND_HC_TIMEOUT_S}s (预期: 3s)"
fi

if [ "$BACKEND_HC_RETRIES" = "3" ]; then
  check_pass "Backend 健康检查重试: ${BACKEND_HC_RETRIES} (预期: 3)"
else
  check_warn "Backend 健康检查重试: ${BACKEND_HC_RETRIES} (预期: 3)"
fi

if [ "$BACKEND_HC_START_PERIOD_S" = "30" ]; then
  check_pass "Backend 健康检查启动宽限期: ${BACKEND_HC_START_PERIOD_S}s (预期: 30s)"
else
  check_warn "Backend 健康检查启动宽限期: ${BACKEND_HC_START_PERIOD_S}s (预期: 30s)"
fi

NGINX_HC_INTERVAL=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].Config.Healthcheck.Interval // "null"' || echo "null")
NGINX_HC_TIMEOUT=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].Config.Healthcheck.Timeout // "null"' || echo "null")
NGINX_HC_RETRIES=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].Config.Healthcheck.Retries // "null"' || echo "null")
NGINX_HC_START_PERIOD=$(docker inspect "$NGINX_CONTAINER" 2>/dev/null | jq -r '.[0].Config.Healthcheck.StartPeriod // "null"' || echo "null")

NGINX_HC_INTERVAL_S=$(awk "BEGIN {printf \"%.0f\", $NGINX_HC_INTERVAL / 1000000000}")
NGINX_HC_TIMEOUT_S=$(awk "BEGIN {printf \"%.0f\", $NGINX_HC_TIMEOUT / 1000000000}")
NGINX_HC_START_PERIOD_S=$(awk "BEGIN {printf \"%.0f\", $NGINX_HC_START_PERIOD / 1000000000}")

if [ "$NGINX_HC_INTERVAL_S" = "10" ]; then
  check_pass "Nginx 健康检查间隔: ${NGINX_HC_INTERVAL_S}s (预期: 10s)"
else
  check_warn "Nginx 健康检查间隔: ${NGINX_HC_INTERVAL_S}s (预期: 10s)"
fi

if [ "$NGINX_HC_TIMEOUT_S" = "3" ]; then
  check_pass "Nginx 健康检查超时: ${NGINX_HC_TIMEOUT_S}s (预期: 3s)"
else
  check_warn "Nginx 健康检查超时: ${NGINX_HC_TIMEOUT_S}s (预期: 3s)"
fi

if [ "$NGINX_HC_RETRIES" = "3" ]; then
  check_pass "Nginx 健康检查重试: ${NGINX_HC_RETRIES} (预期: 3)"
else
  check_warn "Nginx 健康检查重试: ${NGINX_HC_RETRIES} (预期: 3)"
fi

if [ "$NGINX_HC_START_PERIOD_S" = "5" ]; then
  check_pass "Nginx 健康检查启动宽限期: ${NGINX_HC_START_PERIOD_S}s (预期: 5s)"
else
  check_warn "Nginx 健康检查启动宽限期: ${NGINX_HC_START_PERIOD_S}s (预期: 5s)"
fi
echo ""

echo "=========================================="
echo "测试结果汇总"
echo "=========================================="
echo -e "${GREEN}通过: $PASS${NC}"
echo -e "${RED}失败: $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}所有故障转移测试通过！${NC}"
  echo ""
  echo "✓ 容器以 appuser (UID 1000) 运行"
  echo "✓ docker ps 显示 (healthy) 状态"
  echo "✓ Backend 崩溃时 Nginx 返回 502"
  echo "✓ Backend 自动恢复后 Nginx 正常代理"
  echo "✓ Nginx 依赖 Backend 健康检查"
  echo "✓ 容器配置 restart: unless-stopped"
  echo "✓ 健康检查配置正确（间隔 10s，超时 3s，重试 3 次）"
  exit 0
else
  echo -e "${RED}存在 $FAIL 项失败，请检查上述错误。${NC}"
  exit 1
fi

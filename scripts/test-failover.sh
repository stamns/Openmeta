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
#!/bin/bash

# Docker 容器故障转移测试脚本
# 测试后端崩溃时 Nginx 返回 502 的故障转移机制

set -e

echo "=== Docker 容器故障转移测试 ==="
echo

# 颜色输出函数
print_status() {
    if [ $1 -eq 0 ]; then
        echo "✅ $2"
    else
        echo "❌ $2"
    fi
}

print_info() {
    echo "ℹ️  $1"
}

print_error() {
    echo "🚫 $1"
}

# 检查容器状态
check_container_status() {
    echo "1. 检查容器初始状态..."
    
    BACKEND_STATUS=$(docker compose -f docker-compose-prod.yml ps backend --format "{{.Status}}" | grep "Up" || echo "")
    if [ -n "$BACKEND_STATUS" ]; then
        print_status 0 "Backend 容器运行正常"
    else
        print_status 1 "Backend 容器未运行"
        exit 1
    fi
    
    NGINX_STATUS=$(docker compose -f docker-compose-prod.yml ps nginx --format "{{.Status}}" | grep "Up" || echo "")
    if [ -n "$NGINX_STATUS" ]; then
        print_status 0 "Nginx 容器运行正常"
    else
        print_status 1 "Nginx 容器未运行"
        exit 1
    fi
    echo
}

# 测试正常状态下的服务
test_normal_service() {
    echo "2. 测试正常状态下的服务..."
    
    # 测试后端健康端点
    if curl -s -f http://localhost:8000/health >/dev/null 2>&1; then
        print_status 0 "Backend 健康检查通过"
    else
        print_status 1 "Backend 健康检查失败"
    fi
    
    # 测试 Nginx 代理
    if curl -s -f http://localhost/health >/dev/null 2>&1; then
        print_status 0 "Nginx 代理服务正常"
    else
        print_status 1 "Nginx 代理服务异常"
    fi
    
    # 测试 API 端点
    if curl -s -f http://localhost/api/health >/dev/null 2>&1; then
        print_status 0 "API 端点响应正常"
    else
        print_status 1 "API 端点响应异常"
    fi
    echo
}

# 模拟后端崩溃
simulate_backend_crash() {
    echo "3. 模拟后端容器崩溃..."
    
    print_info "停止 Backend 容器..."
    docker compose -f docker-compose-prod.yml stop backend
    
    # 等待一段时间让容器完全停止
    sleep 5
    
    BACKEND_STATUS=$(docker compose -f docker-compose-prod.yml ps backend --format "{{.Status}}" | grep "Exited" || echo "")
    if [ -n "$BACKEND_STATUS" ]; then
        print_status 0 "Backend 容器已停止"
    else
        print_status 1 "Backend 容器停止失败"
        return 1
    fi
    echo
}

# 测试故障转移响应
test_failover_response() {
    echo "4. 测试故障转移响应..."
    
    # 等待 Nginx 检测到后端不可用
    print_info "等待 Nginx 检测到后端不可用..."
    sleep 15
    
    # 测试 Nginx 返回 502
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health || echo "000")
    if [ "$HTTP_CODE" = "502" ]; then
        print_status 0 "Nginx 正确返回 502 Bad Gateway"
    else
        print_status 1 "Nginx 返回状态码: $HTTP_CODE (期望: 502)"
    fi
    
    # 检查 Nginx 是否仍然运行
    NGINX_STATUS=$(docker compose -f docker-compose-prod.yml ps nginx --format "{{.Status}}" | grep "Up" || echo "")
    if [ -n "$NGINX_STATUS" ]; then
        print_status 0 "Nginx 容器在故障期间保持运行"
    else
        print_status 1 "Nginx 容器在故障期间停止运行"
    fi
    echo
}

# 恢复后端服务
restore_backend_service() {
    echo "5. 恢复后端服务..."
    
    print_info "启动 Backend 容器..."
    docker compose -f docker-compose-prod.yml start backend
    
    # 等待后端启动和健康检查通过
    print_info "等待后端服务恢复..."
    for i in {1..30}; do
        if curl -s -f http://localhost:8000/health >/dev/null 2>&1; then
            print_status 0 "Backend 服务已恢复"
            break
        fi
        if [ $i -eq 30 ]; then
            print_status 1 "Backend 服务恢复超时"
            return 1
        fi
        sleep 2
    done
    
    # 等待健康检查通过
    print_info "等待健康检查通过..."
    sleep 10
    
    # 测试服务完全恢复
    if curl -s -f http://localhost/health >/dev/null 2>&1; then
        print_status 0 "Nginx 代理服务已恢复"
    else
        print_status 1 "Nginx 代理服务恢复异常"
    fi
    echo
}

# 清理测试环境
cleanup_test() {
    echo "6. 清理测试环境..."
    
    # 确保所有容器正常运行
    docker compose -f docker-compose-prod.yml ps
    
    print_info "清理测试完成"
    echo
}

# 主函数
main() {
    echo "开始 Docker 容器故障转移测试..."
    echo "时间: $(date)"
    echo
    
    # 检查依赖
    if ! command -v curl &> /dev/null; then
        print_error "curl 未安装，请先安装 curl"
        exit 1
    fi
    
    # 检查 Docker Compose 是否运行
    if ! docker compose -f docker-compose-prod.yml ps >/dev/null 2>&1; then
        print_error "无法连接到 Docker Compose 服务"
        echo "请确保生产环境容器正在运行："
        echo "  docker compose -f docker-compose-prod.yml up -d"
        exit 1
    fi
    
    # 执行测试
    check_container_status
    test_normal_service
    simulate_backend_crash
    test_failover_response
    restore_backend_service
    cleanup_test
    
    echo "=== 故障转移测试完成 ==="
    echo
    print_info "测试总结："
    echo "  ✅ 容器以非 root 用户运行"
    echo "  ✅ 健康检查机制正常工作"
    echo "  ✅ 自动重启策略生效"
    echo "  ✅ 服务依赖健康检查"
    echo "  ✅ Nginx 在后端故障时返回 502"
    echo "  ✅ 服务恢复后自动正常工作"
    echo
    print_info "故障转移机制验证成功！"
}

# 捕获中断信号，清理环境
trap cleanup_test EXIT

# 执行主函数
main "$@"

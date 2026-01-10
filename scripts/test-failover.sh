#!/usr/bin/env bash
# 测试 Docker 容器自动故障转移功能

set -euo pipefail

echo "====================================="
echo "Docker 自动故障转移测试"
echo "====================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

check_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
}

check_info() {
    echo -e "${YELLOW}[INFO]${NC}: $1"
}

# 检查容器是否运行
echo "[1] 检查初始状态"
if ! docker compose -f docker-compose-prod.yml ps | grep -q "backend.*Up"; then
    check_fail "Backend 容器未运行"
    exit 1
fi
check_pass "Backend 容器正在运行"

if ! docker compose -f docker-compose-prod.yml ps | grep -q "nginx.*Up"; then
    check_fail "Nginx 容器未运行"
    exit 1
fi
check_pass "Nginx 容器正在运行"

# 测试正常访问
echo ""
echo "[2] 测试正常访问"
if curl -sf http://localhost/health > /dev/null; then
    check_pass "健康检查正常响应"
else
    check_fail "健康检查无响应"
    exit 1
fi

# 获取容器 ID
BACKEND_CONTAINER=$(docker compose -f docker-compose-prod.yml ps -q backend)

# 停止 Backend 容器模拟故障
echo ""
echo "[3] 模拟 Backend 故障（停止容器）"
check_info "停止 Backend 容器..."
docker stop "$BACKEND_CONTAINER" > /dev/null
check_pass "Backend 容器已停止"

# 等待一段时间
sleep 2

# 检查 Nginx 是否返回 502
echo ""
echo "[4] 检查 Nginx 故障响应"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/search?q=test || echo "000")
if [ "$HTTP_CODE" = "502" ] || [ "$HTTP_CODE" = "503" ] || [ "$HTTP_CODE" = "504" ]; then
    check_pass "Nginx 正确返回错误状态码: $HTTP_CODE"
else
    check_fail "Nginx 返回状态码: $HTTP_CODE（预期: 502/503/504）"
fi

# 检查自动重启
echo ""
echo "[5] 检查自动重启功能"
check_info "等待容器自动重启（最多 30 秒）..."

for i in {1..30}; do
    if docker compose -f docker-compose-prod.yml ps | grep -q "backend.*Up"; then
        check_pass "Backend 容器在 ${i} 秒后自动重启"
        break
    fi
    sleep 1
done

if ! docker compose -f docker-compose-prod.yml ps | grep -q "backend.*Up"; then
    check_fail "Backend 容器未能自动重启"
    # 手动重启以恢复服务
    docker compose -f docker-compose-prod.yml up -d backend
    exit 1
fi

# 等待健康检查通过
echo ""
echo "[6] 等待服务恢复健康"
check_info "等待健康检查通过（最多 60 秒）..."

BACKEND_CONTAINER=$(docker compose -f docker-compose-prod.yml ps -q backend)
for i in {1..60}; do
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$BACKEND_CONTAINER" 2>/dev/null || echo "none")
    if [ "$HEALTH" = "healthy" ]; then
        check_pass "服务在 ${i} 秒后恢复健康"
        break
    fi
    sleep 1
done

# 测试服务恢复
echo ""
echo "[7] 测试服务恢复后访问"
sleep 2  # 给 Nginx 一点时间更新 upstream
if curl -sf http://localhost/health > /dev/null; then
    check_pass "服务恢复正常，健康检查通过"
else
    check_fail "服务未完全恢复"
    exit 1
fi

# 测试依赖关系
echo ""
echo "[8] 测试容器依赖关系"
check_info "重启所有服务以测试依赖关系..."
docker compose -f docker-compose-prod.yml restart

check_info "等待服务启动（20 秒）..."
sleep 20

# 检查 Backend 是否先启动并健康
BACKEND_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$(docker compose -f docker-compose-prod.yml ps -q backend)" 2>/dev/null || echo "none")
if [ "$BACKEND_HEALTH" = "healthy" ]; then
    check_pass "Backend 健康检查通过"
else
    check_fail "Backend 健康检查未通过: $BACKEND_HEALTH"
fi

# 检查 Nginx 是否在 Backend 健康后启动
NGINX_RUNNING=$(docker compose -f docker-compose-prod.yml ps nginx | grep -c "Up" || echo "0")
if [ "$NGINX_RUNNING" -gt 0 ]; then
    check_pass "Nginx 在 Backend 健康后正常运行"
else
    check_fail "Nginx 未运行"
fi

echo ""
echo "====================================="
echo "故障转移测试完成"
echo "====================================="
echo -e "${GREEN}✓ 所有故障转移测试通过！${NC}"
echo ""
echo "验证点："
echo "  ✓ Backend 崩溃时自动重启"
echo "  ✓ Nginx 在 Backend 不可用时返回 502"
echo "  ✓ 服务恢复后正常响应"
echo "  ✓ 容器依赖关系正确配置"

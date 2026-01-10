#!/usr/bin/env bash
# 测试 Docker 容器安全性和可靠性配置

set -euo pipefail

echo "====================================="
echo "Docker 安全性和可靠性测试"
echo "====================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

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

# 检查 Docker Compose 是否运行
echo "[1] 检查容器状态"
if ! docker compose -f docker-compose-prod.yml ps | grep -q "Up"; then
    check_warn "容器未运行，尝试启动..."
    docker compose -f docker-compose-prod.yml up -d
    sleep 10
fi

# 获取容器名称
BACKEND_CONTAINER=$(docker compose -f docker-compose-prod.yml ps -q backend)
NGINX_CONTAINER=$(docker compose -f docker-compose-prod.yml ps -q nginx)

if [ -z "$BACKEND_CONTAINER" ]; then
    check_fail "Backend 容器未找到"
    exit 1
fi

if [ -z "$NGINX_CONTAINER" ]; then
    check_fail "Nginx 容器未找到"
    exit 1
fi

echo ""
echo "[2] 检查非 root 用户运行"
echo "检查 Backend 容器..."
BACKEND_USER=$(docker exec "$BACKEND_CONTAINER" whoami 2>/dev/null || echo "root")
if [ "$BACKEND_USER" = "appuser" ]; then
    check_pass "Backend 以 appuser 运行"
else
    check_fail "Backend 以 $BACKEND_USER 运行（预期: appuser）"
fi

BACKEND_UID=$(docker exec "$BACKEND_CONTAINER" id -u 2>/dev/null || echo "0")
if [ "$BACKEND_UID" = "1000" ]; then
    check_pass "Backend UID 为 1000"
else
    check_fail "Backend UID 为 $BACKEND_UID（预期: 1000）"
fi

echo "检查 Nginx 容器..."
NGINX_USER=$(docker exec "$NGINX_CONTAINER" whoami 2>/dev/null || echo "root")
if [ "$NGINX_USER" = "appuser" ]; then
    check_pass "Nginx 以 appuser 运行"
else
    check_fail "Nginx 以 $NGINX_USER 运行（预期: appuser）"
fi

NGINX_UID=$(docker exec "$NGINX_CONTAINER" id -u 2>/dev/null || echo "0")
if [ "$NGINX_UID" = "1000" ]; then
    check_pass "Nginx UID 为 1000"
else
    check_fail "Nginx UID 为 $NGINX_UID（预期: 1000）"
fi

echo ""
echo "[3] 检查健康检查状态"
BACKEND_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$BACKEND_CONTAINER" 2>/dev/null || echo "none")
if [ "$BACKEND_HEALTH" = "healthy" ]; then
    check_pass "Backend 健康状态: healthy"
elif [ "$BACKEND_HEALTH" = "starting" ]; then
    check_warn "Backend 健康状态: starting（正在启动）"
else
    check_fail "Backend 健康状态: $BACKEND_HEALTH"
fi

NGINX_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$NGINX_CONTAINER" 2>/dev/null || echo "none")
if [ "$NGINX_HEALTH" = "healthy" ]; then
    check_pass "Nginx 健康状态: healthy"
elif [ "$NGINX_HEALTH" = "starting" ]; then
    check_warn "Nginx 健康状态: starting（正在启动）"
else
    check_fail "Nginx 健康状态: $NGINX_HEALTH"
fi

echo ""
echo "[4] 检查资源限制"
BACKEND_MEM=$(docker inspect --format='{{.HostConfig.Memory}}' "$BACKEND_CONTAINER")
BACKEND_MEM_MB=$((BACKEND_MEM / 1024 / 1024))
if [ "$BACKEND_MEM_MB" -eq 512 ]; then
    check_pass "Backend 内存限制: 512MB"
elif [ "$BACKEND_MEM" -eq 0 ]; then
    check_warn "Backend 内存限制: 未设置（仅在 Swarm 模式生效）"
else
    check_fail "Backend 内存限制: ${BACKEND_MEM_MB}MB（预期: 512MB）"
fi

NGINX_MEM=$(docker inspect --format='{{.HostConfig.Memory}}' "$NGINX_CONTAINER")
NGINX_MEM_MB=$((NGINX_MEM / 1024 / 1024))
if [ "$NGINX_MEM_MB" -eq 256 ]; then
    check_pass "Nginx 内存限制: 256MB"
elif [ "$NGINX_MEM" -eq 0 ]; then
    check_warn "Nginx 内存限制: 未设置（仅在 Swarm 模式生效）"
else
    check_fail "Nginx 内存限制: ${NGINX_MEM_MB}MB（预期: 256MB）"
fi

echo ""
echo "[5] 检查日志限制"
BACKEND_LOG_MAX=$(docker inspect --format='{{.HostConfig.LogConfig.Config.max-size}}' "$BACKEND_CONTAINER")
if [ "$BACKEND_LOG_MAX" = "10m" ]; then
    check_pass "Backend 日志大小限制: 10m"
else
    check_fail "Backend 日志大小限制: $BACKEND_LOG_MAX（预期: 10m）"
fi

BACKEND_LOG_FILES=$(docker inspect --format='{{.HostConfig.LogConfig.Config.max-file}}' "$BACKEND_CONTAINER")
if [ "$BACKEND_LOG_FILES" = "5" ]; then
    check_pass "Backend 日志文件数量: 5"
else
    check_fail "Backend 日志文件数量: $BACKEND_LOG_FILES（预期: 5）"
fi

echo ""
echo "[6] 检查重启策略"
BACKEND_RESTART=$(docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' "$BACKEND_CONTAINER")
if [ "$BACKEND_RESTART" = "unless-stopped" ]; then
    check_pass "Backend 重启策略: unless-stopped"
else
    check_fail "Backend 重启策略: $BACKEND_RESTART（预期: unless-stopped）"
fi

NGINX_RESTART=$(docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' "$NGINX_CONTAINER")
if [ "$NGINX_RESTART" = "unless-stopped" ]; then
    check_pass "Nginx 重启策略: unless-stopped"
else
    check_fail "Nginx 重启策略: $NGINX_RESTART（预期: unless-stopped）"
fi

echo ""
echo "[7] 检查安全选项"
BACKEND_SECOPT=$(docker inspect --format='{{json .HostConfig.SecurityOpt}}' "$BACKEND_CONTAINER")
if echo "$BACKEND_SECOPT" | grep -q "no-new-privileges:true"; then
    check_pass "Backend 安全选项: no-new-privileges 已启用"
else
    check_fail "Backend 安全选项: no-new-privileges 未启用"
fi

NGINX_SECOPT=$(docker inspect --format='{{json .HostConfig.SecurityOpt}}' "$NGINX_CONTAINER")
if echo "$NGINX_SECOPT" | grep -q "no-new-privileges:true"; then
    check_pass "Nginx 安全选项: no-new-privileges 已启用"
else
    check_fail "Nginx 安全选项: no-new-privileges 未启用"
fi

echo ""
echo "[8] 测试健康检查端点"
if curl -sf http://localhost/health > /dev/null; then
    check_pass "健康检查端点响应正常"
else
    check_fail "健康检查端点无响应"
fi

echo ""
echo "[9] 测试文件写入权限（应该被限制）"
if docker exec "$BACKEND_CONTAINER" sh -c "echo test > /test.txt 2>/dev/null"; then
    check_fail "Backend 可以写入根目录（安全风险）"
    docker exec "$BACKEND_CONTAINER" rm -f /test.txt 2>/dev/null || true
else
    check_pass "Backend 无法写入根目录（符合预期）"
fi

echo ""
echo "====================================="
echo "测试结果汇总"
echo "====================================="
echo -e "${GREEN}通过: $PASS${NC}"
echo -e "${RED}失败: $FAIL${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过！${NC}"
    exit 0
else
    echo -e "${RED}✗ 有 $FAIL 项测试失败${NC}"
    exit 1
fi

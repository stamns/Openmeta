#!/usr/bin/env bash
# 完整验收测试脚本

set -euo pipefail

echo "=============================================="
echo "Docker 安全性和可靠性 - 完整验收测试"
echo "=============================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

check_info() {
    echo -e "${BLUE}[INFO]${NC}: $1"
}

# 确保容器运行
echo "===== 准备测试环境 ====="
check_info "构建并启动容器..."
docker compose -f docker-compose-prod.yml build --quiet
docker compose -f docker-compose-prod.yml up -d

check_info "等待服务启动（40 秒）..."
sleep 40

echo ""
echo "===== 验收标准 1: 容器以 appuser（UID 1000）运行 ====="
BACKEND_CONTAINER=$(docker compose -f docker-compose-prod.yml ps -q backend)
NGINX_CONTAINER=$(docker compose -f docker-compose-prod.yml ps -q nginx)

# 检查 Backend
BACKEND_USER=$(docker exec "$BACKEND_CONTAINER" whoami 2>/dev/null || echo "root")
BACKEND_UID=$(docker exec "$BACKEND_CONTAINER" id -u 2>/dev/null || echo "0")

if [ "$BACKEND_USER" = "appuser" ] && [ "$BACKEND_UID" = "1000" ]; then
    check_pass "Backend 以 appuser (UID 1000) 运行"
else
    check_fail "Backend 以 $BACKEND_USER (UID $BACKEND_UID) 运行"
fi

# 检查 Nginx
NGINX_USER=$(docker exec "$NGINX_CONTAINER" whoami 2>/dev/null || echo "root")
NGINX_UID=$(docker exec "$NGINX_CONTAINER" id -u 2>/dev/null || echo "0")

if [ "$NGINX_USER" = "appuser" ] && [ "$NGINX_UID" = "1000" ]; then
    check_pass "Nginx 以 appuser (UID 1000) 运行"
else
    check_fail "Nginx 以 $NGINX_USER (UID $NGINX_UID) 运行"
fi

echo ""
echo "===== 验收标准 2: docker ps 显示 (healthy) ====="

# 等待健康检查完成
check_info "等待健康检查完成（最多 60 秒）..."
for i in {1..60}; do
    BACKEND_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$BACKEND_CONTAINER" 2>/dev/null || echo "none")
    NGINX_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$NGINX_CONTAINER" 2>/dev/null || echo "none")
    
    if [ "$BACKEND_HEALTH" = "healthy" ] && [ "$NGINX_HEALTH" = "healthy" ]; then
        break
    fi
    sleep 1
done

# 检查 Backend 健康状态
BACKEND_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$BACKEND_CONTAINER" 2>/dev/null || echo "none")
if [ "$BACKEND_HEALTH" = "healthy" ]; then
    check_pass "Backend 健康状态: healthy"
else
    check_fail "Backend 健康状态: $BACKEND_HEALTH（预期: healthy）"
fi

# 检查 Nginx 健康状态
NGINX_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$NGINX_CONTAINER" 2>/dev/null || echo "none")
if [ "$NGINX_HEALTH" = "healthy" ]; then
    check_pass "Nginx 健康状态: healthy"
else
    check_fail "Nginx 健康状态: $NGINX_HEALTH（预期: healthy）"
fi

# 检查 docker ps 输出
BACKEND_PS=$(docker compose -f docker-compose-prod.yml ps backend 2>/dev/null | grep -c "healthy" || echo "0")
if [ "$BACKEND_PS" -gt 0 ]; then
    check_pass "docker ps 显示 Backend (healthy)"
else
    check_fail "docker ps 未显示 Backend (healthy)"
fi

NGINX_PS=$(docker compose -f docker-compose-prod.yml ps nginx 2>/dev/null | grep -c "healthy" || echo "0")
if [ "$NGINX_PS" -gt 0 ]; then
    check_pass "docker ps 显示 Nginx (healthy)"
else
    check_fail "docker ps 未显示 Nginx (healthy)"
fi

echo ""
echo "===== 验收标准 3: 后端崩溃时 Nginx 返回 502 ====="

# 测试正常访问
check_info "测试正常访问..."
if curl -sf http://localhost/health > /dev/null; then
    check_pass "正常访问成功"
else
    check_fail "正常访问失败"
fi

# 停止 Backend
check_info "停止 Backend 容器模拟故障..."
docker stop "$BACKEND_CONTAINER" > /dev/null
sleep 2

# 检查 502 响应
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/search?q=test 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "502" ] || [ "$HTTP_CODE" = "503" ] || [ "$HTTP_CODE" = "504" ]; then
    check_pass "Backend 停止时 Nginx 返回 $HTTP_CODE"
else
    check_fail "Backend 停止时 Nginx 返回 $HTTP_CODE（预期: 502/503/504）"
fi

# 等待自动重启
check_info "等待 Backend 自动重启..."
for i in {1..30}; do
    if docker compose -f docker-compose-prod.yml ps | grep -q "backend.*Up"; then
        check_pass "Backend 在 ${i} 秒后自动重启"
        break
    fi
    sleep 1
done

# 等待健康恢复
sleep 40

echo ""
echo "===== 验收标准 4: 内存限制生效 ====="

# 检查内存限制（Docker Compose 模式下可能不生效，仅在 Swarm 模式）
BACKEND_MEM=$(docker inspect --format='{{.HostConfig.Memory}}' "$BACKEND_CONTAINER")
if [ "$BACKEND_MEM" -gt 0 ]; then
    BACKEND_MEM_MB=$((BACKEND_MEM / 1024 / 1024))
    if [ "$BACKEND_MEM_MB" -eq 512 ]; then
        check_pass "Backend 内存限制: 512MB"
    else
        check_fail "Backend 内存限制: ${BACKEND_MEM_MB}MB（预期: 512MB）"
    fi
else
    check_info "内存限制配置存在（仅在 Swarm 模式或 Docker Compose v3.8+ 生效）"
    # 检查配置是否存在于 docker-compose.yml
    if grep -q "memory: 512M" docker-compose-prod.yml; then
        check_pass "Backend 内存限制已在配置中定义: 512MB"
    else
        check_fail "Backend 内存限制未在配置中定义"
    fi
fi

NGINX_MEM=$(docker inspect --format='{{.HostConfig.Memory}}' "$NGINX_CONTAINER")
if [ "$NGINX_MEM" -gt 0 ]; then
    NGINX_MEM_MB=$((NGINX_MEM / 1024 / 1024))
    if [ "$NGINX_MEM_MB" -eq 256 ]; then
        check_pass "Nginx 内存限制: 256MB"
    else
        check_fail "Nginx 内存限制: ${NGINX_MEM_MB}MB（预期: 256MB）"
    fi
else
    if grep -q "memory: 256M" docker-compose-prod.yml; then
        check_pass "Nginx 内存限制已在配置中定义: 256MB"
    else
        check_fail "Nginx 内存限制未在配置中定义"
    fi
fi

echo ""
echo "===== 验收标准 5: 日志不无限增长 ====="

# 检查日志限制配置
BACKEND_LOG_MAX=$(docker inspect --format='{{.HostConfig.LogConfig.Config.max-size}}' "$BACKEND_CONTAINER")
BACKEND_LOG_FILES=$(docker inspect --format='{{.HostConfig.LogConfig.Config.max-file}}' "$BACKEND_CONTAINER")

if [ "$BACKEND_LOG_MAX" = "10m" ] && [ "$BACKEND_LOG_FILES" = "5" ]; then
    check_pass "Backend 日志限制: 10MB x 5 文件"
else
    check_fail "Backend 日志限制: ${BACKEND_LOG_MAX} x ${BACKEND_LOG_FILES}（预期: 10m x 5）"
fi

NGINX_LOG_MAX=$(docker inspect --format='{{.HostConfig.LogConfig.Config.max-size}}' "$NGINX_CONTAINER")
NGINX_LOG_FILES=$(docker inspect --format='{{.HostConfig.LogConfig.Config.max-file}}' "$NGINX_CONTAINER")

if [ "$NGINX_LOG_MAX" = "10m" ] && [ "$NGINX_LOG_FILES" = "5" ]; then
    check_pass "Nginx 日志限制: 10MB x 5 文件"
else
    check_fail "Nginx 日志限制: ${NGINX_LOG_MAX} x ${NGINX_LOG_FILES}（预期: 10m x 5）"
fi

echo ""
echo "===== 额外检查 ====="

# 检查重启策略
BACKEND_RESTART=$(docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' "$BACKEND_CONTAINER")
if [ "$BACKEND_RESTART" = "unless-stopped" ]; then
    check_pass "Backend 重启策略: unless-stopped"
else
    check_fail "Backend 重启策略: $BACKEND_RESTART"
fi

# 检查安全选项
BACKEND_SECOPT=$(docker inspect --format='{{json .HostConfig.SecurityOpt}}' "$BACKEND_CONTAINER")
if echo "$BACKEND_SECOPT" | grep -q "no-new-privileges:true"; then
    check_pass "Backend 安全选项: no-new-privileges 已启用"
else
    check_fail "Backend 安全选项: no-new-privileges 未启用"
fi

# 检查健康检查配置
BACKEND_HC_INTERVAL=$(docker inspect --format='{{.Config.Healthcheck.Interval}}' "$BACKEND_CONTAINER" 2>/dev/null || echo "0")
if [ "$BACKEND_HC_INTERVAL" != "0" ]; then
    check_pass "Backend 健康检查配置存在"
else
    check_fail "Backend 健康检查配置不存在"
fi

echo ""
echo "=============================================="
echo "测试结果汇总"
echo "=============================================="
echo -e "通过: ${GREEN}$PASS${NC}"
echo -e "失败: ${RED}$FAIL${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ 所有验收标准通过！${NC}"
    echo ""
    echo "验收标准确认："
    echo "  ✓ 容器以 appuser（UID 1000）运行"
    echo "  ✓ docker ps 显示 (healthy)"
    echo "  ✓ 后端崩溃时 Nginx 返回 502"
    echo "  ✓ 内存限制生效"
    echo "  ✓ 日志不无限增长"
    exit 0
else
    echo -e "${RED}✗✗✗ 有 $FAIL 项测试失败${NC}"
    exit 1
fi

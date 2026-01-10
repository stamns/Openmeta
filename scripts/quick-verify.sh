#!/usr/bin/env bash
# 快速验证 Docker 安全性和可靠性配置

set -euo pipefail

echo "快速验证 Docker 安全性和可靠性配置"
echo "======================================"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}

# 1. 检查 Dockerfile 配置
echo "[1] 检查 Dockerfile 配置"
grep -q "USER appuser" backend/Dockerfile
check "Backend Dockerfile 使用 appuser"

grep -q "USER appuser" deploy/nginx/Dockerfile
check "Nginx Dockerfile 使用 appuser"

grep -q "HEALTHCHECK" backend/Dockerfile
check "Backend Dockerfile 包含健康检查"

grep -q "HEALTHCHECK" deploy/nginx/Dockerfile
check "Nginx Dockerfile 包含健康检查"

echo ""

# 2. 检查 docker-compose 配置
echo "[2] 检查 docker-compose.yml 配置"
grep -q "restart: unless-stopped" docker-compose.yml
check "开发环境配置重启策略"

grep -q "healthcheck:" docker-compose.yml
check "开发环境配置健康检查"

grep -q "resources:" docker-compose.yml
check "开发环境配置资源限制"

grep -q "no-new-privileges:true" docker-compose.yml
check "开发环境配置安全选项"

echo ""

# 3. 检查 docker-compose-prod 配置
echo "[3] 检查 docker-compose-prod.yml 配置"
grep -q "restart: unless-stopped" docker-compose-prod.yml
check "生产环境配置重启策略"

grep -q "condition: service_healthy" docker-compose-prod.yml
check "生产环境配置服务依赖"

grep -q "memory: 512M" docker-compose-prod.yml
check "生产环境配置 Backend 内存限制"

grep -q "memory: 256M" docker-compose-prod.yml
check "生产环境配置 Nginx 内存限制"

grep -q "max-size: \"10m\"" docker-compose-prod.yml
check "生产环境配置日志限制"

grep -q "no-new-privileges:true" docker-compose-prod.yml
check "生产环境配置安全选项"

echo ""

# 4. 检查 nginx 配置
echo "[4] 检查 Nginx 配置"
grep -q "user appuser;" deploy/nginx/nginx.conf
check "Nginx 配置使用 appuser"

grep -q "gzip on;" deploy/nginx/nginx.conf
check "Nginx 配置启用 Gzip"

grep -q "proxy_cache_path" deploy/nginx/nginx.conf
check "Nginx 配置 API 缓存"

echo ""

# 5. 检查测试脚本
echo "[5] 检查测试脚本"
[ -x scripts/test-docker-security.sh ]
check "安全性测试脚本可执行"

[ -x scripts/test-failover.sh ]
check "故障转移测试脚本可执行"

[ -x scripts/acceptance-test.sh ]
check "验收测试脚本可执行"

echo ""

# 6. 检查文档
echo "[6] 检查文档"
[ -f docs/docker-security-reliability.md ]
check "安全性和可靠性文档存在"

[ -f DOCKER-SECURITY-COMPLETE.md ]
check "改进总结文档存在"

echo ""
echo "======================================"
echo -e "${GREEN}配置验证完成！${NC}"
echo ""
echo "下一步："
echo "  1. 运行完整验收测试: ./scripts/acceptance-test.sh"
echo "  2. 启动服务: docker compose -f docker-compose-prod.yml up -d"
echo "  3. 查看状态: docker compose -f docker-compose-prod.yml ps"

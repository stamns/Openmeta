#!/bin/bash
# 快速 Docker 安全性检查脚本

set -e

echo "=========================================="
echo "Docker 安全性快速检查"
echo "=========================================="
echo ""

# 检查容器是否运行
echo "[1/5] 检查容器状态..."
docker compose -f docker-compose-prod.yml ps

echo ""
echo "[2/5] 检查容器用户..."
if docker compose -f docker-compose-prod.yml ps -q backend | grep -q .; then
    BACKEND_USER=$(docker compose -f docker-compose-prod.yml ps -q backend | xargs -I {} docker exec {} whoami 2>/dev/null || echo "无法确定")
    echo "  Backend 用户: $BACKEND_USER"
fi

if docker compose -f docker-compose-prod.yml ps -q nginx | grep -q .; then
    NGINX_USER=$(docker compose -f docker-compose-prod.yml ps -q nginx | xargs -I {} docker exec {} whoami 2>/dev/null || echo "无法确定")
    echo "  Nginx 用户: $NGINX_USER"
fi

echo ""
echo "[3/5] 检查健康状态..."
docker compose -f docker-compose-prod.yml ps --format "table {{.Name}}\t{{.Status}}"

echo ""
echo "[4/5] 检查健康端点..."
echo "  Backend /health:"
curl -s -f http://localhost:8000/health 2>/dev/null && echo "    [OK]" || echo "    [FAIL]"

echo "  Nginx /health:"
curl -s -f http://localhost/health 2>/dev/null && echo "    [OK]" || echo "    [FAIL/未配置]"

echo ""
echo "[5/5] 检查资源限制..."
echo "  Backend 资源限制:"
docker compose -f docker-compose-prod.yml ps -q backend | grep -q . && \
    docker inspect $(docker compose -f docker-compose-prod.yml ps -q backend | head -1) | \
    jq -r '.[0].HostConfig | "    内存: \(.Memory // "未设置" | if type=="number" then ./(1024*1024)|floor|tostring + "MB" else . end)\n    CPU: \(.NanoCpus // "未设置" | if type=="number" then ./1e9|tostring + " cores" else . end)"'

echo "  Nginx 资源限制:"
docker compose -f docker-compose-prod.yml ps -q nginx | grep -q . && \
    docker inspect $(docker compose -f docker-compose-prod.yml ps -q nginx | head -1) | \
    jq -r '.[0].HostConfig | "    内存: \(.Memory // "未设置" | if type=="number" then ./(1024*1024)|floor|to_string + "MB" else . end)\n    CPU: \(.NanoCpus // "未设置" | if type=="number" then ./1e9|to_string + " cores" else . end)"'

echo ""
echo "=========================================="
echo "快速检查完成"
echo "=========================================="
echo ""
echo "完整测试请运行: python scripts/test_docker_security.py"

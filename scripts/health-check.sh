#!/bin/bash

# Docker 容器健康检查脚本
# 用于验证容器安全性和可靠性配置

set -e

echo "=== Docker 容器安全性和可靠性检查 ==="
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

# 检查容器是否以非 root 用户运行
check_non_root_user() {
    echo "1. 检查非 root 用户运行..."
    
    # 检查 backend 容器
    BACKEND_USER=$(docker compose -f docker-compose-prod.yml exec -T backend id -u 2>/dev/null || echo "N/A")
    if [ "$BACKEND_USER" = "1000" ]; then
        print_status 0 "Backend 容器以 appuser (UID 1000) 运行"
    else
        print_status 1 "Backend 容器未以非 root 用户运行 (当前: $BACKEND_USER)"
    fi
    
    # 检查 nginx 容器
    NGINX_USER=$(docker compose -f docker-compose-prod.yml exec -T nginx id -u 2>/dev/null || echo "N/A")
    if [ "$NGINX_USER" = "1000" ]; then
        print_status 0 "Nginx 容器以 appuser (UID 1000) 运行"
    else
        print_status 1 "Nginx 容器未以非 root 用户运行 (当前: $NGINX_USER)"
    fi
    echo
}

# 检查健康状态
check_health_status() {
    echo "2. 检查健康状态..."
    
    BACKEND_HEALTH=$(docker compose -f docker-compose-prod.yml ps backend --format "table {{.Service}}\t{{.Status}}" | grep backend | grep -o "(healthy)" || echo "")
    if [ -n "$BACKEND_HEALTH" ]; then
        print_status 0 "Backend 容器健康状态正常"
    else
        print_status 1 "Backend 容器健康状态异常"
    fi
    
    NGINX_HEALTH=$(docker compose -f docker-compose-prod.yml ps nginx --format "table {{.Service}}\t{{.Status}}" | grep nginx | grep -o "(healthy)" || echo "")
    if [ -n "$NGINX_HEALTH" ]; then
        print_status 0 "Nginx 容器健康状态正常"
    else
        print_status 1 "Nginx 容器健康状态异常"
    fi
    echo
}

# 检查资源限制
check_resource_limits() {
    echo "3. 检查资源限制..."
    
    print_info "Backend 资源限制："
    docker compose -f docker-compose-prod.yml exec -T backend cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null | \
        awk '{printf "  内存限制: %dMB\n", $1/1024/1024}' || echo "  无法获取内存限制"
    
    print_info "Nginx 资源限制："
    docker compose -f docker-compose-prod.yml exec -T nginx cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null | \
        awk '{printf "  内存限制: %dMB\n", $1/1024/1024}' || echo "  无法获取内存限制"
    echo
}

# 检查安全配置
check_security_config() {
    echo "4. 检查安全配置..."
    
    # 检查 no-new-privileges
    BACKEND_PRIV=$(docker compose -f docker-compose-prod.yml inspect backend | grep -o "no-new-privileges" | head -1 || echo "")
    if [ -n "$BACKEND_PRIV" ]; then
        print_status 0 "Backend 启用了 no-new-privileges"
    else
        print_status 1 "Backend 未启用 no-new-privileges"
    fi
    
    # 检查 capability drop
    BACKEND_CAP_DROP=$(docker compose -f docker-compose-prod.yml inspect backend | grep -A5 "CapDrop" | grep -o "ALL" || echo "")
    if [ -n "$BACKEND_CAP_DROP" ]; then
        print_status 0 "Backend 禁用了所有 capabilities"
    else
        print_status 1 "Backend 未禁用所有 capabilities"
    fi
    echo
}

# 检查故障转移机制
check_failover() {
    echo "5. 检查故障转移机制..."
    
    BACKEND_RESTART=$(docker compose -f docker-compose-prod.yml inspect backend | grep -o "unless-stopped" | head -1 || echo "")
    if [ -n "$BACKEND_RESTART" ]; then
        print_status 0 "Backend 启用了自动重启"
    else
        print_status 1 "Backend 未启用自动重启"
    fi
    
    NGINX_RESTART=$(docker compose -f docker-compose-prod.yml inspect nginx | grep -o "unless-stopped" | head -1 || echo "")
    if [ -n "$NGINX_RESTART" ]; then
        print_status 0 "Nginx 启用了自动重启"
    else
        print_status 1 "Nginx 未启用自动重启"
    fi
    echo
}

# 检查服务依赖
check_service_dependencies() {
    echo "6. 检查服务依赖..."
    
    NGINX_DEPENDS=$(docker compose -f docker-compose-prod.yml config | grep -A10 "nginx:" | grep -o "condition: service_healthy" || echo "")
    if [ -n "$NGINX_DEPENDS" ]; then
        print_status 0 "Nginx 依赖 Backend 健康状态"
    else
        print_status 1 "Nginx 未依赖 Backend 健康状态"
    fi
    echo
}

# 主函数
main() {
    echo "开始 Docker 容器安全性和可靠性检查..."
    echo "时间: $(date)"
    echo
    
    check_non_root_user
    check_health_status
    check_resource_limits
    check_security_config
    check_failover
    check_service_dependencies
    
    echo "=== 检查完成 ==="
    echo
    print_info "建议："
    echo "  - 如果有检查项失败，请检查相应的 Docker 配置"
    echo "  - 确保所有容器都显示 (healthy) 状态"
    echo "  - 验证资源限制是否按预期生效"
    echo "  - 测试故障转移机制是否正常工作"
}

# 检查 Docker Compose 是否运行
if ! docker compose -f docker-compose-prod.yml ps >/dev/null 2>&1; then
    echo "❌ 无法连接到 Docker Compose 服务"
    echo "请确保生产环境容器正在运行："
    echo "  docker compose -f docker-compose-prod.yml up -d"
    exit 1
fi

main
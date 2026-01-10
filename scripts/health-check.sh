#!/bin/bash

# Docker 容器健康检查脚本
# 用于验证容器安全性和可靠性配置

set -e

COMPOSE_FILE="docker-compose-prod.yml"

usage() {
    echo "用法: $0 [-f <compose-file>]"
    echo
    echo "选项:"
    echo "  -f <compose-file>  指定 docker compose 配置文件 (默认: docker-compose-prod.yml)"
    echo "  -h                 显示帮助"
}

while getopts "f:h" opt; do
    case "$opt" in
        f)
            COMPOSE_FILE="$OPTARG"
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

COMPOSE_CMD=(docker compose -f "$COMPOSE_FILE")

echo "=== Docker 容器安全性和可靠性检查 ==="
echo "Compose 文件: $COMPOSE_FILE"
echo

# 状态输出函数
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

get_container_id() {
    local service="$1"
    "${COMPOSE_CMD[@]}" ps -q "$service" 2>/dev/null || true
}

get_health_status() {
    local service="$1"
    local cid

    cid="$(get_container_id "$service")"
    if [ -z "$cid" ]; then
        echo ""
        return 0
    fi

    docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$cid" 2>/dev/null || true
}

print_memory_limit() {
    local service="$1"
    local cid
    local raw

    cid="$(get_container_id "$service")"
    if [ -z "$cid" ]; then
        echo "  容器未运行，跳过"
        return 0
    fi

    raw=$("${COMPOSE_CMD[@]}" exec -T "$service" sh -c 'if [ -f /sys/fs/cgroup/memory.max ]; then cat /sys/fs/cgroup/memory.max; elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then cat /sys/fs/cgroup/memory/memory.limit_in_bytes; fi' 2>/dev/null || true)

    if [ -z "$raw" ]; then
        echo "  无法获取内存限制"
        return 0
    fi

    if [ "$raw" = "max" ] || [ "$raw" = "9223372036854771712" ] || [ "$raw" = "9223372036854775807" ]; then
        echo "  内存限制: unlimited"
        return 0
    fi

    awk -v b="$raw" 'BEGIN{printf "  内存限制: %.0fMB\n", b/1024/1024}'
}

# 检查容器是否以非 root 用户运行
check_non_root_user() {
    echo "1. 检查非 root 用户运行..."

    BACKEND_USER=$("${COMPOSE_CMD[@]}" exec -T backend id -u 2>/dev/null || echo "N/A")
    if [ "$BACKEND_USER" = "1000" ]; then
        print_status 0 "Backend 容器以 appuser (UID 1000) 运行"
    else
        print_status 1 "Backend 容器未以非 root 用户运行 (当前: $BACKEND_USER)"
    fi

    NGINX_USER=$("${COMPOSE_CMD[@]}" exec -T nginx id -u 2>/dev/null || echo "N/A")
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

    BACKEND_HEALTH="$(get_health_status backend)"
    if [ "$BACKEND_HEALTH" = "healthy" ]; then
        print_status 0 "Backend 容器健康状态正常"
    else
        print_status 1 "Backend 容器健康状态异常 (当前: ${BACKEND_HEALTH:-N/A})"
    fi

    NGINX_HEALTH="$(get_health_status nginx)"
    if [ "$NGINX_HEALTH" = "healthy" ]; then
        print_status 0 "Nginx 容器健康状态正常"
    else
        print_status 1 "Nginx 容器健康状态异常 (当前: ${NGINX_HEALTH:-N/A})"
    fi
    echo
}

# 检查资源限制
check_resource_limits() {
    echo "3. 检查资源限制..."

    print_info "Backend 资源限制："
    print_memory_limit backend

    print_info "Nginx 资源限制："
    print_memory_limit nginx

    echo
}

# 检查安全配置
check_security_config() {
    echo "4. 检查安全配置..."

    BACKEND_SEC=$("${COMPOSE_CMD[@]}" inspect backend 2>/dev/null | grep -o "no-new-privileges" | head -1 || echo "")
    if [ -n "$BACKEND_SEC" ]; then
        print_status 0 "Backend 启用了 no-new-privileges"
    else
        print_status 1 "Backend 未启用 no-new-privileges"
    fi

    BACKEND_CAP_DROP=$("${COMPOSE_CMD[@]}" inspect backend 2>/dev/null | grep -A5 "CapDrop" | grep -o "ALL" || echo "")
    if [ -n "$BACKEND_CAP_DROP" ]; then
        print_status 0 "Backend 禁用了所有 capabilities"
    else
        print_status 1 "Backend 未禁用所有 capabilities"
    fi

    BACKEND_RO=$("${COMPOSE_CMD[@]}" inspect backend 2>/dev/null | grep -o '"ReadonlyRootfs":true' | head -1 || echo "")
    if [ -n "$BACKEND_RO" ]; then
        print_status 0 "Backend 启用了只读根文件系统 (read_only)"
    else
        print_status 1 "Backend 未启用只读根文件系统 (read_only)"
    fi

    NGINX_RO=$("${COMPOSE_CMD[@]}" inspect nginx 2>/dev/null | grep -o '"ReadonlyRootfs":true' | head -1 || echo "")
    if [ -n "$NGINX_RO" ]; then
        print_status 0 "Nginx 启用了只读根文件系统 (read_only)"
    else
        print_status 1 "Nginx 未启用只读根文件系统 (read_only)"
    fi

    echo
}

# 检查故障转移机制
check_failover() {
    echo "5. 检查故障转移机制..."

    BACKEND_RESTART=$("${COMPOSE_CMD[@]}" inspect backend 2>/dev/null | grep -o "unless-stopped" | head -1 || echo "")
    if [ -n "$BACKEND_RESTART" ]; then
        print_status 0 "Backend 启用了自动重启"
    else
        print_status 1 "Backend 未启用自动重启"
    fi

    NGINX_RESTART=$("${COMPOSE_CMD[@]}" inspect nginx 2>/dev/null | grep -o "unless-stopped" | head -1 || echo "")
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

    NGINX_DEPENDS=$("${COMPOSE_CMD[@]}" config 2>/dev/null | grep -A10 "nginx:" | grep -o "condition: service_healthy" || echo "")
    if [ -n "$NGINX_DEPENDS" ]; then
        print_status 0 "Nginx 依赖 Backend 健康状态"
    else
        print_status 1 "Nginx 未依赖 Backend 健康状态"
    fi

    echo
}

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

if ! "${COMPOSE_CMD[@]}" ps >/dev/null 2>&1; then
    echo "❌ 无法连接到 Docker Compose 服务"
    echo "请确保容器正在运行，例如："
    echo "  docker compose -f $COMPOSE_FILE up -d"
    exit 1
fi

main

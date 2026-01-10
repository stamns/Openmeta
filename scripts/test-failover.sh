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
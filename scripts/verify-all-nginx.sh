#!/bin/bash
# Nginx 优化完整验证脚本

echo "============================================================"
echo "           Nginx 性能优化 - 完整验证"
echo "============================================================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0

# 检查函数
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} 文件存在: $1"
        ((passed++))
    else
        echo -e "${RED}✗${NC} 文件缺失: $1"
        ((failed++))
    fi
}

check_config() {
    local file=$1
    local pattern=$2
    local desc=$3

    if grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓${NC} $desc"
        ((passed++))
    else
        echo -e "${RED}✗${NC} $desc (未在 $file 中找到)"
        ((failed++))
    fi
}

# 1. 检查文件存在性
echo "1. 检查配置文件"
echo "------------------------"
check_file "nginx_conf/default.conf"
check_file "deploy/nginx/nginx.conf"
check_file "deploy/nginx/Dockerfile"
check_file "scripts/test_nginx_optimization.py"
check_file "docs/nginx-optimization.md"
check_file "NGINX-OPTIMIZATION-COMPLETE.md"
echo ""

# 2. 检查 Gzip 配置
echo "2. 检查 Gzip 压缩配置"
echo "------------------------"
check_config "deploy/nginx/nginx.conf" "gzip on" "Gzip 启用"
check_config "deploy/nginx/nginx.conf" "gzip_comp_level 6" "压缩级别 6"
check_config "deploy/nginx/nginx.conf" "gzip_min_length 500" "最小压缩 500 字节"
check_config "deploy/nginx/nginx.conf" "application/json" "JSON 类型支持"
check_config "deploy/nginx/nginx.conf" "application/javascript" "JavaScript 类型支持"
check_config "deploy/nginx/nginx.conf" "text/css" "CSS 类型支持"
echo ""

# 3. 检查静态缓存配置
echo "3. 检查静态文件缓存"
echo "------------------------"
check_config "nginx_conf/default.conf" "expires 365d" "JS/CSS 缓存 365 天"
check_config "nginx_conf/default.conf" "public, immutable" "不可变缓存策略"
check_config "nginx_conf/default.conf" "expires -1" "HTML 禁用缓存"
check_config "nginx_conf/default.conf" "no-cache, no-store" "HTML 缓存控制"
echo ""

# 4. 检查安全头配置
echo "4. 检查安全 HTTP 头"
echo "------------------------"
check_config "nginx_conf/default.conf" "X-Frame-Options.*SAMEORIGIN" "X-Frame-Options"
check_config "nginx_conf/default.conf" "X-Content-Type-Options.*nosniff" "X-Content-Type-Options"
check_config "nginx_conf/default.conf" "X-XSS-Protection" "X-XSS-Protection"
check_config "nginx_conf/default.conf" "Referrer-Policy" "Referrer-Policy"
check_config "nginx_conf/default.conf" "Permissions-Policy" "Permissions-Policy"
check_config "nginx_conf/default.conf" "server_tokens off" "隐藏 Nginx 版本号"
echo ""

# 5. 检查 API 缓存配置
echo "5. 检查 API 响应缓存"
echo "------------------------"
check_config "nginx_conf/default.conf" "proxy_cache api_cache" "API 缓存启用"
check_config "nginx_conf/default.conf" "proxy_cache_valid.*10m" "10 分钟缓存"
check_config "nginx_conf/default.conf" "proxy_cache_lock on" "缓存锁"
check_config "nginx_conf/default.conf" "proxy_cache_background_update on" "后台更新"
check_config "deploy/nginx/nginx.conf" "proxy_cache_path" "缓存路径配置"
check_config "nginx_conf/default.conf" "X-Cache-Status" "缓存状态头"
echo ""

# 6. 检查连接和缓冲优化
echo "6. 检查连接和缓冲优化"
echo "------------------------"
check_config "nginx_conf/default.conf" "keepalive 32" "连接复用 (32)"
check_config "nginx_conf/default.conf" "proxy_buffering on" "代理缓冲启用"
check_config "nginx_conf/default.conf" "proxy_buffer_size 4k" "缓冲区 4k"
check_config "nginx_conf/default.conf" "proxy_connect_timeout 5s" "连接超时 5s"
check_config "nginx_conf/default.conf" "proxy_read_timeout 10s" "读取超时 10s"
check_config "deploy/nginx/nginx.conf" "worker_connections 1024" "工作连接数 1024"
check_config "deploy/nginx/nginx.conf" "sendfile on" "sendfile 优化"
check_config "deploy/nginx/nginx.conf" "tcp_nodelay on" "TCP 优化"
echo ""

# 7. 检查日志优化
echo "7. 检查日志优化"
echo "------------------------"
check_config "deploy/nginx/nginx.conf" 'rt=\$request_time' "请求时间"
check_config "deploy/nginx/nginx.conf" 'uct="\$upstream_connect_time"' "连接时间"
check_config "deploy/nginx/nginx.conf" 'uht="\$upstream_header_time"' "响应头时间"
check_config "deploy/nginx/nginx.conf" 'urt="\$upstream_response_time"' "响应体时间"
check_config "deploy/nginx/nginx.conf" 'cache="\$upstream_cache_status"' "缓存状态"
echo ""

# 8. 检查 Docker 配置
echo "8. 检查 Docker 配置"
echo "------------------------"
check_config "deploy/nginx/Dockerfile" "deploy/nginx/nginx.conf" "自定义 nginx.conf"
check_config "deploy/nginx/Dockerfile" "mkdir -p /var/cache/nginx" "缓存目录创建"
check_config "deploy/nginx/Dockerfile" "HEALTHCHECK" "健康检查"
check_config "docker-compose-prod.yml" "nginx-cache:" "缓存卷配置"
check_config "docker-compose-prod.yml" "nginx-logs:" "日志卷配置"
check_config "docker-compose-prod.yml" "deploy/nginx/Dockerfile" "Nginx Dockerfile"
echo ""

# 总结
echo "============================================================"
echo "                      验证总结"
echo "============================================================"
echo -e "通过: ${GREEN}${passed}${NC}"
echo -e "失败: ${RED}${failed}${NC}"
echo ""

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}✓ 所有验证通过！${NC}"
    echo ""
    echo "下一步："
    echo "  1. 构建镜像: docker-compose -f docker-compose-prod.yml build"
    echo "  2. 启动服务: docker-compose -f docker-compose-prod.yml up -d"
    echo "  3. 运行测试: python scripts/test_nginx_optimization.py"
    echo ""
    exit 0
else
    echo -e "${RED}✗ 有 $failed 个验证失败${NC}"
    echo ""
    echo "请检查上述失败项并修复。"
    echo ""
    exit 1
fi

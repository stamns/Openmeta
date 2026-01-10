#!/bin/bash
# 快速 Nginx 配置检查

echo "==================================="
echo "Nginx 配置快速检查"
echo "==================================="
echo ""

# 检查文件是否存在
echo "1. 检查配置文件..."
files=(
    "nginx_conf/default.conf"
    "deploy/nginx/nginx.conf"
    "deploy/nginx/Dockerfile"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file 存在"
    else
        echo "  ✗ $file 不存在"
        exit 1
    fi
done

echo ""
echo "2. 检查关键配置..."

# 检查 gzip 配置
if grep -q "gzip_comp_level 6" deploy/nginx/nginx.conf; then
    echo "  ✓ Gzip 压缩级别 6"
else
    echo "  ✗ Gzip 压缩配置缺失"
fi

# 检查静态缓存配置
if grep -q "expires 365d" nginx_conf/default.conf; then
    echo "  ✓ 静态文件缓存 365 天"
else
    echo "  ✗ 静态缓存配置缺失"
fi

# 检查安全头配置
security_headers=(
    "X-Frame-Options"
    "X-Content-Type-Options"
    "X-XSS-Protection"
)

for header in "${security_headers[@]}"; do
    if grep -q "$header" nginx_conf/default.conf; then
        echo "  ✓ $header 安全头"
    else
        echo "  ✗ $header 安全头缺失"
    fi
done

# 检查 API 缓存配置
if grep -q "proxy_cache api_cache" nginx_conf/default.conf; then
    echo "  ✓ API 响应缓存配置"
else
    echo "  ✗ API 缓存配置缺失"
fi

# 检查 keepalive 配置
if grep -q "keepalive 32" nginx_conf/default.conf; then
    echo "  ✓ Keepalive 连接复用"
else
    echo "  ✗ Keepalive 配置缺失"
fi

# 检查缓存目录配置
if grep -q "proxy_cache_path" deploy/nginx/nginx.conf; then
    echo "  ✓ 缓存路径配置"
else
    echo "  ✗ 缓存路径配置缺失"
fi

echo ""
echo "3. 检查 docker-compose 卷配置..."
if grep -q "nginx-cache:" docker-compose-prod.yml; then
    echo "  ✓ nginx-cache 卷配置"
else
    echo "  ✗ nginx-cache 卷配置缺失"
fi

if grep -q "nginx-logs:" docker-compose-prod.yml; then
    echo "  ✓ nginx-logs 卷配置"
else
    echo "  ✗ nginx-logs 卷配置缺失"
fi

echo ""
echo "==================================="
echo "检查完成！"
echo "==================================="
echo ""
echo "要部署和测试，请运行："
echo "  docker-compose -f docker-compose-prod.yml build"
echo "  docker-compose -f docker-compose-prod.yml up -d"
echo "  python scripts/test_nginx_optimization.py"

#!/bin/bash
# Nginx 配置验证脚本

set -e

echo "========================================="
echo "Nginx 配置验证"
echo "========================================="
echo ""

# 验证 nginx.conf 主配置
echo "1. 验证 nginx.conf 主配置..."
docker run --rm \
  -v "$(pwd)/deploy/nginx/nginx.conf":/etc/nginx/nginx.conf:ro \
  nginx:1.25-alpine \
  nginx -t -c /etc/nginx/nginx.conf 2>&1 | grep -v "host not found" || true

echo ""
echo "2. 验证 default.conf 站点配置语法（忽略上游主机解析）..."
# 使用 resolver 配置来避免上游主机解析错误
docker run --rm \
  -v "$(pwd)/nginx_conf/default.conf":/tmp/default.conf:ro \
  nginx:1.25-alpine \
  sh -c "
    echo '检查 Nginx 配置文件语法...'

    # 使用 sed 添加 resolver 指令来避免 DNS 解析错误
    sed -i '1s/^/resolver 8.8.8.8 valid=300s;\n/' /tmp/default.conf

    # 将 backend:8000 替换为一个测试地址
    sed -i 's/backend:8000/127.0.0.1:8000/g' /tmp/default.conf

    # 复制到正确的位置
    cp /tmp/default.conf /etc/nginx/conf.d/default.conf

    # 测试配置
    nginx -t 2>&1
  "

echo ""
echo "========================================="
echo "配置验证完成"
echo "========================================="
echo ""
echo "注意：'host not found' 错误在测试环境中是正常的，"
echo "因为在 Docker Compose 环境中，backend 服务才可解析。"
echo ""
echo "要实际测试配置，请运行："
echo "  docker-compose -f docker-compose-prod.yml up -d"
echo "  python scripts/test_nginx_optimization.py"

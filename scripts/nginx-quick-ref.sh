#!/bin/bash
# Nginx 优化快速参考

cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║          Nginx 性能优化 - 快速参考                              ║
╚══════════════════════════════════════════════════════════════════╝

📋 配置文件位置
  - nginx_conf/default.conf        ← 站点配置（缓存、安全头）
  - deploy/nginx/nginx.conf        ← 全局配置（gzip、日志）
  - deploy/nginx/Dockerfile        ← 镜像构建
  - docker-compose-prod.yml        ← 生产部署

🚀 快速部署
  # 构建镜像
  docker-compose -f docker-compose-prod.yml build

  # 启动服务
  docker-compose -f docker-compose-prod.yml up -d

  # 查看日志
  docker-compose -f docker-compose-prod.yml logs -f nginx

✅ 验证和测试
  # 完整验证（47 项检查）
  bash scripts/verify-all-nginx.sh

  # 快速检查
  bash scripts/quick-nginx-check.sh

  # 运行自动化测试
  python scripts/test_nginx_optimization.py

🔍 手动验证命令
  # Gzip 压缩
  curl -i http://localhost/api/search?q=test -H "Accept-Encoding: gzip" | grep -i content-encoding

  # 静态缓存（JS/CSS）
  curl -i http://localhost/app.js | grep -i cache-control

  # HTML 缓存
  curl -i http://localhost/ | grep -i cache-control

  # 安全头
  curl -i http://localhost/ | grep -i "X-Frame-Options\|X-Content-Type-Options"

  # API 缓存
  curl -i http://localhost/api/search?q=test | grep -i X-Cache-Status

  # 版本号隐藏
  curl -i http://localhost/ | grep -i server:

📊 性能指标
  • 响应时间: < 100ms
  • CPU 使用: < 5%
  • 内存使用: < 256MB
  • Gzip 压缩率: 10-20% (JSON)
  • 缓存命中率: > 80%

🎯 核心功能
  ✅ Gzip 压缩（级别 6）
  ✅ 静态缓存（365 天）
  ✅ 安全头（5 个）
  ✅ API 缓存（10 分钟）
  ✅ 连接复用（32 连接）
  ✅ 日志优化（5 个字段）

🛠️ 故障排查
  # 检查配置
  docker exec openmeta-nginx-1 nginx -t

  # 重载配置
  docker exec openmeta-nginx-1 nginx -s reload

  # 查看错误日志
  docker exec openmeta-nginx-1 cat /var/log/nginx/error.log

  # 检查缓存目录
  docker exec openmeta-nginx-1 ls -la /var/cache/nginx

📚 文档
  • docs/nginx-optimization.md          ← 完整文档
  • NGINX-OPTIMIZATION-COMPLETE.md       ← 完成总结

💡 提示
  • 首次启动后，API 缓存需要时间生效
  • 缓存命中率会随着请求增加而提高
  • 使用 docker-compose 中的卷持久化缓存和日志
  • 调整 gzip_comp_level 可以平衡压缩率和 CPU 使用

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

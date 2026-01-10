# Nginx 性能优化文档

## 概述

本文档详细说明了 OpenMeta 项目中 Nginx 反向代理的性能优化配置，包括 Gzip 压缩、静态缓存、安全 HTTP 头和连接优化。

## 优化目标

- ✅ Gzip 压缩：JSON 响应压缩率 10-20%
- ✅ 静态文件缓存：JS/CSS/图片缓存 365 天
- ✅ HTML 缓存：禁用缓存，每次检查
- ✅ 安全 HTTP 头：防止 XSS、点击劫持等攻击
- ✅ API 响应缓存：10 分钟缓存，减少后端负载
- ✅ 响应时间：< 100ms，CPU < 5%

## 配置文件结构

```
nginx_conf/
└── default.conf          # 站点配置（缓存、压缩、安全头）

deploy/nginx/
├── Dockerfile            # Nginx 镜像构建
└── nginx.conf            # Nginx 主配置（全局优化）

docker-compose-prod.yml   # 生产环境部署配置
```

## 1. Gzip 压缩配置

### 配置说明

```nginx
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_min_length 500;
gzip_types
    text/plain
    text/css
    text/xml
    text/javascript
    application/json
    application/javascript
    application/xml+rss
    application/rss+xml
    application/atom+xml
    image/svg+xml
    text/x-component
    text/x-cross-domain-policy;
```

### 参数说明

- `gzip on`: 启用 gzip 压缩
- `gzip_comp_level 6`: 压缩级别 1-9，6 是平衡压缩率和 CPU 的最佳值
- `gzip_min_length 500`: 最小压缩文件大小（字节）
- `gzip_types`: 启用压缩的 MIME 类型
- `gzip_proxied any`: 对所有代理请求启用压缩
- `gzip_vary on`: 添加 Vary: Accept-Encoding 响应头

### 效果

- JSON 响应压缩率：10-20%
- JavaScript/CSS 压缩率：60-70%
- 减少 50-70% 的传输带宽

### 验证方法

```bash
# 检查响应是否压缩
curl -i http://localhost/api/search?q=test -H "Accept-Encoding: gzip"

# 应该看到：
# Content-Encoding: gzip
```

## 2. 静态文件缓存

### JS/CSS/图片缓存（365 天）

```nginx
location ~* \.(js|css|png|jpg|jpeg|gif|svg|ico|woff2?|webp|avif)$ {
    try_files $uri =404;
    expires 365d;
    add_header Cache-Control "public, immutable";
    access_log off;
}
```

**特点：**
- 长期缓存，减少重复请求
- `immutable` 标记表示文件不会改变
- 禁用访问日志，减少磁盘 I/O

### HTML 缓存（禁用）

```nginx
location ~* \.html$ {
    try_files $uri =404;
    expires -1;
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
}
```

**特点：**
- 每次检查新版本
- 适合频繁更新的页面

### 验证方法

```bash
# 检查 JS 缓存头
curl -i http://localhost/app.js

# 应该看到：
# Cache-Control: public, immutable
# Expires: Thu, 31 Dec 2037 23:55:55 GMT

# 检查 HTML 缓存头
curl -i http://localhost/

# 应该看到：
# Cache-Control: no-cache, no-store, must-revalidate
```

## 3. 安全 HTTP 响应头

### 配置说明

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Permissions-Policy "geolocation=(), camera=()" always;
```

### 安全头说明

| 头名称 | 值 | 作用 |
|--------|-----|------|
| `X-Frame-Options` | `SAMEORIGIN` | 防止点击劫持，只允许同源嵌入 |
| `X-Content-Type-Options` | `nosniff` | 防止 MIME 类型嗅探攻击 |
| `X-XSS-Protection` | `1; mode=block` | 启用浏览器 XSS 过滤器 |
| `Referrer-Policy` | `no-referrer-when-downgrade` | 控制 Referer 信息泄露 |
| `Permissions-Policy` | `geolocation=(), camera=()` | 限制浏览器功能访问 |

### 验证方法

```bash
curl -i http://localhost/ | grep -i "X-Frame-Options\|X-Content-Type-Options\|X-XSS-Protection"
```

## 4. 缓存和连接优化

### 代理缓冲配置

```nginx
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 8 4k;
proxy_busy_buffers_size 8k;
```

**作用：**
- 启用代理缓冲，提高响应速度
- 减少后端服务器的 I/O 操作

### 连接复用

```nginx
upstream backend {
    server backend:8000;
    keepalive 32;
}

proxy_http_version 1.1;
proxy_set_header Connection "";
```

**作用：**
- 保持 32 个到后端的持久连接
- 减少 TCP 连接建立开销

### 超时配置

```nginx
proxy_connect_timeout 5s;
proxy_send_timeout 10s;
proxy_read_timeout 10s;
```

**作用：**
- 连接超时：5 秒
- 发送/读取超时：10 秒
- 防止长时间挂起的连接

## 5. API 响应缓存

### 配置说明

```nginx
# 缓存路径配置
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=100m inactive=60m use_temp_path=off;

# API 端点
location /api/ {
    proxy_pass http://backend/api/;
    proxy_cache api_cache;
    proxy_cache_valid 200 301 302 10m;
    proxy_cache_valid 404 1m;
    proxy_cache_lock on;
    proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
    proxy_cache_background_update on;
    add_header X-Cache-Status $upstream_cache_status always;
}
```

### 参数说明

- `proxy_cache_path`: 缓存存储路径和配置
  - `levels=1:2`: 两级目录结构
  - `keys_zone=api_cache:10m`: 缓存键空间大小 10MB
  - `max_size=100m`: 最大缓存 100MB
  - `inactive=60m`: 60 分钟未访问则删除
- `proxy_cache_valid`: 不同状态码的缓存时间
- `proxy_cache_lock`: 防止缓存击穿
- `proxy_cache_use_stale`: 后端不可用时使用过期缓存
- `proxy_cache_background_update`: 后台更新缓存

### 缓存状态码

- `HIT`: 命中缓存
- `MISS`: 未命中
- `BYPASS`: 绕过缓存
- `EXPIRED`: 缓存过期
- `STALE`: 使用过期缓存
- `UPDATING`: 正在更新

### 验证方法

```bash
# 第一次请求（应该 MISS）
curl -i http://localhost/api/search?q=test

# 第二次请求（应该 HIT）
curl -i http://localhost/api/search?q=test

# 检查 X-Cache-Status 头
```

## 6. 日志优化

### 自定义日志格式

```nginx
log_format main '$remote_addr - $remote_user [$time_local] '
                '"$request" $status $body_bytes_sent '
                '"$http_referer" "$http_user_agent" '
                'rt=$request_time uct="$upstream_connect_time" '
                'uht="$upstream_header_time" urt="$upstream_response_time" '
                'cache="$upstream_cache_status"';
```

### 日志字段说明

- `rt`: 请求总时间
- `uct`: 上游连接时间
- `uht`: 上游响应头时间
- `urt`: 上游响应体时间
- `cache`: 缓存状态

### 日志示例

```
192.168.1.1 - - [10/Jan/2026:15:30:00 +0000] "GET /api/search?q=test HTTP/1.1" 200 1234 "http://localhost/" "Mozilla/5.0" rt=0.050 uct="0.001" uht="0.002" urt="0.047" cache="HIT"
```

## 7. 全局性能优化

### nginx.conf 优化

```nginx
events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    client_max_body_size 10M;

    # 隐藏版本号
    server_tokens off;
}
```

### 参数说明

- `worker_connections 2048`: 每个工作进程最大连接数
- `use epoll`: 使用高效的事件模型（Linux）
- `multi_accept on`: 尽可能多地接受连接
- `sendfile on`: 启用高效文件传输
- `tcp_nopush on`: 优化数据包发送
- `tcp_nodelay on`: 禁用 Nagle 算法
- `server_tokens off`: 隐藏 Nginx 版本号

## Docker 部署

### 构建和启动

```bash
# 构建镜像
docker-compose -f docker-compose-prod.yml build

# 启动服务
docker-compose -f docker-compose-prod.yml up -d

# 查看日志
docker-compose -f docker-compose-prod.yml logs -f nginx
```

### 持久化卷

```yaml
volumes:
  - nginx-cache:/var/cache/nginx    # 缓存持久化
  - nginx-logs:/var/log/nginx       # 日志持久化
```

### 健康检查

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1
```

## 测试验证

### 运行测试脚本

```bash
# 确保服务运行
docker-compose -f docker-compose-prod.yml up -d

# 运行测试脚本
python scripts/test_nginx_optimization.py
```

### 手动测试命令

```bash
# 1. Gzip 压缩测试
curl -i http://localhost/api/search?q=test -H "Accept-Encoding: gzip" | grep -i "content-encoding"

# 2. 静态缓存测试（JS/CSS）
curl -i http://localhost/app.js | grep -i "cache-control\|expires"

# 3. HTML 缓存测试
curl -i http://localhost/ | grep -i "cache-control\|pragma"

# 4. 安全头测试
curl -i http://localhost/ | grep -i "X-Frame-Options\|X-Content-Type-Options\|X-XSS-Protection"

# 5. API 缓存测试
curl -i http://localhost/api/search?q=test | grep -i "X-Cache-Status"

# 6. 响应时间测试
time curl -s http://localhost/api/search?q=test > /dev/null

# 7. 版本号隐藏测试
curl -i http://localhost/ | grep -i "server:"
```

## 性能指标

### 期望指标

- ✅ 响应时间：< 100ms（平均值）
- ✅ CPU 使用率：< 5%
- ✅ 内存使用：< 256MB
- ✅ Gzip 压缩率：10-20%（JSON）
- ✅ 缓存命中率：> 80%（API）

### 监控建议

1. 使用 Nginx 日志分析缓存命中率
2. 监控 CPU 和内存使用率
3. 跟踪响应时间分布
4. 监控缓存大小和命中率

## 故障排查

### 缓存不工作

```bash
# 检查缓存目录权限
docker exec openmeta-nginx-1 ls -la /var/cache/nginx

# 检查 Nginx 错误日志
docker exec openmeta-nginx-1 cat /var/log/nginx/error.log
```

### Gzip 不工作

```bash
# 检查 Nginx 配置
docker exec openmeta-nginx-1 nginx -t

# 重载配置
docker exec openmeta-nginx-1 nginx -s reload
```

### 安全头缺失

```bash
# 检查响应头
curl -i http://localhost/

# 检查配置文件
docker exec openmeta-nginx-1 cat /etc/nginx/conf.d/default.conf | grep -i "add_header"
```

## 最佳实践

1. **定期清理缓存**：使用 `proxy_cache_path` 的 `inactive` 参数
2. **监控缓存大小**：设置合理的 `max_size` 限制
3. **调整压缩级别**：根据 CPU 资源调整 `gzip_comp_level`
4. **使用 CDN**：对于静态资源，考虑使用 CDN
5. **定期更新 Nginx**：获取安全补丁和性能改进

## 参考资源

- [Nginx 官方文档](https://nginx.org/en/docs/)
- [Nginx 缓存指南](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache)
- [HTTP 安全头指南](https://owasp.org/www-project-secure-headers/)
- [Web 性能优化](https://web.dev/performance/)

## 更新日志

- 2026-01-10: 初始版本，实现所有核心优化功能
  - Gzip 压缩（级别 6）
  - 静态文件缓存（365 天）
  - 安全 HTTP 头
  - API 响应缓存（10 分钟）
  - 连接和缓冲优化
  - 日志格式优化

# Docker 容器安全性和可靠性改进

本文档说明了 OpenMeta 项目中实现的 Docker 容器安全性和可靠性改进。

## 改进概述

### 1. 非 root 用户运行

所有容器现在以非特权用户 `appuser` (UID 1000) 运行，而不是 root 用户。

#### 实现细节

**Backend (backend/Dockerfile)**
```dockerfile
# 创建非 root 用户
RUN groupadd -g 1000 appuser && \
    useradd -u 1000 -g appuser -s /bin/sh -m appuser

# 设置目录权限
RUN chown -R appuser:appuser /app

# 切换到非 root 用户
USER appuser
```

**Nginx (deploy/nginx/Dockerfile)**
```dockerfile
# 创建非 root 用户
RUN addgroup -g 1000 appuser && \
    adduser -u 1000 -G appuser -s /bin/sh -D appuser

# 设置权限
RUN chown -R appuser:appuser /var/cache/nginx /var/log/nginx

# 切换用户
USER appuser
```

#### 安全优势

- 限制容器内进程权限
- 防止特权提升攻击
- 减少容器逃逸风险
- 符合最小权限原则

### 2. 完整的健康检查

所有服务配置了健康检查机制，确保服务可用性监控。

#### 配置参数

- **interval**: 10s - 每 10 秒检查一次
- **timeout**: 3s - 检查超时时间
- **retries**: 3 - 失败重试次数
- **start_period**: 5-30s - 启动宽限期

#### 各服务健康检查

**Backend**
```yaml
healthcheck:
  test: ["CMD-SHELL", "python -c 'import urllib.request; urllib.request.urlopen(\"http://127.0.0.1:8000/health\")' || exit 1"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 30s
```

**Nginx**
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost/health || exit 1"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 5s
```

**Redis**
```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 5s
```

### 3. 资源限制

限制每个容器的资源使用，防止资源耗尽。

#### 资源配置

| 服务 | 内存限制 | 内存保留 | CPU 限制 | CPU 保留 |
|------|---------|---------|---------|---------|
| Backend | 512MB | 256MB | 0.50 | 0.25 |
| Nginx | 256MB | 128MB | 0.25 | 0.10 |
| Redis | 256MB | 128MB | 0.25 | 0.10 |

```yaml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: "0.50"
    reservations:
      memory: 256M
      cpus: "0.25"
```

#### 日志限制

防止日志文件无限增长：

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"  # 单个日志文件最大 10MB
    max-file: "5"    # 最多保留 5 个日志文件
```

### 4. 安全配置

#### Linux Capabilities 管理

使用 capability 限制容器权限：

```yaml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE  # 允许绑定特权端口（80, 443）
```

#### 环境变量安全

```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1  # 不生成 .pyc 文件
ENV PYTHONUNBUFFERED=1         # 实时输出日志
ENV PIP_NO_CACHE_DIR=1         # 不缓存下载的包
ENV PIP_DISABLE_PIP_VERSION_CHECK=1  # 禁用版本检查
```

### 5. 自动故障转移

#### 重启策略

所有服务配置了 `unless-stopped` 重启策略：

```yaml
restart: unless-stopped
```

这意味着：
- 容器异常退出时自动重启
- 手动停止的容器不会自动重启
- Docker daemon 重启后容器会自动启动

#### 服务依赖

Nginx 依赖 Backend 的健康状态：

```yaml
nginx:
  depends_on:
    backend:
      condition: service_healthy
```

这确保：
- Nginx 在 Backend 健康后才启动
- Backend 不健康时，Nginx 返回 502 错误
- Backend 恢复后，Nginx 自动恢复服务

## 验证测试

### 1. 安全性测试

运行安全性测试脚本：

```bash
chmod +x scripts/test-docker-security.sh
./scripts/test-docker-security.sh
```

测试项目：
- ✅ 容器以 appuser (UID 1000) 运行
- ✅ 健康检查状态为 healthy
- ✅ 资源限制生效
- ✅ 日志限制配置正确
- ✅ 重启策略正确
- ✅ 安全选项启用
- ✅ 无法写入根目录

### 2. 故障转移测试

运行故障转移测试脚本：

```bash
chmod +x scripts/test-failover.sh
./scripts/test-failover.sh
```

测试项目：
- ✅ Backend 崩溃时自动重启
- ✅ Nginx 在 Backend 不可用时返回 502
- ✅ 服务恢复后正常响应
- ✅ 容器依赖关系正确

### 3. 手动验证

#### 检查容器用户

```bash
# Backend
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) whoami
# 应该输出: appuser

# Nginx
docker exec $(docker compose -f docker-compose-prod.yml ps -q nginx) whoami
# 应该输出: appuser
```

#### 检查健康状态

```bash
docker compose -f docker-compose-prod.yml ps
# 应该显示: (healthy)
```

#### 检查资源使用

```bash
docker stats --no-stream
```

#### 查看容器详细信息

```bash
docker inspect $(docker compose -f docker-compose-prod.yml ps -q backend) | jq '.[0].Config.User'
docker inspect $(docker compose -f docker-compose-prod.yml ps -q backend) | jq '.[0].State.Health'
```

## 性能影响

### 启动时间

- Backend: +5-10 秒（健康检查宽限期）
- Nginx: +5 秒（等待 Backend 健康）
- 总体: 约 30-40 秒完全启动

### 运行时开销

- 健康检查: 每 10 秒一次，几乎无开销
- 非 root 用户: 无性能影响
- 资源限制: 防止资源耗尽，提高稳定性

## 故障排查

### 容器无法启动

1. 检查权限问题：
```bash
docker logs $(docker compose -f docker-compose-prod.yml ps -q backend)
```

2. 检查健康检查失败：
```bash
docker inspect $(docker compose -f docker-compose-prod.yml ps -q backend) | jq '.[0].State.Health'
```

### 健康检查失败

1. 手动测试健康端点：
```bash
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) \
  python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
```

2. 检查端口监听：
```bash
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) netstat -tlnp
```

### 权限问题

1. 检查文件所有者：
```bash
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) ls -la /app
```

2. 检查进程用户：
```bash
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) ps aux
```

## 最佳实践

### 1. 开发环境

开发时可以使用简化配置：

```bash
docker compose up
```

这会使用 `docker-compose.yml`，包含所有安全特性但重启策略较宽松。

### 2. 生产环境

生产环境使用完整配置：

```bash
docker compose -f docker-compose-prod.yml up -d
```

### 3. 监控

定期检查容器状态：

```bash
# 查看健康状态
docker compose -f docker-compose-prod.yml ps

# 查看资源使用
docker stats

# 查看日志
docker compose -f docker-compose-prod.yml logs -f --tail=100
```

### 4. 更新和维护

更新容器时确保健康检查通过：

```bash
# 重新构建
docker compose -f docker-compose-prod.yml build

# 滚动更新
docker compose -f docker-compose-prod.yml up -d --no-deps backend

# 等待健康检查
watch docker compose -f docker-compose-prod.yml ps
```

## 安全检查清单

- [x] 所有容器以非 root 用户运行
- [x] 健康检查配置并正常工作
- [x] 资源限制设置合理
- [x] 日志轮转配置正确
- [x] 自动重启策略配置
- [x] Linux capabilities 最小化
- [x] no-new-privileges 启用
- [x] 敏感信息使用环境变量
- [x] 容器依赖关系正确
- [x] 故障转移机制工作

## 参考资料

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Container Security Guide](https://www.nccgroup.com/us/research-blog/understanding-and-hardening-linux-containers/)
- [Docker Compose Healthcheck](https://docs.docker.com/compose/compose-file/compose-file-v3/#healthcheck)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)

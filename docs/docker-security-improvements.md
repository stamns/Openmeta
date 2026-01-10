# Docker 容器安全性和可靠性改进文档

## 概述

本文档记录了为 OpenMeta 项目实施的 Docker 容器安全性和可靠性改进，包括非 root 用户运行、完整的健康检查机制、资源限制和自动故障转移。

## 改进内容

### 1. 非 root 用户运行

#### Backend 容器
- 创建专用用户 `appuser`（UID 1000）
- 在 `backend/Dockerfile` 中添加用户创建和权限设置
- 使用 `USER appuser` 切换到非 root 用户运行应用

**配置文件**: `backend/Dockerfile`

```dockerfile
# 创建非 root 用户
RUN groupadd -r appuser && useradd -r -g appuser -u 1000 appuser

# 设置目录权限
RUN chown -R appuser:appuser /app

# 切换到非 root 用户
USER appuser
```

#### Nginx 容器
- 使用官方 nginx 镜像内置的 `nginx` 用户
- 在 `deploy/nginx/Dockerfile` 中设置必要的目录权限

**配置文件**: `deploy/nginx/Dockerfile`

```dockerfile
# 创建必要的目录并设置权限
RUN mkdir -p /var/cache/nginx/api_cache \
             /var/run/nginx \
             /var/log/nginx \
             /tmp/nginx && \
    chown -R nginx:nginx /var/cache/nginx \
                         /var/log/nginx \
                         /var/run/nginx \
                         /tmp/nginx \
                         /usr/share/nginx/html

# 切换到非 root 用户
USER nginx
```

### 2. 完整的健康检查机制

#### 开发环境 (docker-compose.yml)

```yaml
healthcheck:
  test: ["CMD-SHELL", "python -c 'import urllib.request; urllib.request.urlopen(\"http://127.0.0.1:8000/health\")' || exit 1"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 10s
```

#### 生产环境 (docker-compose-prod.yml)

**Backend 健康检查**:
```yaml
healthcheck:
  test: ["CMD-SHELL", "python -c 'import urllib.request; urllib.request.urlopen(\"http://127.0.0.1:8000/health\")' || exit 1"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 30s
```

**Nginx 健康检查**:
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost/health || exit 1"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 5s
```

**Redis 健康检查**:
```yaml
healthcheck:
  test: ["CMD-SHELL", "redis-cli ping || exit 1"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 5s
```

### 3. 资源限制

#### 开发环境
```yaml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: "0.50"
```

#### 生产环境
```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "0.50"

  nginx:
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: "0.25"

  redis:
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: "0.25"
```

### 4. 日志限制

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "5"
```

应用日志限制到每个容器最多 10MB，保留最多 5 个文件（共 50MB）。

### 5. 安全配置

#### Linux Capabilities 管理
```yaml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE  # 允许绑定端口
```

对于 Nginx 容器，还需要额外的 capabilities:
```yaml
cap_add:
  - NET_BIND_SERVICE
  - CHOWN
  - SETGID
  - SETUID
```

#### 临时文件系统 (tmpfs)
```yaml
tmpfs:
  - /tmp
  - /var/run  # Nginx 需要此目录
```

### 6. 自动故障转移

#### 重启策略
```yaml
restart: unless-stopped
```

容器会自动重启，除非手动停止。

#### 服务依赖
```yaml
depends_on:
  backend:
    condition: service_healthy
```

Nginx 会等待 backend 健康后才启动。

## 验收标准

### ✅ 标准 1: 容器以非 root 用户运行
```bash
# 检查 backend 容器用户
docker compose -f docker-compose-prod.yml ps -q backend | xargs docker exec whoami
# 期望输出: appuser

# 检查 nginx 容器用户
docker compose -f docker-compose-prod.yml ps -q nginx | xargs docker exec whoami
# 期望输出: nginx
```

### ✅ 标准 2: 健康检查状态显示 healthy
```bash
docker compose -f docker-compose-prod.yml ps
# 期望输出中包含 (healthy) 状态
```

### ✅ 标准 3: 后端崩溃时 Nginx 返回 502
```bash
# 停止 backend
docker compose -f docker-compose-prod.yml stop backend

# 访问网站应该返回 502
curl -i http://localhost

# 启动 backend
docker compose -f docker-compose-prod.yml up -d backend

# 等待健康检查通过后恢复正常
```

### ✅ 标准 4: 资源限制生效
```bash
# 检查内存限制
docker compose -f docker-compose-prod.yml ps -q backend | xargs docker inspect | jq '.[0].HostConfig.Memory'
# 期望输出: 536870912 (512MB)

docker compose -f docker-compose-prod.yml ps -q nginx | xargs docker inspect | jq '.[0].HostConfig.Memory'
# 期望输出: 268435456 (256MB)
```

### ✅ 标准 5: 日志不无限增长
```bash
# 检查日志配置
docker compose -f docker-compose-prod.yml ps -q backend | xargs docker inspect | jq '.[0].HostConfig.LogConfig'
# 期望输出包含: {"max-size": "10m", "max-file": "5"}
```

## 部署和使用

### 开发环境

```bash
# 启动开发环境
docker compose up --build

# 查看健康状态
docker compose ps

# 查看日志
docker compose logs -f
```

### 生产环境

```bash
# 启动生产环境
docker compose -f docker-compose-prod.yml up -d --build

# 查看健康状态
docker compose -f docker-compose-prod.yml ps

# 查看日志
docker compose -f docker-compose-prod.yml logs -f
```

## 验证测试

运行自动化测试脚本验证所有改进：

```bash
# 确保生产环境正在运行
docker compose -f docker-compose-prod.yml up -d --build

# 等待容器启动和健康检查通过（约 30-60 秒）
sleep 60

# 运行验证测试
python scripts/test_docker_security.py
```

测试脚本会验证：
1. 非 root 用户运行
2. 健康检查状态
3. 健康检查端点可访问
4. 资源限制配置
5. 日志配置
6. 安全选项
7. 故障转移机制（需要手动验证）

## 故障排查

### 容器无法以非 root 用户启动

**问题**: 权限错误或无法写入文件

**解决方案**:
- 检查目录权限是否正确设置
- 确保应用不需要写入系统目录
- 使用 tmpfs 挂载临时目录

### 健康检查一直失败

**问题**: 容器状态显示 unhealthy

**解决方案**:
```bash
# 查看容器日志
docker compose -f docker-compose-prod.yml logs backend

# 手动测试健康检查端点
curl http://localhost:8000/health

# 检查健康检查配置
docker compose -f docker-compose-prod.yml config | grep -A 10 healthcheck
```

### 资源限制导致性能问题

**问题**: 容器运行缓慢或被杀死

**解决方案**:
- 增加内存限制
- 检查内存使用情况: `docker stats`
- 优化应用内存使用

## 安全最佳实践

1. **永远不要以 root 用户运行容器**
   - 创建专用用户并限制权限
   - 只授予必要的 capabilities

2. **实施完整的健康检查**
   - 确保所有关键服务都有健康检查
   - 设置合理的超时和重试次数

3. **限制资源使用**
   - 防止单个容器耗尽主机资源
   - 设置内存和 CPU 限制

4. **使用安全选项**
   - `no-new-privileges:true` 防止提权
   - 移除不必要的 capabilities
   - 使用 tmpfs 保护临时文件

5. **监控和日志**
   - 限制日志大小防止磁盘耗尽
   - 使用集中式日志收集

## 参考资源

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Docker Compose Healthcheck](https://docs.docker.com/compose/compose-file/compose-file-v3/#healthcheck)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Docker Resource Constraints](https://docs.docker.com/config/containers/resource_constraints/)

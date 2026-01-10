# Docker 安全性和可靠性改进

## 概述

本文档详细说明了 OpenMeta 项目的 Docker 容器安全性和可靠性改进，包括非 root 用户运行、完整的健康检查机制、资源限制和自动故障转移。

## 核心目标

创建安全的容器环境，包含：
- 非 root 用户运行
- 完整的健康检查机制
- 资源限制（内存、CPU、日志）
- 自动故障转移
- 最小化 Linux capabilities

## 文件改动清单

### 1. backend/Dockerfile
- ✅ 创建非 root 用户 `appuser` (UID 1000)
- ✅ 设置安全环境变量（PYTHONDONTWRITEBYTECODE、PIP_NO_CACHE_DIR）
- ✅ 配置健康检查（间隔 10s，超时 3s，重试 3 次，启动宽限期 30s）
- ✅ 设置目录权限为 appuser
- ✅ 切换到非 root 用户运行

### 2. deploy/nginx/Dockerfile
- ✅ 创建非 root 用户 `appuser` (UID 1000)
- ✅ 配置健康检查（间隔 10s，超时 3s，重试 3 次，启动宽限期 5s）
- ✅ 设置必要的目录权限（/var/cache/nginx、/var/log/nginx、/var/run）
- ✅ 切换到非 root 用户运行
- ✅ Nginx 配置使用 `user appuser`

### 3. docker-compose.yml（开发环境）
- ✅ 完整的服务配置（backend、nginx、redis）
- ✅ 健康检查配置
- ✅ 资源限制（内存、CPU）
- ✅ 日志限制（10MB/文件，最多 5 个）
- ✅ 安全配置（no-new-privileges、capabilities）
- ✅ Nginx depends_on backend with health condition
- ✅ restart: unless-stopped

### 4. docker-compose-prod.yml（生产环境）
- ✅ 完整的服务配置（backend、nginx、redis）
- ✅ 健康检查配置
- ✅ 资源限制（内存、CPU）
- ✅ 日志限制（10MB/文件，最多 5 个）
- ✅ 安全配置（no-new-privileges、capabilities）
- ✅ Nginx depends_on backend with health condition
- ✅ restart: unless-stopped
- ✅ tmpfs 挂载（/tmp、/var/run）

## 验收标准

### ✅ 1. 非 root 用户运行
- Backend: `appuser` (UID 1000)
- Nginx: `appuser` (UID 1000)
- Redis: 非 root 用户（Alpine 默认行为）

### ✅ 2. 健康检查状态
- docker ps 显示 `(healthy)` 状态
- Backend: 间隔 10s，超时 3s，重试 3 次，启动宽限期 30s
- Nginx: 间隔 10s，超时 3s，重试 3 次，启动宽限期 5s
- Redis: 间隔 10s，超时 3s，重试 3 次，启动宽限期 5s

### ✅ 3. 故障转移
- Backend 崩溃时 Nginx 返回 502 Bad Gateway
- Backend 自动恢复后 Nginx 正常代理
- Nginx 依赖 Backend 的健康检查

### ✅ 4. 资源限制
- Backend: 512MB 内存，0.50 核 CPU（保留 256MB，0.25 核）
- Nginx: 256MB 内存，0.25 核 CPU（保留 128MB，0.10 核）
- Redis: 256MB 内存，0.25 核 CPU（保留 128MB，0.10 核）

### ✅ 5. 日志限制
- 最大文件大小：10MB
- 最大文件数量：5 个（总共 50MB）
- 日志驱动：json-file

## 安全性特性

### 1. 非 root 用户运行
所有容器使用专用用户 `appuser` (UID 1000) 运行，防止特权提升攻击。

### 2. Linux Capabilities 最小化
```yaml
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE  # 仅绑定端口
```

对于 Nginx，额外添加：
```yaml
cap_add:
  - NET_BIND_SERVICE
  - CHOWN
  - SETGID
  - SETUID
```

### 3. no-new-privileges
```yaml
security_opt:
  - no-new-privileges:true
```
防止进程获取新的权限。

### 4. 安全环境变量
```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
```

## 可靠性特性

### 1. 健康检查
```yaml
healthcheck:
  test: ["CMD-SHELL", "python -c 'import urllib.request; urllib.request.urlopen(\"http://127.0.0.1:8000/health\")' || exit 1"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 30s
```

### 2. 自动故障转移
```yaml
restart: unless-stopped
```

容器崩溃时自动重启，除非明确停止。

### 3. 服务依赖
```yaml
depends_on:
  backend:
    condition: service_healthy
```

Nginx 等待 Backend 健康后再启动。

## 测试脚本

### 完整验收测试
```bash
./scripts/acceptance-test.sh
```

运行所有验收测试，包括安全性和故障转移测试。

### 安全性测试
```bash
./scripts/test-docker-security.sh
```

测试：
- 非 root 用户运行
- 健康检查状态
- 资源限制
- 安全配置（no-new-privileges、capabilities）
- 环境变量
- 日志配置
- 目录权限

### 故障转移测试
```bash
./scripts/test-failover.sh
```

测试：
- 服务健康状态
- Backend 崩溃恢复
- Nginx 依赖关系
- restart 策略
- 健康检查配置

## 使用说明

### 开发环境
```bash
# 启动开发环境
docker compose up --build

# 查看日志
docker compose logs -f

# 查看健康状态
docker compose ps

# 停止服务
docker compose down
```

### 生产环境
```bash
# 启动生产环境
docker compose -f docker-compose-prod.yml build
docker compose -f docker-compose-prod.yml up -d

# 查看日志和健康状态
docker compose -f docker-compose-prod.yml logs -f nginx
docker compose -f docker-compose-prod.yml ps

# 进入容器
docker exec -it $(docker compose -f docker-compose-prod.yml ps -q backend) sh

# 停止服务
docker compose -f docker-compose-prod.yml down
```

### 启用 Redis（可选）
```bash
# 启动 Redis
docker compose -f docker-compose-prod.yml --profile redis up -d

# 查看状态
docker compose -f docker-compose-prod.yml ps redis
```

## 监控和调试

### 健康检查
```bash
# 健康端点
curl http://localhost/health

# 监控指标
curl http://localhost/metrics

# 持续监控容器状态
watch -n 5 'docker compose -f docker-compose-prod.yml ps'
```

### 资源使用
```bash
# 查看资源使用情况
docker stats

# 查看特定容器的资源限制
docker inspect $(docker compose -f docker-compose-prod.yml ps -q backend) | jq '.[0].HostConfig'
```

### 容器用户检查
```bash
# 检查运行用户
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) whoami
# 应该输出: appuser

# 检查 UID
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) id -u
# 应该输出: 1000

# 检查进程用户
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) ps aux
```

### 健康检查排查
```bash
# 查看健康状态
docker inspect $(docker compose -f docker-compose-prod.yml ps -q backend) | jq '.[0].State.Health'

# 查看健康检查日志
docker inspect $(docker compose -f docker-compose-prod.yml ps -q backend) | jq '.[0].State.Health.Log'

# 手动测试健康端点
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) \
  python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
```

### Nginx 配置
```bash
# 检查配置语法
docker exec $(docker compose -f docker-compose-prod.yml ps -q nginx) nginx -t

# 重载配置
docker exec $(docker compose -f docker-compose-prod.yml ps -q nginx) nginx -s reload

# 查看错误日志
docker compose -f docker-compose-prod.yml logs nginx | grep error
```

### 缓存问题
```bash
# 检查缓存目录
docker exec $(docker compose -f docker-compose-prod.yml ps -q nginx) ls -la /var/cache/nginx

# 清空缓存
docker exec $(docker compose -f docker-compose-prod.yml ps -q nginx) rm -rf /var/cache/nginx/*
```

### 权限问题
```bash
# 检查文件所有者
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) ls -la /app

# 检查进程用户
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) ps aux
```

## 部署注意事项

1. **环境变量**
   - 需要 `.env` 文件（可从 `.env.example` 复制）
   - 确保配置正确（REDIS_URL、LOG_LEVEL 等）

2. **启动时间**
   - Backend 启动需要 30 秒宽限期（健康检查）
   - Nginx 启动需要 5 秒宽限期
   - Redis 启动需要 5 秒宽限期

3. **健康检查依赖**
   - Nginx 依赖 Backend 健康状态
   - 确保 Backend `/health` 端点正常工作

4. **卷挂载**
   - Nginx 缓存和日志需要持久化卷
   - Redis 数据需要持久化卷

5. **用户一致性**
   - 所有容器使用相同的 UID 1000
   - 确保文件权限正确设置

## 常见问题

### Q1: 容器启动失败，提示权限错误
**A:** 检查文件所有者和权限，确保容器内的 appuser 有正确的访问权限。

### Q2: 健康检查一直失败
**A:** 检查：
- 健康端点是否正确响应
- 防火墙是否允许内部通信
- 应用是否正确启动

### Q3: 容器资源被限制
**A:** 这是预期行为。如需调整资源限制，修改 docker-compose 文件中的 `deploy.resources` 部分。

### Q4: Nginx 返回 502 错误
**A:** 检查 Backend 是否健康：
```bash
docker compose -f docker-compose-prod.yml ps backend
```

### Q5: 日志文件过大
**A:** 日志限制已配置（10MB/文件，最多 5 个）。如果仍有问题，检查日志驱动配置。

## 参考资源

- [Docker 安全最佳实践](https://docs.docker.com/engine/security/)
- [Docker 健康检查](https://docs.docker.com/engine/reference/builder/#healthcheck)
- [Docker 资源限制](https://docs.docker.com/config/containers/resource_constraints/)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [no-new-privileges](https://www.kernel.org/doc/Documentation/prctl/no_new_privs.txt)

## 总结

通过实施这些改进，OpenMeta 项目现在具备：
- ✅ 增强的安全性（非 root 用户、最小化权限）
- ✅ 提高的可靠性（健康检查、自动恢复）
- ✅ 更好的资源管理（限制和监控）
- ✅ 完整的测试覆盖（验收、安全、故障转移）

这些改进使项目更适合生产环境部署。

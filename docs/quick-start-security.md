# 快速开始 - Docker 安全性和可靠性

本指南帮助你快速了解和使用 OpenMeta 的 Docker 安全性和可靠性特性。

## 🎯 核心特性

✅ **非 root 用户运行** - 所有容器以 appuser (UID 1000) 运行  
✅ **完整健康检查** - 每 10 秒自动检查服务状态  
✅ **资源限制** - 防止内存和 CPU 耗尽  
✅ **自动故障转移** - 服务崩溃自动重启  
✅ **安全加固** - 最小化权限和能力  

## 🚀 快速开始

### 1. 开发环境（推荐）

适用于本地开发和测试：

```bash
# 启动服务
docker compose up -d

# 查看状态（应该显示 healthy）
docker compose ps

# 查看日志
docker compose logs -f
```

### 2. 生产环境

适用于生产部署：

```bash
# 构建镜像
docker compose -f docker-compose-prod.yml build

# 启动服务
docker compose -f docker-compose-prod.yml up -d

# 查看状态
docker compose -f docker-compose-prod.yml ps

# 等待服务健康（约 30-40 秒）
watch -n 2 'docker compose -f docker-compose-prod.yml ps'
```

## ✅ 验证安全配置

### 方法 1: 快速验证（推荐）

一键验证所有配置：

```bash
./scripts/quick-verify.sh
```

预期输出：全部 ✓

### 方法 2: 完整验收测试

运行完整的验收测试（需要先启动服务）：

```bash
# 启动服务
docker compose -f docker-compose-prod.yml up -d

# 等待 40 秒让服务完全启动
sleep 40

# 运行验收测试
./scripts/acceptance-test.sh
```

这将测试：
- ✅ 容器以 appuser (UID 1000) 运行
- ✅ docker ps 显示 (healthy)
- ✅ 后端崩溃时 Nginx 返回 502
- ✅ 内存限制生效
- ✅ 日志不无限增长

### 方法 3: 手动验证

#### 检查运行用户

```bash
# Backend
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) whoami
# 预期输出: appuser

# Nginx
docker exec $(docker compose -f docker-compose-prod.yml ps -q nginx) whoami
# 预期输出: appuser
```

#### 检查健康状态

```bash
docker compose -f docker-compose-prod.yml ps
# 预期输出: backend ... (healthy)
#          nginx ... (healthy)
```

#### 测试故障转移

```bash
# 1. 停止 Backend
docker stop $(docker compose -f docker-compose-prod.yml ps -q backend)

# 2. 测试 Nginx 响应
curl -i http://localhost/api/search?q=test
# 预期输出: HTTP/1.1 502 Bad Gateway

# 3. 等待自动重启（10-30 秒）
watch -n 2 'docker compose -f docker-compose-prod.yml ps'

# 4. 确认服务恢复
curl http://localhost/health
```

## 📊 监控和维护

### 实时监控

```bash
# 查看健康状态
watch -n 5 'docker compose -f docker-compose-prod.yml ps'

# 查看资源使用
docker stats

# 查看日志
docker compose -f docker-compose-prod.yml logs -f --tail=100
```

### 查看详细信息

```bash
# Backend 健康状态
docker inspect $(docker compose -f docker-compose-prod.yml ps -q backend) | jq '.[0].State.Health'

# Nginx 健康状态
docker inspect $(docker compose -f docker-compose-prod.yml ps -q nginx) | jq '.[0].State.Health'

# 资源限制
docker inspect $(docker compose -f docker-compose-prod.yml ps -q backend) | jq '.[0].HostConfig.Memory'
```

## 🔧 常见任务

### 重启服务

```bash
# 重启单个服务
docker compose -f docker-compose-prod.yml restart backend

# 重启所有服务
docker compose -f docker-compose-prod.yml restart
```

### 查看日志

```bash
# 查看所有日志
docker compose -f docker-compose-prod.yml logs

# 查看特定服务日志
docker compose -f docker-compose-prod.yml logs backend

# 实时跟踪日志
docker compose -f docker-compose-prod.yml logs -f --tail=100
```

### 更新服务

```bash
# 1. 拉取最新代码
git pull

# 2. 重新构建
docker compose -f docker-compose-prod.yml build

# 3. 滚动更新（零停机）
docker compose -f docker-compose-prod.yml up -d --no-deps backend
docker compose -f docker-compose-prod.yml up -d --no-deps nginx

# 4. 等待健康检查
watch -n 2 'docker compose -f docker-compose-prod.yml ps'
```

## 🐛 故障排查

### 容器无法启动

```bash
# 查看日志
docker compose -f docker-compose-prod.yml logs backend

# 检查配置
docker compose -f docker-compose-prod.yml config

# 进入容器调试
docker compose -f docker-compose-prod.yml run backend sh
```

### 健康检查失败

```bash
# 查看健康检查日志
docker inspect $(docker compose -f docker-compose-prod.yml ps -q backend) | jq '.[0].State.Health.Log'

# 手动测试健康端点
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) \
  python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
```

### 权限问题

```bash
# 检查文件所有者
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) ls -la /app

# 检查进程用户
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) ps aux
```

### Nginx 502 错误

```bash
# 检查 Backend 状态
docker compose -f docker-compose-prod.yml ps backend

# 检查网络连接
docker exec $(docker compose -f docker-compose-prod.yml ps -q nginx) \
  wget -O- http://backend:8000/health

# 查看 Nginx 错误日志
docker compose -f docker-compose-prod.yml logs nginx | grep error
```

## 🧪 测试脚本

项目提供了 3 个测试脚本：

### 1. 快速验证

验证配置文件是否正确：

```bash
./scripts/quick-verify.sh
```

### 2. 安全性测试

详细的安全配置检查：

```bash
./scripts/test-docker-security.sh
```

测试内容：
- 非 root 用户
- 健康检查状态
- 资源限制
- 日志限制
- 重启策略
- 安全选项

### 3. 故障转移测试

测试自动故障转移：

```bash
./scripts/test-failover.sh
```

测试内容：
- Backend 自动重启
- Nginx 错误响应
- 服务自动恢复
- 容器依赖关系

### 4. 完整验收测试

验证所有验收标准：

```bash
./scripts/acceptance-test.sh
```

## 📚 更多文档

- [详细文档](docker-security-reliability.md) - 完整的安全性和可靠性说明
- [前后对比](before-after-comparison.md) - 改进前后的详细对比
- [改进总结](../DOCKER-SECURITY-COMPLETE.md) - 改进概览和验收标准

## 💡 最佳实践

### 开发环境

1. 使用 `docker-compose.yml`
2. 定期运行 `./scripts/quick-verify.sh`
3. 关注日志输出

### 生产环境

1. 使用 `docker-compose-prod.yml`
2. 启动后等待 40 秒确保健康检查通过
3. 定期运行 `./scripts/test-docker-security.sh`
4. 使用 `docker stats` 监控资源使用
5. 定期查看日志

### 安全建议

1. ✅ 定期更新基础镜像
2. ✅ 定期运行安全测试
3. ✅ 监控资源使用
4. ✅ 检查日志异常
5. ✅ 备份重要数据

## 🎓 学习资源

- [Docker 安全最佳实践](https://docs.docker.com/engine/security/)
- [容器安全指南](https://www.nccgroup.com/us/research-blog/understanding-and-hardening-linux-containers/)
- [Docker Compose 健康检查](https://docs.docker.com/compose/compose-file/compose-file-v3/#healthcheck)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)

## ❓ 常见问题

### Q: 为什么启动时间变长了？

A: 改进后启动时间约 30-40 秒，主要原因：
- Backend 健康检查宽限期（30 秒）
- Nginx 等待 Backend 健康
- 这是为了确保服务完全启动和健康

### Q: 资源限制会影响性能吗？

A: 不会。资源限制只是设置上限，防止资源耗尽：
- Backend: 512MB 内存，0.5 核 CPU（通常使用 < 100MB）
- Nginx: 256MB 内存，0.25 核 CPU（通常使用 < 50MB）

### Q: 如何调整资源限制？

A: 编辑 `docker-compose-prod.yml`，修改 `deploy.resources` 部分：

```yaml
deploy:
  resources:
    limits:
      memory: 1024M  # 改为 1GB
      cpus: "1.00"   # 改为 1 核
```

### Q: 可以禁用健康检查吗？

A: 不推荐。健康检查是可靠性的核心。如果必须禁用：

```yaml
# 在服务配置中添加
healthcheck:
  disable: true
```

### Q: 如何回滚到改进前的配置？

A: 使用 git 回滚：

```bash
git checkout HEAD~1 backend/Dockerfile
git checkout HEAD~1 deploy/nginx/Dockerfile
git checkout HEAD~1 docker-compose.yml
git checkout HEAD~1 docker-compose-prod.yml
```

但强烈不推荐，因为会失去所有安全改进。

## 🆘 需要帮助？

1. 查看 [详细文档](docker-security-reliability.md)
2. 运行测试脚本诊断问题
3. 查看日志: `docker compose logs -f`
4. 检查 GitHub Issues

---

**提示**: 首次使用请先运行 `./scripts/quick-verify.sh` 确保配置正确！

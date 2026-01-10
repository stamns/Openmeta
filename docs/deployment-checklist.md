# Docker 安全性和可靠性 - 部署检查清单

使用本检查清单确保 Docker 安全性和可靠性配置正确部署。

## 📋 部署前检查清单

### 1. 配置文件验证

- [ ] 运行配置验证: `./scripts/quick-verify.sh`
- [ ] 检查 Docker Compose 语法: `docker compose -f docker-compose-prod.yml config`
- [ ] 确认 .env 文件存在并正确配置
- [ ] 检查所有必需的环境变量

### 2. 构建测试

- [ ] 清理旧镜像: `docker compose -f docker-compose-prod.yml down --rmi all`
- [ ] 构建所有服务: `docker compose -f docker-compose-prod.yml build`
- [ ] 检查构建日志无错误
- [ ] 验证镜像大小合理

### 3. 本地测试

- [ ] 启动服务: `docker compose -f docker-compose-prod.yml up -d`
- [ ] 等待健康检查通过（40 秒）
- [ ] 运行验收测试: `./scripts/acceptance-test.sh`
- [ ] 运行安全性测试: `./scripts/test-docker-security.sh`
- [ ] 运行故障转移测试: `./scripts/test-failover.sh`

### 4. 安全验证

- [ ] 验证所有容器以非 root 用户运行
- [ ] 确认 no-new-privileges 启用
- [ ] 检查 Linux capabilities 最小化
- [ ] 验证资源限制生效
- [ ] 确认日志轮转配置正确

### 5. 功能测试

- [ ] 健康检查端点响应: `curl http://localhost/health`
- [ ] API 搜索功能正常: `curl http://localhost/api/search?q=test`
- [ ] 前端页面加载正常: `curl http://localhost/`
- [ ] Nginx 压缩生效: `curl -H "Accept-Encoding: gzip" http://localhost/ -I`
- [ ] 缓存头正确: `curl -I http://localhost/`

## 📊 部署后监控

### 1. 立即检查（部署后 5 分钟内）

- [ ] 所有容器状态为 healthy: `docker compose -f docker-compose-prod.yml ps`
- [ ] 无错误日志: `docker compose -f docker-compose-prod.yml logs --tail=100`
- [ ] CPU 使用率正常: `docker stats --no-stream`
- [ ] 内存使用率正常: `docker stats --no-stream`

### 2. 短期监控（部署后 1 小时内）

- [ ] 服务稳定运行，无重启
- [ ] 响应时间正常（< 100ms）
- [ ] 无 5xx 错误
- [ ] 资源使用稳定

### 3. 长期监控（每天）

- [ ] 检查日志大小: `docker system df`
- [ ] 检查磁盘使用: `df -h`
- [ ] 查看容器重启次数: `docker compose -f docker-compose-prod.yml ps`
- [ ] 监控资源趋势

## 🔧 部署步骤

### 开发环境部署

```bash
# 1. 克隆代码
git clone <repository-url>
cd openmeta

# 2. 复制环境变量
cp .env.example .env

# 3. 验证配置
./scripts/quick-verify.sh

# 4. 启动服务
docker compose up -d

# 5. 等待并验证
sleep 40
docker compose ps
```

### 生产环境部署

```bash
# 1. 拉取最新代码
git pull origin main

# 2. 配置环境变量
cp .env.example .env
vim .env  # 编辑生产配置

# 3. 验证配置
./scripts/quick-verify.sh
docker compose -f docker-compose-prod.yml config

# 4. 构建镜像
docker compose -f docker-compose-prod.yml build

# 5. 启动服务
docker compose -f docker-compose-prod.yml up -d

# 6. 等待健康检查
echo "等待服务启动..."
sleep 40

# 7. 验证部署
docker compose -f docker-compose-prod.yml ps
./scripts/acceptance-test.sh

# 8. 监控启动
watch -n 5 'docker compose -f docker-compose-prod.yml ps'
```

## 🚨 回滚计划

如果部署出现问题，按以下步骤回滚：

### 方法 1: 使用旧镜像

```bash
# 1. 停止当前服务
docker compose -f docker-compose-prod.yml down

# 2. 恢复旧代码
git checkout <previous-commit>

# 3. 使用已有镜像启动
docker compose -f docker-compose-prod.yml up -d
```

### 方法 2: 完全重建

```bash
# 1. 完全清理
docker compose -f docker-compose-prod.yml down --volumes --rmi all

# 2. 检出稳定版本
git checkout <stable-tag>

# 3. 重新构建和启动
docker compose -f docker-compose-prod.yml build
docker compose -f docker-compose-prod.yml up -d
```

## ✅ 验收标准检查

### 标准 1: 非 root 用户运行

```bash
# Backend
docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) whoami
# 预期: appuser

docker exec $(docker compose -f docker-compose-prod.yml ps -q backend) id -u
# 预期: 1000

# Nginx
docker exec $(docker compose -f docker-compose-prod.yml ps -q nginx) whoami
# 预期: appuser

docker exec $(docker compose -f docker-compose-prod.yml ps -q nginx) id -u
# 预期: 1000
```

**验收**: 所有容器以 appuser (UID 1000) 运行 ✅

### 标准 2: 健康检查显示 healthy

```bash
docker compose -f docker-compose-prod.yml ps
# 预期: backend ... (healthy)
#       nginx ... (healthy)
```

**验收**: docker ps 显示 (healthy) ✅

### 标准 3: 故障自动恢复

```bash
# 停止 Backend
docker stop $(docker compose -f docker-compose-prod.yml ps -q backend)

# 检查 Nginx 响应
curl -i http://localhost/api/search?q=test
# 预期: HTTP/1.1 502 Bad Gateway

# 等待自动重启（30 秒内）
sleep 30

# 检查恢复
docker compose -f docker-compose-prod.yml ps
# 预期: backend ... (healthy)
```

**验收**: 后端崩溃时 Nginx 返回 502，服务自动恢复 ✅

### 标准 4: 资源限制生效

```bash
# 检查配置
grep -A 10 "resources:" docker-compose-prod.yml
# 预期: memory: 512M (backend)
#       memory: 256M (nginx)
```

**验收**: 内存限制配置正确 ✅

### 标准 5: 日志轮转

```bash
# 检查配置
docker inspect $(docker compose -f docker-compose-prod.yml ps -q backend) | jq '.[0].HostConfig.LogConfig'
# 预期: "max-size": "10m", "max-file": "5"
```

**验收**: 日志不无限增长 ✅

## 📈 性能基准

记录部署后的性能基准，用于后续监控：

### 响应时间

```bash
# 健康检查
curl -w "@-" -o /dev/null -s http://localhost/health <<< '
time_total: %{time_total}s
'
# 目标: < 0.1s

# API 搜索
curl -w "@-" -o /dev/null -s "http://localhost/api/search?q=test" <<< '
time_total: %{time_total}s
'
# 目标: < 1.0s
```

### 资源使用

```bash
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
# 目标: 
#   backend: CPU < 10%, Memory < 200MB
#   nginx: CPU < 5%, Memory < 50MB
```

### 压缩率

```bash
# 检查 Gzip 压缩
curl -H "Accept-Encoding: gzip" -I http://localhost/ | grep -i content-encoding
# 目标: Content-Encoding: gzip
```

## 🔍 故障排查检查清单

如果部署失败，按此顺序检查：

### 1. 配置问题

- [ ] 检查 .env 文件存在
- [ ] 验证环境变量正确
- [ ] 检查文件权限
- [ ] 验证 Docker Compose 语法

### 2. 构建问题

- [ ] 查看构建日志
- [ ] 检查网络连接
- [ ] 验证基础镜像可访问
- [ ] 检查磁盘空间

### 3. 运行时问题

- [ ] 查看容器日志
- [ ] 检查端口冲突
- [ ] 验证网络配置
- [ ] 检查资源限制

### 4. 健康检查问题

- [ ] 手动测试健康端点
- [ ] 检查服务是否监听正确端口
- [ ] 验证健康检查命令正确
- [ ] 增加启动宽限期

### 5. 权限问题

- [ ] 检查文件所有者
- [ ] 验证目录权限
- [ ] 检查 SELinux/AppArmor
- [ ] 验证 capabilities

## 📞 支持和文档

- 详细文档: [docker-security-reliability.md](docker-security-reliability.md)
- 快速开始: [quick-start-security.md](quick-start-security.md)
- 前后对比: [before-after-comparison.md](before-after-comparison.md)
- 改进总结: [../DOCKER-SECURITY-COMPLETE.md](../DOCKER-SECURITY-COMPLETE.md)

## 🎉 部署完成检查

部署成功的标志：

- ✅ 所有容器状态为 healthy
- ✅ 所有验收标准通过
- ✅ 响应时间正常
- ✅ 资源使用合理
- ✅ 无错误日志
- ✅ 服务稳定运行

**恭喜！您的 Docker 容器现在具备生产级别的安全性和可靠性！** 🎊

---

**记住**: 定期运行 `./scripts/test-docker-security.sh` 验证安全配置！

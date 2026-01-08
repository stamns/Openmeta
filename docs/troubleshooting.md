# 故障排查指南

## Vercel 部署常见问题

### 1. 函数返回 502 Bad Gateway

**排查步骤：**
1. Vercel Dashboard → Functions → Logs
2. 检查是否有 Import Error
3. 检查 `requirements.txt` 是否完整
4. 本地运行 `vercel dev` 测试

**解决方案：**

```bash
cd backend
vercel dev
curl -v 'http://localhost:3000/api/search?q=test'
```

### 2. 环境变量未生效

**症状：** API 返回 mock 数据（`source: "mock"`）

**解决方案：**
1. Vercel Dashboard → Settings → Environment Variables
2. 添加 PANSOU_HOST、PANSOU_USER、PANSOU_PWD
3. 确认应用到正确的环境（Production / Preview）
4. **重新部署**（环境变量修改需要重新构建）

### 3. 前端可以打开，但 API 404

**可能原因：**
- `vercel.json` 路由配置错误
- Root Directory 设置不匹配

**解决方案：**
1. 确认 Root Directory = `backend`
2. 检查 `vercel.json` 中 `routes` 配置
3. 确认访问路径为 `/api/search?q=...`

### 4. 冷启动时间过长（> 5s）

**优化措施：**
1. 减少 import 时间（延迟导入）
2. 使用连接池复用
3. 移除不必要的依赖包

### 5. PanSou 连接超时

**症状：** API 返回 `source: "fallback"` 且有 `error` 字段

**解决方案：**
1. 检查 PANSOU_HOST 是否正确（需要完整 URL）
2. 本地测试连通性：
   ```bash
   curl -u "$PANSOU_USER:$PANSOU_PWD" "$PANSOU_HOST/search?q=test"
   ```
3. 调整超时设置（`pansou.py`）

### 6. 日志写入失败（Read-only file system）

**解决方案：**
```python
# 使用 stdout（Vercel 会自动收集）
import logging
logging.basicConfig(level=logging.INFO)
```

查看日志：Vercel Dashboard → Functions → Logs

## Docker 部署常见问题

### 1. 容器启动后无法访问

```bash
# 检查容器状态
docker ps

# 查看日志
docker logs <container_id>

# 确认端口映射
docker port <container_id>
```

### 2. 环境变量未生效

```bash
docker run -p 8000:8000 \
  -e PANSOU_HOST="..." \
  -e PANSOU_USER="..." \
  -e PANSOU_PWD="..." \
  openmeta
```

## 本地开发常见问题

### 1. 导入错误（ModuleNotFoundError）

确保在 `backend/` 目录下运行：

```bash
cd backend
python -c "import openmeta"
```

### 2. 依赖安装失败

使用虚拟环境：

```bash
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## 性能监控

### Vercel Function 性能

Dashboard → Analytics：
- 函数执行时间
- 冷启动频率
- 并发请求数

### 优化建议

1. 缓存热数据（Redis/Upstash）
2. 减少外部请求
3. 使用异步处理
4. 适当降级（超时返回缓存）

## 获取帮助

- Vercel 文档：https://vercel.com/docs
- FastAPI 文档：https://fastapi.tiangolo.com
- GitHub Issues：提交问题到项目仓库

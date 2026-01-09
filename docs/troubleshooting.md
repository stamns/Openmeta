# OpenMeta Vercel 部署故障排查指南

本指南提供常见问题的诊断和解决方案，帮助您快速定位和解决部署问题。

## 🔍 诊断工具

### 1. 本地验证脚本

运行完整的验证检查：

```bash
./scripts/verify-deployment.sh
```

### 2. Vercel 函数日志

查看实时日志：

```bash
vercel logs [项目名称] --follow
```

查看特定函数日志：

```bash
vercel logs [项目名称] --follow --filter api/index.py
```

## ❌ 常见错误及解决方案

### 错误 1: 冷启动超时

**症状:**
```
Function timeout after 30 seconds
```

**原因:**
- 依赖导入过多
- 初始化耗时过长
- PanSou 服务连接超时

**解决方案:**

1. **优化导入**
   ```python
   # 避免在模块顶部导入大量库
   # 使用延迟导入
   async def get_data():
       import heavy_library
       return heavy_library.process()
   ```

2. **连接池优化**
   ```python
   # 在函数外部定义连接池
   _client = None
   
   def get_client():
       global _client
       if _client is None:
           _client = httpx.AsyncClient()
       return _client
   ```

3. **超时设置**
   ```json
   {
     "functions": {
       "api/index.py": {
         "maxDuration": 30
       }
     }
   }
   ```

### 错误 2: 内存不足

**症状:**
```
Memory limit exceeded
```

**原因:**
- 处理的数据量过大
- 内存泄漏
- 缓存过多数据

**解决方案:**

1. **流式处理**
   ```python
   async def stream_large_data():
       async for chunk in data_source:
           yield chunk
   ```

2. **减少缓存**
   ```python
   # 使用更小的缓存大小
   @lru_cache(maxsize=10)  # 从 100 减少到 10
   def cached_function():
       return expensive_computation()
   ```

3. **内存配置**
   ```json
   {
     "functions": {
       "api/index.py": {
         "memory": 1024
       }
     }
   }
   ```

### 错误 3: 导入错误

**症状:**
```
ModuleNotFoundError: No module named 'xxx'
```

**原因:**
- 依赖未正确安装
- 路径配置错误
- 版本不兼容

**解决方案:**

1. **检查 requirements.txt**
   ```txt
   fastapi>=0.110,<1.0
   uvicorn[standard]>=0.27
   httpx>=0.26,<1.0
   ```

2. **路径配置**
   ```python
   # 确保正确的路径
   import sys
   from pathlib import Path
   
   BACKEND_DIR = Path(__file__).resolve().parents[1]
   sys.path.insert(0, str(BACKEND_DIR))
   ```

3. **版本锁定**
   ```bash
   pip freeze > requirements-lock.txt
   ```

### 错误 4: 环境变量未设置

**症状:**
```
KeyError: 'PANSOU_HOST'
```

**原因:**
- Vercel 环境变量未配置
- 环境变量名称错误
- 权限问题

**解决方案:**

1. **检查环境变量设置**
   ```bash
   vercel env ls
   ```

2. **重新设置环境变量**
   ```bash
   vercel env add PANSOU_HOST production
   # 输入: http://112.124.53.114:8888
   ```

3. **代码中验证**
   ```python
   import os
   
   pansou_host = os.getenv("PANSOU_HOST")
   if not pansou_host:
       raise ValueError("PANSOU_HOST environment variable is required")
   ```

### 错误 5: PanSou 服务连接失败

**症状:**
```
Connection timeout to PanSou service
```

**原因:**
- PanSou 服务地址错误
- 网络连接问题
- 认证失败

**解决方案:**

1. **测试连接**
   ```bash
   curl -v http://112.124.53.114:8888/api/search?q=test
   ```

2. **超时配置**
   ```python
   timeout = httpx.Timeout(10.0, connect=5.0)
   client = httpx.AsyncClient(timeout=timeout)
   ```

3. **错误处理**
   ```python
   try:
       response = await client.get(url, params=params)
   except httpx.TimeoutException:
       return {"error": "PanSou service timeout"}
   except httpx.ConnectError:
       return {"error": "Cannot connect to PanSou service"}
   ```

### 错误 6: CORS 错误

**症状:**
```
CORS policy: No 'Access-Control-Allow-Origin' header
```

**原因:**
- CORS 配置错误
- 预检请求失败

**解决方案:**

1. **正确配置 CORS**
   ```python
   from fastapi.middleware.cors import CORSMiddleware
   
   app.add_middleware(
       CORSMiddleware,
       allow_origins=["*"],  # 或指定具体域名
       allow_credentials=True,
       allow_methods=["GET", "POST", "OPTIONS"],
       allow_headers=["*"],
   )
   ```

2. **处理 OPTIONS 请求**
   ```python
   @app.options("/api/search")
   async def options_handler():
       return JSONResponse(content={})
   ```

## 🔧 性能优化问题

### 冷启动时间过长

**诊断:**
```bash
# 查看函数执行时间
vercel logs [项目名称] | grep "Duration"
```

**优化策略:**

1. **减少依赖**
   ```python
   # 避免导入不必要的库
   # 只导入实际使用的模块
   ```

2. **延迟初始化**
   ```python
   _initialized = False
   
   def lazy_init():
       global _initialized
       if not _initialized:
           # 初始化代码
           _initialized = True
   ```

3. **连接复用**
   ```python
   # 复用 HTTP 连接
   _connection_pool = None
   
   def get_connection():
       global _connection_pool
       if _connection_pool is None:
           _connection_pool = httpx.AsyncClient()
       return _connection_pool
   ```

## 📊 监控和告警

### 设置监控

1. **Vercel Analytics**
   ```bash
   # 在 Vercel Dashboard 中启用 Analytics
   # 查看性能指标和错误率
   ```

2. **自定义指标**
   ```python
   import time
   
   start_time = time.time()
   # 处理逻辑
   duration = time.time() - start_time
   
   print(f"Function duration: {duration:.2f}s")
   ```

3. **错误追踪**
   ```python
   import logging
   
   logger = logging.getLogger("openmeta")
   logger.error(f"Search failed: {str(e)}", extra={
       "query": q,
       "duration": duration,
       "error": str(e)
   })
   ```

## 🛠️ 调试技巧

### 本地模拟 Vercel 环境

```bash
# 使用 Vercel CLI 本地测试
vercel dev

# 或使用 Python 直接测试
python3 -c "
import os
os.environ['VERCEL'] = '1'
from api.index import app
import uvicorn
uvicorn.run(app, host='127.0.0.1', port=8000)
"
```

### 分步骤调试

```python
# 添加调试日志
import logging

logger = logging.getLogger("openmeta")
logger.info(f"Environment: VERCEL={os.getenv('VERCEL')}")
logger.info(f"PANSOU_HOST: {os.getenv('PANSOU_HOST')}")
logger.info(f"Import path: {sys.path}")
```

### 网络诊断

```python
import httpx

async def diagnose_connection():
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "http://httpbin.org/get",
                timeout=httpx.Timeout(5.0)
            )
            print(f"HTTP Status: {response.status_code}")
    except Exception as e:
        print(f"Network error: {e}")
```

## 📞 获取帮助

### 日志收集

在提交问题时请收集：

1. **函数日志**
   ```bash
   vercel logs [项目名称] > logs.txt
   ```

2. **环境信息**
   ```bash
   vercel inspect [项目名称] > environment.txt
   ```

3. **配置信息**
   ```bash
   cat vercel.json > config.json
   ```

### 常见问题快速检查清单

- [ ] 环境变量是否正确设置
- [ ] PanSou 服务是否可访问
- [ ] requirements.txt 依赖是否完整
- [ ] vercel.json 配置是否正确
- [ ] 网络连接是否正常
- [ ] 内存使用是否超限
- [ ] 冷启动时间是否合理

### 社区资源

- [Vercel 官方文档](https://vercel.com/docs)
- [FastAPI 部署指南](https://fastapi.tiangolo.com/deployment/)
- [Python 无服务器最佳实践](https://docs.aws.amazon.com/lambda/latest/operatorguide/serverless-python.html)

---

**记住：大多数部署问题都可以通过仔细检查日志和环境配置来解决！** 🔧
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

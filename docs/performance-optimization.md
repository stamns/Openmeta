# 性能优化指南

## Vercel Serverless 冷启动优化

### 1. 减少 Import 时间

延迟导入大型库：

```python
# 不推荐
import pandas as pd

# 推荐
async def process():
    import pandas as pd
    ...
```

### 2. 连接池复用

已在 `pansou.py` 中实现：

```python
async def _get_client():
    if not hasattr(_get_client, "_client"):
        import httpx
        _get_client._client = httpx.AsyncClient(...)
    return _get_client._client
```

### 3. 依赖包优化

当前依赖（已优化）：
- fastapi (~100KB)
- uvicorn
- mangum (~20KB)
- httpx (~200KB)

总计 < 5MB，远低于 Vercel 250MB 限制。

### 4. 内存缓存

```python
from functools import lru_cache

@lru_cache(maxsize=128)
def cached_function(key):
    ...
```

### 5. 外部缓存（Redis）

推荐使用 Vercel KV (Upstash Redis)：

```bash
vercel kv create
```

```python
from redis.asyncio import Redis

async def get_redis():
    return Redis.from_url(os.getenv("KV_URL"))
```

## Docker 性能优化

### 多阶段构建

```dockerfile
FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.11-slim
COPY --from=builder /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH
CMD ["uvicorn", "main:app", "--host", "0.0.0.0"]
```

### Uvicorn 并发

```bash
uvicorn main:app --workers 4
```

## 监控

### Vercel Analytics

Dashboard → Analytics 查看：
- 函数执行时间
- 冷启动频率
- 内存使用

### 自定义指标

```python
import time

@app.middleware("http")
async def add_process_time(request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    process_time = time.perf_counter() - start
    response.headers["X-Process-Time"] = str(process_time)
    return response
```

## 成本优化

### Vercel 免费额度（Hobby）

- 函数执行时间：100 GB-Hours/月
- 函数调用：100K 次/月
- 带宽：100 GB/月

估算：单次请求 200ms (0.2s) × 512MB (0.5GB) = 0.1 GB-s
免费额度可支持约 360万次请求。

### 建议

1. 启用缓存（Redis）
2. 降低函数内存配置
3. 异步批处理
4. CDN 缓存静态资源

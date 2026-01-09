# OpenMeta 架构说明

## 目录结构

```
backend/
├── api/index.py          # Vercel Function 入口（Mangum）
├── openmeta/
│   ├── main.py           # FastAPI app
│   ├── routers/search.py # /api/search 路由
│   └── services/pansou.py # PanSou API 调用
├── public/               # 前端静态资源
├── requirements.txt
├── Dockerfile
└── vercel.json
```

## 技术栈

- **FastAPI**: 高性能异步 Web 框架
- **Uvicorn**: 本地/Docker ASGI 服务器
- **Mangum**: Lambda/Vercel → ASGI 适配器
- **httpx**: 异步 HTTP 客户端

## 数据流

### 本地/Docker

```
浏览器 → Uvicorn → FastAPI → search.py → pansou.py → PanSou API
```

### Vercel

```
浏览器 → Vercel CDN → Lambda Function (api/index.py)
                        ↓ Mangum
                     FastAPI → search.py → pansou.py → PanSou API
```

## 关键设计

### 1. 为什么使用 Mangum？

Vercel Python Runtime 基于 AWS Lambda，Mangum 负责 Lambda event/context 与 ASGI 的转换。

### 2. 为什么延迟导入 httpx？

冷启动优化：首次调用时才导入，减少 import 时间。

### 3. 为什么提供 mock/fallback？

- 无 PANSOU_HOST：返回 mock（方便演示）
- PanSou 调用失败：返回 fallback + error（保证可用性）

### 4. 文件系统处理

Vercel 只读：日志输出到 stdout，不写入本地文件。

## API 接口

### GET /api/search

| 参数 | 类型 | 必填 | 说明 |
|-----|------|-----|------|
| q | string | 是 | 搜索关键词 |
| limit | integer | 否 | 返回条数（默认 20，最大 50）|

**响应示例：**

```json
{
  "query": "test",
  "source": "mock",
  "items": [...],
  "took_ms": 1
}
```

## 扩展性

### 添加新路由

1. 在 `backend/openmeta/routers/` 创建新文件
2. 在 `main.py` 注册：

```python
from openmeta.routers.new_router import router as new_router
app.include_router(new_router, prefix="/api")
```

### 添加中间件

```python
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(CORSMiddleware, ...)
```

## 性能指标

| 指标 | 本地/Docker | Vercel 冷启动 | Vercel 热启动 |
|-----|-----------|-------------|-------------|
| 启动时间 | <1s | ~700ms | <100ms |
| API 响应 | 50-200ms | 100-500ms | 50-200ms |

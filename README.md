# OpenMeta

> 支持**本地开发**、**Docker 容器化**、**Vercel 无服务器**三种部署方式的 FastAPI 应用

## 特性

- 三层部署支持：本地 / Docker / Vercel Serverless
- FastAPI 后端：高性能异步 Web 框架
- 静态前端：轻量级原生 HTML/CSS/JS
- PanSou 集成：支持外部 API 调用 + Fallback 机制
- 最小依赖：仅 4 个核心包，冷启动 < 1s
- 开箱即用：自动 CORS、健康检查、API 文档

## 项目结构

```
openmeta/
├── backend/              # 后端代码
│   ├── api/
│   │   └── index.py      # Vercel Function 入口
│   ├── openmeta/
│   │   ├── main.py       # FastAPI 应用
│   │   ├── routers/      # API 路由
│   │   └── services/     # 业务逻辑
│   ├── public/           # 前端静态资源
│   ├── requirements.txt
│   ├── Dockerfile
│   └── vercel.json
├── docs/                 # 文档
└── vercel.json
```

## 快速开始

### 方式 1: 本地运行

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

访问：http://localhost:8000

### 方式 2: Docker 运行

```bash
cd backend
docker build -t openmeta .
docker run -p 8000:8000 openmeta
```

访问：http://localhost:8000

### 方式 3: Vercel 部署

#### 通过 GitHub

1. Fork 本仓库到你的 GitHub
2. 访问 [Vercel Dashboard](https://vercel.com/new)
3. 导入 GitHub 仓库
4. 设置 **Root Directory** = `backend`
5. 配置环境变量（可选）
6. 点击 **Deploy**

#### 通过 CLI

```bash
npm i -g vercel
vercel login
vercel --prod
```

访问：https://your-project.vercel.app

## 文档

- [Vercel 部署指南](./docs/vercel-deployment.md) - 环境变量、路由配置、优化
- [快速开始](./docs/quick-start.md) - 三种部署方式详细步骤
- [部署方式对比](./docs/deployment-comparison.md) - 本地/Docker/Vercel 对比
- [架构说明](./docs/architecture.md) - 技术栈、数据流
- [性能优化](./docs/performance-optimization.md) - 冷启动优化、缓存
- [故障排查](./docs/troubleshooting.md) - 常见问题解决

## API 接口

### GET /api/search

**请求参数：**
- `q` (string, 必填): 搜索关键词
- `limit` (integer, 可选): 返回条数（默认 20，最大 50）

**响应示例：**

```json
{
  "query": "test",
  "limit": 20,
  "source": "mock",
  "items": [
    {"title": "Result 1 for test", "url": null}
  ],
  "took_ms": 1
}
```

### GET /health

健康检查接口

```json
{"status": "ok"}
```

## 环境变量

创建 `backend/.env` 文件：

```env
PANSOU_HOST=https://your-pansou-api.com
PANSOU_USER=your_username
PANSOU_PWD=your_password
```

如果未配置，将返回 Mock 数据。

## 技术栈

- **后端框架**: FastAPI
- **ASGI 服务器**: Uvicorn
- **Serverless 适配**: Mangum
- **HTTP 客户端**: httpx
- **前端**: 原生 JS

## 性能指标

| 指标 | 本地/Docker | Vercel 冷启动 | Vercel 热启动 |
|-----|-----------|-------------|-------------|
| 启动时间 | <1s | ~700ms | <100ms |
| API 响应 | 50-200ms | 100-500ms | 50-200ms |
| 并发能力 | 取决于服务器 | 自动扩展 | 自动扩展 |

## 开源协议

MIT License

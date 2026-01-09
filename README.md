# OpenMeta - 三层部署支持的元数据聚合平台

<div align="center">
> 支持**本地开发**、**Docker 容器化**、**Vercel 无服务器**三种部署方式的 FastAPI 应用
# OpenMeta - 网盘聚合搜索引擎

## 简介
OpenMeta 是一个**网盘聚合搜索引擎**，采用混合引擎架构（**FastAPI + PanSou + Vue3**）：

- **前端**：Vue3（Vite）提供简洁的搜索 UI
- **后端**：FastAPI 提供统一 API（`/api/search`）与健康检查（`/health`）
- **搜索源**：对接 PanSou（可通过环境变量配置）；未配置时可降级返回空结果，便于快速跑通

本仓库提供三种部署方式：
- 方案 A：本地开发（后端热更新 + 前端 dev server）
- 方案 B：Docker 部署（Nginx 托管前端 + 反代后端，一键上线）
- 方案 C：Vercel 部署（GitHub 自动构建 + 全球边缘网络 + 免费额度可用）

---

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
This repository is structured to support **three deployment layers**:

![OpenMeta](https://img.shields.io/badge/OpenMeta-v1.0.0-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-green.svg)
![Vercel](https://img.shields.io/badge/部署-Vercel-orange.svg)
![Docker](https://img.shields.io/badge/部署-Docker-blue.svg)

**一个基于 PanSou 搜索的元数据聚合平台，支持本地、Docker、Vercel 三层部署**

[快速开始](#-快速开始) • [部署文档](./docs/vercel-deployment.md) • [故障排查](./docs/troubleshooting.md)

</div>

## ✨ 特性

- 🚀 **三层部署支持**: 本地开发、Docker 容器化、Vercel 无服务器
- 🌍 **全球加速**: Vercel CDN 和边缘节点
- 🔍 **智能搜索**: 基于 PanSou 的高效搜索服务
- ⚡ **高性能**: 冷启动优化和连接池缓存
- 🔧 **易于部署**: 一键部署到多个平台
- 📊 **完整监控**: 健康检查和性能监控
- 🔒 **安全可靠**: CORS 配置和环境变量管理

## 🏗️ 架构概览

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   本地开发       │    │   Docker 容器    │    │  Vercel 无服务器 │
│                 │    │                  │    │                 │
│ uvicorn main:app│    │ docker-compose  │    │ vercel.json    │
│ --reload        │    │ --build         │    │ 自动扩展       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌──────────────────┐
                    │  OpenMeta API    │
                    │                  │
                    │ • /health        │
                    │ • /api/search    │
                    │ • /docs          │
                    └──────────────────┘
                                 │
                    ┌──────────────────┐
                    │  PanSou 搜索     │
                    │                  │
                    │ 112.124.53.114   │
                    └──────────────────┘
```

## 🚀 快速开始

### 方案一：本地开发

```bash
# 克隆项目
git clone <your-repo-url>
cd openmeta

# 安装依赖
cd backend
pip install -r requirements.txt

# 配置环境
cp .env.local.example .env.local
# 编辑 .env.local 填入 PanSou 配置

# 启动服务
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 访问 http://localhost:8000
```

### 方案二：Docker 部署

```bash
# 使用 Docker Compose
docker-compose up --build

# 访问 http://localhost:8000
```

### 方案三：Vercel 部署

```bash
# 安装 Vercel CLI
npm install -g vercel

# 配置环境变量
cd backend
vercel env add PANSOU_HOST
vercel env add PANSOU_USER  
vercel env add PANSOU_PWD

# 部署
vercel

# 访问生成的 Vercel URL
```

## 🔧 配置
以下示例以 **Docker 一键部署**为最快路径（适合“先上线再优化”）：

```bash
git clone <your-repo-url> openmeta && cd openmeta
cp .env.example .env
./scripts/deploy-docker.sh
```

部署完成后：
- Web：`http://<服务器IP>/`
- Health：`http://<服务器IP>/health`
- API：`http://<服务器IP>/api/search?q=三体`

建议立即做一次健康检查：

```bash
./scripts/health-check.sh --mode docker
```

> 如需获得真实搜索结果，请编辑 `.env` 并配置 `PANSOU_HOST / PANSOU_USER / PANSOU_PWD`。

---

## 三种部署方案

### 方案 A：本地开发

#### 环境要求
- Python **3.9+**
- Node.js **18+**（前端开发/构建需要）

#### 一键初始化并启动后端

```bash
./scripts/setup-local.sh
```

脚本会自动完成：检查 Python 版本 → 创建虚拟环境 → 安装依赖 → 生成 `.env` → 启动后端（热更新）。

默认访问：
- 后端：`http://127.0.0.1:8000`
- 健康检查：`http://127.0.0.1:8000/health`
- 搜索接口：`http://127.0.0.1:8000/api/search?q=三体`

#### 启动前端（Vue3）

### 环境变量

| 变量名 | 必需 | 默认值 | 说明 |
|--------|------|--------|------|
| `PANSOU_HOST` | ✅ | - | PanSou 服务器地址 |
| `PANSOU_USER` | ❌ | - | PanSou 用户名 |
| `PANSOU_PWD` | ❌ | - | PanSou 密码 |
| `LOG_LEVEL` | ❌ | INFO | 日志级别 |
| `CORS_ALLOW_ORIGINS` | ❌ | * | CORS 允许的源 |

### 本地配置

```bash
# 复制并编辑配置文件
cp backend/.env.local.example backend/.env.local
```

### Vercel 配置

在 Vercel Dashboard > Settings > Environment Variables 中设置：
前端地址：`http://127.0.0.1:5173`

#### 本地健康检查（包含一次测试搜索）

```bash
./scripts/health-check.sh --mode local
```

- `PANSOU_HOST`
- `PANSOU_USER`
- `PANSOU_PWD`

## 📊 API 文档

部署后访问以下端点：

- **API 基础信息**: `GET /`
- **健康检查**: `GET /health`
- **搜索接口**: `GET /api/search?q=关键词&page=1`
- **API 文档**: `GET /docs`
- **ReDoc**: `GET /redoc`

### 搜索示例

```bash
# 使用 curl
curl "https://your-app.vercel.app/api/search?q=python&page=1"

# 使用浏览器
https://your-app.vercel.app/api/search?q=python
```

## 🛠️ 开发指南

### 项目结构

```
openmeta/
├── backend/                 # Python FastAPI 应用
│   ├── api/                 # Vercel 入口
│   │   └── index.py        # Vercel Function
│   ├── app/                # 应用核心
│   │   ├── main.py         # FastAPI 主应用
│   │   ├── settings.py     # 配置管理
│   │   └── services/       # 业务服务
│   ├── assets/             # 前端静态资源
│   │   ├── app.js
│   │   └── style.css
│   ├── main.py             # 本地开发入口
│   ├── index.html          # 前端页面
│   ├── requirements.txt    # Python 依赖
│   ├── vercel.json         # Vercel 配置
│   └── .env.local.example  # 环境变量模板
├── docs/                   # 文档
│   ├── vercel-deployment.md
│   └── troubleshooting.md
├── scripts/                # 脚本工具
│   └── verify-deployment.sh
├── docker-compose.yml      # Docker 配置
└── README.md
```

### 开发命令

```bash
# 本地开发
cd backend
uvicorn main:app --reload

# 运行测试
python3 scripts/verify-deployment.sh

# Vercel 本地测试
cd backend
vercel dev

# Docker 开发
docker-compose up --build
```

## 🚀 部署特性

### Vercel 无服务器部署

- **全球 CDN**: 自动全球加速
- **自动扩展**: 根据流量自动调整
- **零运维**: 无需管理服务器
- **按使用付费**: 只为实际使用付费
- **HTTPS 自动**: 自动 SSL 证书
#### 前置条件
- Docker
- Docker Compose（`docker compose` 或 `docker-compose`）

#### 一键启动

```bash
cp .env.example .env
./scripts/deploy-docker.sh
```

> 默认会使用 `docker-compose-prod.yml`：
> - Nginx：托管前端静态文件 + 反代后端 `/api/*` 与 `/health`
> - 后端：FastAPI
> - Redis：默认不启用（可选 profile）

#### 内存占用说明
- 默认配置下（后端 + Nginx），通常**< 500MB**（与机器、并发、日志量有关）。
- `docker-compose-prod.yml` 中包含 `deploy.resources` 的参考限制（注意：非 Swarm 模式下该字段可能被 Docker Compose 忽略，仅作为建议）。

#### （可选）启用 Redis

```bash
./scripts/deploy-docker.sh --with-redis
```

并在 `.env` 中设置：

```env
REDIS_HOST=redis
```

#### 更新/升级步骤

```bash
git pull
./scripts/deploy-docker.sh
```

常用运维命令：

```bash
# 查看日志
docker compose -f docker-compose-prod.yml logs -f --tail=200

# 查看运行状态
docker compose -f docker-compose-prod.yml ps

# 停止
docker compose -f docker-compose-prod.yml down
```

---

### 方案 C：Vercel 部署

#### 你需要
- GitHub 账号（推荐走 Git 集成自动部署）

#### 自动部署配置
1. 将代码推送到 GitHub
2. 打开 https://vercel.com/new 导入仓库
3. 保持 Root Directory 为**仓库根目录**（本仓库提供根目录 `vercel.json`）
4. 在 Project → Settings → Environment Variables 配置环境变量（见下文）
5. 点击 Deploy

也可以用脚本快速检查配置并打印步骤：

```bash
./scripts/deploy-vercel.sh
```

#### 域名绑定
Vercel Dashboard：Project → Settings → Domains，按提示添加域名并配置 DNS。

#### 成本说明（免费）
- **Vercel Free**：适合个人/小流量站点（可能存在冷启动与配额限制）
- **Vercel Pro**：适合更高并发、团队协作、更高配额与 SLA

---

## 环境变量
环境变量模板见仓库根目录：`.env.example`。

### 完整列表与说明

| 变量名 | 必填 | 说明 | 示例 |
|---|---:|---|---|
| `PANSOU_HOST` | 否 | PanSou 服务地址；不填则降级返回空结果（用于快速跑通） | `http://112.124.53.114:8888` |
| `PANSOU_USER` | 否 | PanSou 账号 | `admin` |
| `PANSOU_PWD` | 否 | PanSou 密码 | `******` |
| `REDIS_HOST` | 否 | Redis 主机（启用 Redis 时建议为 `redis`） | `redis` |
| `REDIS_PORT` | 否 | Redis 端口 | `6379` |
| `REDIS_PASSWORD` | 否 | Redis 密码 |  |
| `BACKEND_HOST` | 否 | 本地后端监听地址（脚本用） | `0.0.0.0` |
| `BACKEND_PORT` | 否 | 本地后端端口（脚本用） | `8000` |
| `LOG_LEVEL` | 否 | 日志级别 | `INFO` |
| `RATE_LIMIT_PER_MINUTE` | 否 | 每 IP 每分钟请求数（可选） | `10` |
| `SEARCH_TIMEOUT` | 否 | 请求 PanSou 的超时（秒） | `15` |
| `CORS_ALLOW_ORIGINS` | 否 | CORS 允许来源（逗号分隔） | `http://localhost:5173` |
| `APP_MODULE` | 否 | 覆盖后端入口（一般不需要） | `backend.app.main:app` |

### 三种部署方式的配置方法

- **本地开发**：
  - `cp .env.example .env` 后编辑 `.env`
  - `./scripts/setup-local.sh` 会在没有 `.env` 时自动复制生成

- **Docker**：
  - 推荐：服务器上创建/编辑 `.env`
  - `docker-compose-prod.yml` 通过 `env_file: .env` 注入

- **Vercel**：
  - Vercel Dashboard → Project → Settings → Environment Variables
  - 生产建议只在 Production 环境配置密钥

### Docker 容器化

- **标准化部署**: 一致的运行环境
- **易于扩展**: 简单的水平扩展
- **本地模拟**: 与生产环境一致
- **团队协作**: 统一开发环境

### 本地开发

- **热重载**: 代码修改即时生效
- **调试友好**: 完整的错误信息
- **快速迭代**: 最快的开发体验

## 📈 性能优化

### 冷启动优化

- **延迟导入**: 按需加载模块
- **连接池**: HTTP 连接复用
- **环境预配置**: 启动时环境变量处理

### 内存优化

- **LRU 缓存**: 智能缓存管理
- **连接限制**: 控制并发连接数
- **资源清理**: 自动资源释放

## 🔍 监控和日志

### 健康检查
### 常见问题
1. **前端能打开，但搜索为空/报错**
   - 未配置 `PANSOU_HOST`：后端会降级返回空结果（这是预期行为）
   - 已配置但不可达：检查 PanSou 是否可访问、账号密码是否正确

2. **Docker 部署后 /health 不通 或 502**
   - 端口冲突：确认宿主机 80 端口未被占用
   - 查看日志：`docker compose -f docker-compose-prod.yml logs -f --tail=200`

3. **Vercel 部署后 API 超时**
   - 外部依赖（PanSou）对 Vercel 出网不可达
   - 适当降低 `SEARCH_TIMEOUT`

4. **CORS 跨域问题（本地开发常见）**
   - `.env` 设置：`CORS_ALLOW_ORIGINS=http://localhost:5173`

### 日志查看方法
- 本地：直接看 `uvicorn` 输出
- Docker：`docker compose -f docker-compose-prod.yml logs -f --tail=200`
- Vercel：Dashboard → Deployments → Functions → Logs

### 性能诊断
用 `curl` 观察接口耗时：

```bash
curl https://your-app.vercel.app/health
```

响应示例：
```json
{
  "status": "ok",
  "service": "OpenMeta",
  "version": "1.0.0",
  "pansou_host": "http://112.124.53.114:8888"
}
```

### 日志查看

```bash
# Vercel 日志
vercel logs your-app --follow

# 本地日志
tail -f logs/openmeta.log
```
---

## 架构说明

### 系统架构图

```mermaid
flowchart LR
  U[User] --> FE[Vue3 Web]
  FE -->|/api/search| API[FastAPI]
  API -->|HTTP| PS[PanSou]
  API -. optional .-> R[(Redis)]
```

### 组件说明
- **Vue3**：负责展示与交互，调用 `/api/search` 获取搜索结果
- **FastAPI**：统一封装外部搜索源接口，输出结构化 JSON
- **PanSou**：外部搜索源（可替换/扩展）
- **Redis（可选）**：用于缓存、限流等

### 数据流程
1. 用户在前端输入关键词
2. 前端请求：`GET /api/search?q=<keyword>`
3. 后端请求 PanSou，并返回结果（失败时返回空结果 + error 信息）
4. 前端渲染结果列表

## 🛠️ 故障排查

常见问题和解决方案请参考：[故障排查指南](./docs/troubleshooting.md)

## 🤝 贡献指南
## 开发指南

### 本地修改代码步骤
1. 启动后端：`./scripts/setup-local.sh`
2. 启动前端：`cd frontend && npm install && npm run dev`
3. 修改代码后：
   - 后端会自动热更新
   - 前端会自动热更新

### 提交 PR 流程
1. Fork 仓库并创建 feature 分支
2. 保持改动小而清晰（一次 PR 聚焦一个问题）
3. 在 PR 描述中写清：改动点 / 测试方式 / 影响范围

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

## 📄 许可证
## 部署对比表

| 方案 | 成本 | 性能 | 维护 | 适用场景 |
|------|------|------|------|---------|
| 本地 | 免费 | 快 | 低 | 开发调试 |
| Docker | 低 | 快 | 中 | 团队服务器 |
| Vercel | 免费 | 快 | 低 | 小流量站点 |

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🎯 路线图

- [ ] 更多搜索引擎支持
- [ ] 用户认证系统
- [ ] 搜索结果缓存
- [ ] 高级搜索过滤器
- [ ] 搜索历史记录
- [ ] API 限流管理

## 📞 支持

- 📖 [部署文档](./docs/vercel-deployment.md)
- 🔧 [故障排查](./docs/troubleshooting.md)
- 🐛 [问题反馈](https://github.com/your-repo/issues)
- 💬 [讨论区](https://github.com/your-repo/discussions)

---

<div align="center">

**让搜索变得简单而强大** 🔍

[Star ⭐](https://github.com/your-repo) • [Fork 🍴](https://github.com/your-repo/fork) • [Deploy 🚀](https://vercel.com/new)

</div>
### 一键启动命令
- 本地后端：`./scripts/setup-local.sh`
- Docker 上线：`cp .env.example .env && ./scripts/deploy-docker.sh`
- Vercel 指南：`./scripts/deploy-vercel.sh`

### 常用故障排查命令

```bash
# 本地健康检查
./scripts/health-check.sh --mode local

# Docker 健康检查
./scripts/health-check.sh --mode docker

# Docker 日志
docker compose -f docker-compose-prod.yml logs -f --tail=200
```

### 环境变量速查表（最常用）
- `PANSOU_HOST / PANSOU_USER / PANSOU_PWD`
- `CORS_ALLOW_ORIGINS`
- `LOG_LEVEL`


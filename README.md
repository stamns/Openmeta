# OpenMeta - 三层部署支持的元数据聚合平台

<div align="center">

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

## 🛠️ 故障排查

常见问题和解决方案请参考：[故障排查指南](./docs/troubleshooting.md)

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

## 📄 许可证

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
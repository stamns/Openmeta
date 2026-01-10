# Vercel 无服务器部署指南

本指南将帮助你使用 Vercel 平台部署 OpenMeta 应用，实现自动构建、全球边缘网络和免费额度。

## 📋 目录

- [快速开始](#快速开始)
- [环境变量配置](#环境变量配置)
- [部署流程](#部署流程)
- [域名和 HTTPS](#域名和-https)
- [常见问题排查](#常见问题排查)
- [性能优化](#性能优化)

## 🚀 快速开始

### 前置要求

1. GitHub 账号
2. Vercel 账号（免费注册）
3. OpenMeta 代码仓库已推送到 GitHub

### 一键部署

1. **导入项目到 Vercel**

   ```bash
   # 安装 Vercel CLI（可选）
   npm install -g vercel

   # 登录 Vercel
   vercel login

   # 部署项目
   vercel
   ```

2. **通过 Vercel Dashboard 部署**

   - 访问 [vercel.com/new](https://vercel.com/new)
   - 导入你的 GitHub 仓库
   - Vercel 会自动检测 `vercel.json` 配置
   - 点击 "Deploy" 开始部署

## 🔧 环境变量配置

### 必需的环境变量

在 Vercel Dashboard 中配置以下环境变量（Project Settings → Environment Variables）：

| 变量名 | 说明 | 示例 | 必需 |
|--------|------|------|------|
| `PANSOU_HOST` | PanSou 服务器地址 | `https://pansou.example.com` | ✅ |
| `PANSOU_USER` | PanSou 用户名 | `your_username` | ✅ |
| `PANSOU_PWD` | PanSou 密码 | `your_password` | ✅ |
| `SEARCH_TIMEOUT` | 搜索超时（秒） | `15` | ⚪ |

### 配置步骤

1. 进入 Vercel Dashboard
2. 选择你的项目
3. 点击 "Settings" → "Environment Variables"
4. 添加上述环境变量
5. 选择环境：`Production`, `Preview`, `Development`（建议全部选中）
6. 点击 "Save" 保存
7. **重新部署项目**使环境变量生效

### 环境变量模板

```bash
# .env.example 文件内容
PANSOU_HOST=https://your-pansou-server.com
PANSOU_USER=your_username
PANSOU_PWD=your_password
SEARCH_TIMEOUT=15
```

## 📦 部署流程
# OpenMeta Vercel 部署指南

本指南将帮助您将 OpenMeta 部署到 Vercel 平台，实现 GitHub 自动构建、全球边缘网络和免费额度。
本指南将指导您如何将 OpenMeta 项目部署到 Vercel 平台。

## 部署准备

- **GitHub 自动构建**: 每次 push 自动触发部署
- **全球边缘网络**: Vercel 自动配置 CDN 和 HTTPS
- **免费额度**: 适合个人/小流量站点
- **三层部署**: 同时支持本地开发、Docker 和 Vercel 无服务器
1. **GitHub 账号**: 确保项目已托管在 GitHub 上。
2. **Vercel 账号**: 访问 [vercel.com](https://vercel.com) 并关联您的 GitHub 账号。

## 部署步骤

### 必要条件

- Vercel 账号 ([注册地址](https://vercel.com/signup))
- GitHub 仓库
- PanSou 搜索服务凭证

### 环境变量配置
### 1. 导入项目
在 Vercel 控制台中，点击 "Add New" -> "Project"，然后选择您的 OpenMeta 仓库。

### 2. 配置项目
Vercel 会自动识别项目结构，但请确保以下配置正确：

- **Framework Preset**: 选择 `Other` 或让其自动检测（Vite 将被识别为前端，Python 将被识别为后端）。
- **Root Directory**: 保持为项目根目录。

### 3. 配置环境变量
这是最关键的一步。在 "Environment Variables" 部分，添加以下变量：

| 变量名 | 说明 | 示例值 |
| :--- | :--- | :--- |
| `PANSOU_HOST` | PanSou 服务器地址 | `https://api.example.com` |
| `PANSOU_USER` | PanSou 用户名 | `your_username` |
| `PANSOU_PWD` | PanSou 密码 | `your_password` |
| `CORS_ALLOW_ORIGINS` | 允许的 CORS 源 | `*` 或您的域名 |

> **注意**: 在 `vercel.json` 中，我们引用了 `@pansou_host` 等变量。如果您在 Vercel UI 中直接创建同名变量，Vercel 会自动映射。

### 4. 部署
点击 "Deploy"。Vercel 将开始：
1. 使用 `frontend/package.json` 构建前端。
2. 配置 `backend/api/index.py` 作为无服务器函数。
3. 应用 `vercel.json` 中的路由规则。

## 常见问题排查

| 变量名 | 示例值 | 说明 |
|--------|--------|------|
| `PANSOU_HOST` | `http://112.124.53.114:8888` | PanSou 服务器地址 |
| `PANSOU_USER` | `admin` | PanSou 用户名 |
| `PANSOU_PWD` | `your_password` | PanSou 密码 |
### 1. API 返回 503 错误
- 检查 Vercel 环境变量是否已正确设置。
- 检查 `backend/api/index.py` 的日志输出。

### 2. 静态资源 404
- 确保 `frontend/vite.config.js` 中的 `outDir` 设置为 `dist`。
- 检查 `vercel.json` 中的 `routes` 配置是否与构建输出路径匹配。

### 3. 冷启动时间过长
- 我们已通过延迟导入和精简依赖优化了冷启动。
- 首次访问可能会有几秒延迟，后续访问将非常快。

### 方案一：GitHub 自动部署（推荐）
## 自定义域名
1. 在 Vercel 项目设置中点击 "Domains"。
2. 添加您的域名并按照提示配置 DNS 记录。
3. Vercel 会自动为您配置 HTTPS 证书。
# Vercel 无服务器部署指南

本文档介绍如何将 OpenMeta 部署到 Vercel 平台，实现自动构建、全球边缘网络和免费额度。

## 📋 目录

3. **配置项目设置**
   - **Framework Preset**: Other
   - **Root Directory**: 保持默认（仓库根目录）
   - **Build Command**: `npm run build --prefix frontend`
   - **Output Directory**: `frontend/dist`

4. **添加环境变量**
   - 进入 Project → Settings → Environment Variables
   - 添加 `PANSOU_HOST`, `PANSOU_USER`, `PANSOU_PWD`

5. **部署**
   - 点击 "Deploy" 开始部署
   - 等待构建完成，访问生成的 URL

### 方案二：Vercel CLI 部署

```bash
# 安装 Vercel CLI
npm install -g vercel

# 登录 Vercel
vercel login

# 部署（生产环境）
vercel deploy --prod
```

## 📁 项目结构

```
openmeta/
├── vercel.json              # Vercel 主配置
├── frontend/
│   ├── package.json         # 前端依赖和构建脚本
│   ├── vite.config.js       # Vite 构建配置
│   ├── index.html           # 前端入口
│   └── dist/                # 构建输出（Vercel 自动生成）
└── backend/
    ├── api/
    │   └── index.py         # Vercel Python 函数入口
    ├── app/
    │   ├── main.py          # FastAPI 主应用
    │   └── settings.py      # 环境变量配置
    └── requirements.txt     # Python 依赖
```

## 🔧 路由配置

| 路径 | 目标 | 说明 |
|------|------|------|
| `/` | `frontend/dist/index.html` | 前端页面 |
| `/api/*` | `backend/api/index.py` | Python API |
| `/health` | `backend/api/index.py` | 健康检查 |
| `/assets/*` | `frontend/dist/assets/*` | 静态资源 |

## 🌐 访问方式

部署成功后，您可以通过以下方式访问：

- **前端**: `https://your-app-name.vercel.app`
- **API**: `https://your-app-name.vercel.app/api/search?q=test`
- **健康检查**: `https://your-app-name.vercel.app/health`

## 🔒 自定义域名

1. 进入 Vercel Dashboard → Project → Settings → Domains
2. 添加您的自定义域名（如 `openmeta.example.com`）
3. 按提示在域名服务商处配置 DNS：
   - 类型: CNAME
   - 名称: www 或 @
   - 值: cname.vercel-dns.com
4. DNS 生效后，Vercel 自动签发 HTTPS 证书

### 自动部署（推荐）

每次推送到 GitHub 后，Vercel 会自动触发部署：

```bash
# 推送代码到 GitHub
git add .
git commit -m "feat: 更新代码"
git push origin main

# Vercel 会自动构建和部署
```

### 手动部署

```bash
# 使用 Vercel CLI 部署
vercel --prod

# 或者在 Vercel Dashboard 中点击 "Redeploy"
```

### 部署阶段

1. **构建阶段**
   - 安装 Python 依赖（`requirements.txt`）
   - 构建前端静态文件（`npm run build`）
   - 编译 Vercel 函数

2. **部署阶段**
   - 部署到 Vercel 边缘网络
   - 配置路由和函数
   - 启用 HTTPS

3. **验证阶段**
   - 检查健康检查端点
   - 验证 API 功能
   - 测试前端页面

## 🌐 域名和 HTTPS

### 使用 Vercel 默认域名

部署成功后，Vercel 会提供默认域名：

```
https://your-project-name.vercel.app
```

### 配置自定义域名

1. **在 Vercel Dashboard 中添加域名**

   - 进入项目设置
   - 点击 "Domains"
   - 输入你的域名（如 `openmeta.example.com`）
   - 点击 "Add"

2. **配置 DNS 记录**

   根据你的域名服务商，配置以下 DNS 记录：

   | 类型 | 名称 | 值 |
   |------|------|-----|
   | CNAME | @ | cname.vercel-dns.com |
   | CNAME | www | cname.vercel-dns.com |

3. **验证域名**

   - 等待 DNS 传播（通常 5-30 分钟）
   - Vercel 会自动签发 SSL 证书
   - 访问你的自定义域名

### 自动 HTTPS

- ✅ Vercel 自动为所有域名签发 Let's Encrypt SSL 证书
- ✅ 自动续期，无需手动配置
- ✅ 强制 HTTPS，提高安全性

## 🔍 常见问题排查

### 1. 部署失败

**问题**：构建过程中出现错误

**解决方案**：
```bash
# 检查 Vercel 部署日志
# 在 Dashboard 中查看详细的构建输出

# 常见问题：
# - 依赖包安装失败 → 检查 requirements.txt
# - 前端构建失败 → 检查 package.json 和 vite.config.js
# - 环境变量缺失 → 在 Dashboard 中配置环境变量
```

### 2. API 请求失败

**问题**：前端无法连接到后端 API

**解决方案**：
```bash
# 检查环境变量是否正确配置
# 在 Vercel Dashboard 中验证 PANSOU_HOST、PANSOU_USER、PANSOU_PWD

# 检查 API 路由配置
# vercel.json 中的 routes 配置应该正确指向 /api/* 路径

# 测试 API 健康检查
curl https://your-project.vercel.app/health
```

### 3. 静态资源 404

**问题**：前端页面加载失败或资源无法访问

**解决方案**：
```bash
# 检查前端构建产物
# 确认 frontend/dist 目录存在且包含 index.html

# 检查路由配置
# vercel.json 中的 routes 应该正确配置文件系统路由

# 重新部署
vercel --prod --force
```

### 4. 冷启动慢

**问题**：首次访问时响应时间过长

**解决方案**：
```bash
# Vercel 默认有冷启动，但以下优化可以减少冷启动时间：
# - 依赖包精简（已完成）
# - 延迟导入重型模块（已实现）
# - 保持函数活跃（使用 Pro 计划的 Warmup 功能）

# 测试冷启动时间
curl -w "@curl-format.txt" -o /dev/null -s https://your-project.vercel.app/health
```

### 5. CORS 错误

**问题**：浏览器控制台显示 CORS 错误
### 查看日志

```bash
# 实时日志
vercel logs --follow [项目名称]
```

### 性能监控

在 Vercel Dashboard 中查看：
- 函数执行时间
- 内存使用情况
- 错误率统计

## ❓ 常见问题排查

### 502/函数报错

- 确认 `PANSOU_HOST` 等环境变量已设置
- 进入 Dashboard → Functions 查看错误日志

### 前端页面可以打开，但 API 调用失败

- 检查请求路径是否为 `/api/search`
- 确认 vercel.json 中有 `/api/*` 路由规则
- 查看 Functions 日志确认函数是否被触发

### 冷启动时间过长

- 首次请求可能需要 2-3 秒（Serverless 正常行为）
- 后续请求会快很多（函数实例复用）

### 内存不足

- 检查是否有内存泄漏
- 考虑升级 memory 配置（vercel.json 中）
- [前置要求](#前置要求)
- [环境变量配置](#环境变量配置)
- [部署步骤](#部署步骤)
- [本地测试](#本地测试)
- [GitHub 自动部署](#github-自动部署)
- [自定义域名](#自定义域名)
- [故障排查](#故障排查)

## 前置要求

- [Vercel 账户](https://vercel.com/signup)（免费）
- [GitHub 账户](https://github.com/signup)
- 代码仓库已推送到 GitHub

## 环境变量配置

### 必需的环境变量

在 Vercel Dashboard 中配置以下环境变量：

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `PANSOU_HOST` | PanSou 服务器地址 | `https://pansou.example.com` |
| `PANSOU_USER` | PanSou 用户名 | `your_username` |
| `PANSOU_PWD` | PanSou 密码 | `your_password` |

### 可选的环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `SEARCH_TIMEOUT` | 搜索超时时间（秒） | `15` |
| `LOG_LEVEL` | 日志级别 | `INFO` |
| `CORS_ALLOW_ORIGINS` | CORS 允许的源 | `*` |

### 配置步骤

1. 访问 [Vercel Dashboard](https://vercel.com/dashboard)
2. 选择你的项目
3. 进入 **Settings** → **Environment Variables**
4. 添加以下环境变量：

```
PANSOU_HOST = https://your-pansou-server.com
PANSOU_USER = your_username
PANSOU_PWD = your_password
```

5. 选择应用范围：
   - **Production**: 生产环境
   - **Preview**: 预览环境（每个 Pull Request）
   - **Development**: 开发环境

6. 点击 **Save** 保存

## 部署步骤

### 方法一：通过 Vercel CLI 部署

1. 安装 Vercel CLI：
```bash
npm install -g vercel
```

2. 登录 Vercel：
```bash
vercel login
```

3. 在项目根目录运行：
```bash
vercel
```

4. 按照提示操作：
   - 设置项目名称
   - 选择部署范围（Production/Preview/Development）
   - 确认环境变量

5. 部署完成后，Vercel 会提供一个 URL，如：
```
https://openmeta-xxx.vercel.app
```

### 方法二：通过 GitHub 集成部署

1. 在 Vercel Dashboard 中点击 **Add New Project**
2. 选择 **Import Git Repository**
3. 选择你的 GitHub 仓库
4. 配置项目：
   - **Framework Preset**: Other
   - **Root Directory**: `./`（保持默认）
   - **Build Command**: 自动检测
   - **Output Directory**: 自动检测

5. 配置环境变量（见上文）
6. 点击 **Deploy**

## 本地测试

### v1.1.0 - Vercel 无服务器完整支持

- ✅ 修复 vercel.json 语法错误
- ✅ 统一路由配置（Python API + 前端）
- ✅ 优化冷启动性能
- ✅ GitHub 自动构建支持
- ✅ 完整部署文档

---

**部署愉快！** 🎉
### 安装 Vercel CLI

```bash
npm install -g vercel
```

### 启动本地开发服务器

```bash
# 在项目根目录
vercel dev
```

这将启动本地开发服务器：
- 前端：http://localhost:3000
- API：http://localhost:3000/api/*
- 健康检查：http://localhost:3000/health

### 测试健康检查

```bash
curl http://localhost:3000/health
```

预期返回：
```json
{
  "status": "ok",
  "service": "OpenMeta",
  "version": "1.0.0",
  "pansou_host": "https://your-pansou-server.com"
}
```

### 测试搜索功能

**解决方案**：
```bash
# 检查 CORS 配置
# backend/app/main.py 中的 CORSMiddleware 配置

# 确保允许的源包含你的域名
# 或者设置为 "*" 允许所有源（开发环境）
```

## ⚡ 性能优化

### 已实现的优化

1. **依赖包精简**
   - 只包含必需的依赖（5个核心包）
   - 减少冷启动时间

2. **延迟导入**
   -重型模块在首次使用时才导入
   - 减少内存占用

3. **Token 缓存**
   - PanSou Token 缓存 59 分钟
   - 减少认证请求

4. **连接池复用**
   - HTTP 连接池跨请求重用
   - 提高响应速度

### 监控和分析

```bash
# 使用 Vercel Analytics
# 在 Dashboard 中启用 Analytics 功能

# 查看性能指标
# - 访问量
# - 响应时间
# - 错误率
# - 地理分布
```

### 免费额度

Vercel 免费计划提供：

- ✅ 100GB 带宽/月
- ✅ 无限部署
- ✅ 100GB-Hours 执行时间/月
- ✅ 全球 CDN
- ✅ 自动 HTTPS
- ✅ 自定义域名

## 📊 部署验证清单

在部署完成后，使用以下清单验证部署是否成功：

- [ ] 访问主页返回 200 OK
  ```bash
  curl https://your-project.vercel.app/
  ```

- [ ] 健康检查端点正常
  ```bash
  curl https://your-project.vercel.app/health
  ```

- [ ] API 搜索功能正常
  ```bash
  curl "https://your-project.vercel.app/api/search?q=test&page=1"
  ```

- [ ] 前端页面加载正常
  - 在浏览器中访问主域名
  - 检查页面元素是否正确显示
  - 测试搜索功能

- [ ] 环境变量已配置
  - 检查 Vercel Dashboard
  - 确认所有必需变量已设置

- [ ] 自定义域名（如果配置）
  - DNS 记录正确
  - SSL 证书已签发
  - HTTP 重定向到 HTTPS

## 🔐 安全最佳实践

1. **环境变量安全**
   - ✅ 不在代码中硬编码敏感信息
   - ✅ 使用 Vercel Dashboard 配置环境变量
   - ✅ 定期更新密码和凭证

2. **API 访问控制**
   - ✅ 配置 CORS 限制允许的源
   - ✅ 生产环境使用适当的认证机制
   - ✅ 启用请求速率限制

3. **依赖管理**
   - ✅ 定期更新依赖包
   - ✅ 检查安全漏洞
   - ✅ 使用特定版本而非动态版本

## 📚 相关文档

- [Vercel 官方文档](https://vercel.com/docs)
- [Vercel Python 运行时](https://vercel.com/docs/concepts/functions/serverless-functions/runtimes/python)
- [项目 README](../README.md)
- [安全修复文档](../SECURITY-FIXES.md)

## 🆘 获取帮助

如果遇到问题：

1. 查看本文档的[常见问题排查](#常见问题排查)部分
2. 检查 [GitHub Issues](../../issues)
3. 查阅 [Vercel 支持文档](https://vercel.com/support)

---

**最后更新**: 2025-01-10
**维护者**: OpenMeta Team
curl "http://localhost:3000/api/search?q=测试&page=1"
```

## GitHub 自动部署

### 工作流程

1. 推送代码到 GitHub（默认分支，通常是 `main` 或 `master`）
2. Vercel 自动检测到新提交
3. 触发构建和部署流程
4. 构建日志显示在 Vercel Dashboard
5. 部署完成后，新版本自动上线

### Pull Request 自动预览

每次创建或更新 Pull Request 时，Vercel 会：
1. 自动创建一个预览部署
2. 提供预览 URL（如：`https://openmeta-git-feature-branch-xxx.vercel.app`）
3. 在 PR 页面显示部署状态和预览链接

### 手动触发部署

如果需要重新部署而不更改代码：

1. 访问 Vercel Dashboard
2. 选择项目
3. 进入 **Deployments** 标签
4. 找到之前的部署
5. 点击 **...** → **Redeploy**

## 自定义域名

### 添加自定义域名

1. 在 Vercel Dashboard 中进入项目设置
2. 选择 **Domains**
3. 输入你的域名（如：`openmeta.example.com`）
4. 点击 **Add**

### 配置 DNS

Vercel 会自动检测 DNS 配置并提供两种选项：

#### 选项 A：使用 Vercel DNS（推荐）

将域名服务器（NS）更改为 Vercel 提供的值：
```
nameserver1.vercel-dns.com
nameserver2.vercel-dns.com
```

#### 选项 B：使用 CNAME 记录

如果你希望使用现有 DNS 提供商，添加以下记录：

| 类型 | 名称 | 值 |
|------|------|-----|
| CNAME | `openmeta` | `cname.vercel-dns.com` |

### 自动 HTTPS

Vercel 会自动为你的自定义域名配置 SSL 证书（通过 Let's Encrypt），无需手动配置。

## 故障排查

### 问题 1：部署失败 - 找不到模块

**错误信息**：
```
ModuleNotFoundError: No module named 'mangum'
```

**解决方案**：
确保 `backend/requirements.txt` 包含所有必需的依赖：
```txt
fastapi
uvicorn
mangum
python-dotenv
```

### 问题 2：环境变量未配置

**错误信息**：
```
ValueError: Missing required environment variable: PANSOU_HOST
```

**解决方案**：
1. 检查 Vercel Dashboard 中的环境变量配置
2. 确保所有必需的变量都已添加
3. 重新部署项目

### 问题 3：API 请求失败

**症状**：
- 前端页面能加载
- 搜索功能报错

**解决方案**：
1. 检查 `frontend/vite.config.js` 中的代理配置
2. 确认 API 路由正确（`/api/search`）
3. 检查 Vercel 日志：Dashboard → Deployments → View Logs

### 问题 4：冷启动时间长

**症状**：
- 首次 API 请求需要 2-3 秒
- 后续请求很快

**说明**：
这是正常的 Vercel Serverless 行为。项目已优化：
- 延迟导入重型依赖
- Token 缓存（59 分钟）
- 连接池复用

**进一步优化**：
考虑升级到 Vercel Pro 计划以获得更长的函数执行时间。

### 问题 5：静态资源 404

**症状**：
- 页面能加载但样式或脚本丢失

**解决方案**：
1. 检查 `vercel.json` 中的 routes 配置
2. 确保 `frontend/dist` 目录正确构建
3. 清除 Vercel 缓存：`vercel --force`

## 部署前检查清单

在部署之前，确保完成以下检查：

- [ ] `vercel.json` 已正确配置
- [ ] 所有环境变量已在 Vercel Dashboard 中配置
- [ ] `backend/requirements.txt` 包含所有依赖
- [ ] `frontend/package.json` 包含正确的构建脚本
- [ ] `frontend/vite.config.js` 配置正确
- [ ] 本地测试通过（`vercel dev`）
- [ ] GitHub 仓库已连接到 Vercel
- [ ] 健康检查端点正常（`/health`）
- [ ] 搜索功能正常（`/api/search`）

## 性能优化建议

### 已实现的优化

1. **冷启动优化**
   - 延迟导入重型依赖
   - 减少启动时加载的模块

2. **Token 缓存**
   - PanSou Token 缓存 59 分钟
   - 减少重复登录请求

3. **并发控制**
   - 使用 asyncio.Lock 确保并发安全
   - Double-check locking 机制

4. **连接池复用**
   - HTTP 客户端连接池
   - 减少连接建立开销

### 进一步优化

1. **启用 Vercel Edge Functions**
   - 对于简单请求，考虑使用 Edge Functions（冷启动更快）

2. **使用 CDN**
   - Vercel 自动提供全球 CDN
   - 确保静态资源有合适的缓存策略

3. **监控和分析**
   - 使用 Vercel Analytics 监控性能
   - 配置错误追踪（如 Sentry）

## 相关文档

- [Vercel 官方文档](https://vercel.com/docs)
- [Vercel Python Runtime](https://vercel.com/docs/concepts/functions/serverless-functions/runtimes/python)
- [Mangum 文档](https://github.com/jordaneremieff/mangum)
- [Vite 部署指南](https://vitejs.dev/guide/build.html)

## 支持

如果遇到问题：

1. 查看 [GitHub Issues](https://github.com/your-org/openmeta/issues)
2. 检查 Vercel 部署日志
3. 参考 [故障排查](#故障排查) 部分

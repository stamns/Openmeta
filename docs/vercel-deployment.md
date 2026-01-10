# OpenMeta Vercel 部署指南

本指南将指导您如何将 OpenMeta 项目部署到 Vercel 平台。

## 部署准备

1. **GitHub 账号**: 确保项目已托管在 GitHub 上。
2. **Vercel 账号**: 访问 [vercel.com](https://vercel.com) 并关联您的 GitHub 账号。

## 部署步骤

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

### 1. API 返回 503 错误
- 检查 Vercel 环境变量是否已正确设置。
- 检查 `backend/api/index.py` 的日志输出。

### 2. 静态资源 404
- 确保 `frontend/vite.config.js` 中的 `outDir` 设置为 `dist`。
- 检查 `vercel.json` 中的 `routes` 配置是否与构建输出路径匹配。

### 3. 冷启动时间过长
- 我们已通过延迟导入和精简依赖优化了冷启动。
- 首次访问可能会有几秒延迟，后续访问将非常快。

## 自定义域名
1. 在 Vercel 项目设置中点击 "Domains"。
2. 添加您的域名并按照提示配置 DNS 记录。
3. Vercel 会自动为您配置 HTTPS 证书。
# Vercel 无服务器部署指南

本文档介绍如何将 OpenMeta 部署到 Vercel 平台，实现自动构建、全球边缘网络和免费额度。

## 📋 目录

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

```bash
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

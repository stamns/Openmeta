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

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

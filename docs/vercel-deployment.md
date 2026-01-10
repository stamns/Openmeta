# OpenMeta Vercel 无服务器部署指南

本指南将帮助您将 OpenMeta 部署到 Vercel 平台，实现 GitHub 自动构建、全球边缘网络和免费额度。

## 🚀 部署特性

- **GitHub 自动构建**: 每次 push 自动触发部署
- **全球边缘网络**: Vercel 自动配置 CDN 和 HTTPS
- **免费额度**: 适合个人/小流量站点
- **三层部署**: 同时支持本地开发、Docker 和 Vercel 无服务器

## 📋 部署前准备

### 必要条件

- Vercel 账号 ([注册地址](https://vercel.com/signup))
- GitHub 仓库
- PanSou 搜索服务凭证

### 环境变量配置

在 Vercel Dashboard 中设置以下环境变量：

| 变量名 | 示例值 | 说明 |
|--------|--------|------|
| `PANSOU_HOST` | `http://112.124.53.114:8888` | PanSou 服务器地址 |
| `PANSOU_USER` | `admin` | PanSou 用户名 |
| `PANSOU_PWD` | `your_password` | PanSou 密码 |

## 🛠️ 部署步骤

### 方案一：GitHub 自动部署（推荐）

1. **推送代码到 GitHub**
   ```bash
   git add .
   git commit -m "feat: 添加 Vercel 无服务器部署支持"
   git push origin main
   ```

2. **连接 GitHub 到 Vercel**
   - 登录 [Vercel Dashboard](https://vercel.com/dashboard)
   - 点击 "New Project"
   - 选择 "Import Git Repository"
   - 授权 GitHub 访问并选择您的仓库

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

## 📊 监控和维护

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

## 📝 更新日志

### v1.1.0 - Vercel 无服务器完整支持

- ✅ 修复 vercel.json 语法错误
- ✅ 统一路由配置（Python API + 前端）
- ✅ 优化冷启动性能
- ✅ GitHub 自动构建支持
- ✅ 完整部署文档

---

**部署愉快！** 🎉

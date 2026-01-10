# OpenMeta Vercel 无服务器部署指南

本指南将帮助您将 OpenMeta 部署到 Vercel 平台，实现本地、Docker、Vercel 三层部署支持。

## 🚀 部署特性

- **三层部署**: 同时支持本地开发、Docker 容器化和 Vercel 无服务器部署
- **全球加速**: 自动获得 HTTPS、CDN、全球边缘节点加速
- **冷启动优化**: 针对无服务器环境的性能优化
- **环境隔离**: 开发、预览、生产环境独立配置
- **GitHub 自动部署**: 推送代码自动触发 Vercel 构建

## 📋 部署前准备

### 1. 必要条件

- Vercel 账号 ([注册地址](https://vercel.com/signup))
- GitHub 仓库 (用于自动部署)
- PanSou 搜索服务地址
- Node.js (用于前端构建)
- Python 3.7+ (用于后端)

### 2. 环境变量配置

#### 本地开发环境

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑配置文件
vim .env
```

#### Vercel 环境变量设置

在 Vercel Dashboard 中设置以下环境变量：

1. 登录 [Vercel Dashboard](https://vercel.com/dashboard)
2. 选择您的 OpenMeta 项目
3. 进入 `Settings` > `Environment Variables`
4. 添加以下变量：

| 变量名 | 示例值 | 说明 |
|--------|--------|------|
| `PANSOU_HOST` | `http://112.124.53.114:8888` | PanSou 服务器地址 |
| `PANSOU_USER` | `admin` | PanSou 用户名（可选） |
| `PANSOU_PWD` | `your_password` | PanSou 密码（可选） |

**注意**: 所有环境变量都必须通过 Vercel Dashboard 配置，不能硬编码在代码中。

## 🛠️ 部署步骤

### 方案一：通过 GitHub 集成部署（推荐）

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
   - **Build Command**: `npm install && npm run build`（在 frontend 目录）
   - **Output Directory**: `frontend/dist`

4. **添加环境变量**
   - 在项目设置中添加 PanSou 相关环境变量
   - 确保在 Production、Preview 和 Development 环境中都配置了相同的变量

5. **部署**
   - 点击 "Deploy" 开始部署
   - Vercel 会自动检测 vercel.json 配置并构建前后端

6. **验证部署**
   - 部署完成后，访问生成的 URL（如 `https://openmeta-xxx.vercel.app`）
   - 测试前端页面是否能正常加载
   - 测试 API 端点 `/api/search` 是否返回正确结果
   - 测试健康检查端点 `/health` 是否返回 200 OK

### 方案二：Vercel CLI 部署

1. **安装 Vercel CLI**
   ```bash
   npm install -g vercel
   ```

2. **登录 Vercel**
   ```bash
   vercel login
   ```

3. **部署**
   ```bash
   cd backend
   vercel
   ```

4. **设置环境变量**
   ```bash
   vercel env add PANSOU_HOST
   vercel env add PANSOU_USER
   vercel env add PANSOU_PWD
   ```

### 方案三：本地开发测试

1. **安装依赖**
   ```bash
   # 后端依赖
   cd backend
   pip install -r requirements.txt
   
   # 前端依赖
   cd ../frontend
   npm install
   ```

2. **配置环境变量**
   ```bash
   # 复制环境变量模板
   cp ../.env.example .env
   # 编辑 .env 填入实际值
   ```

3. **启动服务**
   ```bash
   # 后端服务
   uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
   
   # 前端服务
   npm run dev
   ```

4. **本地测试 Vercel 配置**
   ```bash
   # 安装 Vercel CLI
   npm install -g vercel

   # 在项目根目录下测试
   vercel dev
   
   # 验证部署
   curl 'http://localhost:3000/api/search?q=test'
   curl 'http://localhost:3000/health'
   ```

5. **验证 vercel.json 配置**
   ```bash
   # 使用部署脚本验证配置
   ./scripts/deploy-vercel.sh
   ```

## 🔧 高级配置

### Vercel.json 配置详解

最新的 vercel.json 配置结构：

```json
{
  "version": 2,
  "builds": [
    {
      "src": "backend/api/index.py",
      "use": "@vercel/python"
    },
    {
      "src": "frontend/package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "dist"
      }
    }
  ],
  "routes": [
    { "src": "/api/(.*)", "dest": "backend/api/index.py" },
    { "src": "/health", "dest": "backend/api/index.py" },
    { "handle": "filesystem" },
    { "src": "/(.*)", "dest": "/index.html" }
  ],
  "env": {
    "PANSOU_HOST": "@pansou_host",
    "PANSOU_USER": "@pansou_user",
    "PANSOU_PWD": "@pansou_pwd"
  },
  "functions": {
    "backend/api/index.py": {
      "maxDuration": 10,
      "memory": 512
    }
  }
}
```

**关键配置说明**：

- **builds**: 定义了后端 Python 函数和前端静态构建
- **routes**: 定义了 API 路由、健康检查和前端路由
- **env**: 环境变量映射，使用 Vercel Secrets
- **functions**: 后端函数的内存和超时配置

### 性能优化

1. **冷启动优化**
   - 使用延迟导入减少启动时间
   - HTTP 连接池缓存
   - 环境变量预加载
   - 后端使用 `backend.app.main` 延迟导入

2. **内存和超时配置**
   ```json
   {
     "functions": {
       "backend/api/index.py": {
         "maxDuration": 10,
         "memory": 512
       }
     }
   }
   ```

3. **区域配置**
   ```json
   {
     "regions": ["hkg1", "sin1"]
   }
   ```

### 前端构建优化

Vite 配置（frontend/vite.config.js）：

```javascript
build: {
  outDir: 'dist',
  emptyOutDir: true,
  rollupOptions: {
    input: {
      main: fileURLToPath(new URL('index.html', import.meta.url))
    }
  }
}
```

确保前端构建输出到 `dist` 目录，与 vercel.json 中的配置一致。

### 自定义域名

1. **添加域名**
   - 在 Vercel Dashboard 中进入项目设置
   - 点击 "Domains" 标签
   - 添加您的自定义域名

2. **DNS 配置**
   ```
   类型: CNAME
   名称: www
   值: cname.vercel-dns.com
   ```

### 自动部署配置

Git 推送时自动触发部署：
- **main 分支** → 生产环境
- **preview 分支** → 预览环境  
- **feature 分支** → 开发环境

## 📊 监控和维护

### 部署验证检查表

部署完成后，请按照以下检查表验证部署是否成功：

```bash
# 1. 验证 vercel.json 语法
python3 -c "import json; json.loads(open('vercel.json').read())"

# 2. 验证前端构建
cd frontend && npm run build

# 3. 验证后端导入
cd backend && python3 -c "from api.index import app; print('Backend import successful')"

# 4. 本地测试
vercel dev

# 5. 测试 API 端点
curl -v http://localhost:3000/api/search?q=test

# 6. 测试健康检查
curl -v http://localhost:3000/health

# 7. 测试前端页面
open http://localhost:3000
```

**验收标准**：
- ✅ vercel.json 通过 JSON 验证（无语法错误）
- ✅ 本地测试：vercel dev 能正常运行前端和后端
- ✅ GitHub 推送后自动触发 Vercel 部署
- ✅ 部署成功显示生成的 URL（如 openmeta-xxx.vercel.app）
- ✅ 访问前端页面（/）能正常加载和显示
- ✅ 搜索功能正常（/api/search 正常返回）
- ✅ /health 端点返回 200 OK
- ✅ 冷启动时间 <3 秒
- ✅ 前后端路由都能正确访问，无 404 或跨域错误

### 1. 日志查看

```bash
# 查看函数日志
vercel logs [项目名称]

# 实时日志
vercel logs [项目名称] --follow
```

### 2. 性能监控

- 在 Vercel Dashboard 中查看：
  - 函数执行时间
  - 内存使用情况
  - 错误率统计

### 3. 常见问题排查

#### 冷启动时间过长
- 检查导入的依赖数量
- 考虑使用更轻量级的替代方案
- 启用函数连接（需要付费计划）

#### 内存不足
- 优化算法复杂度
- 减少内存中的缓存
- 考虑升级到更大的内存配置

#### 搜索无响应
- 检查 PanSou 服务状态
- 验证环境变量配置
- 查看函数日志获取错误详情

#### 404 错误
- 检查 vercel.json 中的 routes 配置
- 确保所有路由都正确映射
- 验证静态资源路径配置

#### CORS 错误
- 检查后端 CORS 配置
- 确保前端请求使用相对路径（/api/search 而不是完整 URL）

## 🎯 访问方式

部署成功后，您可以通过以下方式访问：

### 生产环境
- **前端**: `https://your-app-name.vercel.app`
- **API**: `https://your-app-name.vercel.app/api/search`
- **文档**: `https://your-app-name.vercel.app/docs`

### 开发环境
- **本地**: `http://localhost:8000`
- **Vercel Dev**: `http://localhost:3000`

## 🔄 三层部署对比

| 特性 | 本地开发 | Docker | Vercel |
|------|----------|---------|---------|
| 部署速度 | 快速 | 中等 | 快速 |
| 运维复杂度 | 低 | 中等 | 极低 |
| 全球加速 | ❌ | ❌ | ✅ |
| 自动扩展 | ❌ | 手动 | ✅ |
| 成本 | 开发为主 | 服务器成本 | 按使用计费 |
| 冷启动 | 无 | 无 | 有 |
| 文件系统 | 读写 | 读写 | 只读 |

## 📝 更新日志

### v1.0.0 - Vercel 无服务器支持
- ✅ 添加 Vercel 配置文件
- ✅ 优化冷启动性能
- ✅ 环境变量自动映射
- ✅ 三层部署支持
- ✅ 完整部署文档

## 🤝 技术支持

如有问题，请检查：

1. **环境变量**是否正确配置
2. **PanSou 服务**是否可访问
3. **函数日志**中的错误信息
4. **网络连接**是否正常

---

**部署愉快！** 🎉
# Vercel 无服务器部署指南（OpenMeta）

## 1. 连接 GitHub → Vercel

1. 在 Vercel Dashboard 点击 **Add New Project**
2. 选择 GitHub 仓库并导入
3. 推荐配置：Project Settings → **Root Directory** 选择 `backend`
   - 这样 Vercel 会自动使用 `backend/vercel.json`
   - 静态资源使用 `backend/public/`（Vercel 默认会把 `public/` 暴露为站点根路径）
4. 点击 Deploy

如果你不想设置 Root Directory，也可以使用 repo root 的 `vercel.json`（路径已写死到 `backend/`）。

## 2. 路由与访问方式

- 前端：`https://<your>.vercel.app/`
- API：`https://<your>.vercel.app/api/search?q=xxx`

`vercel.json` 中的规则：

- `/api/*` → 转发到 `api/index.py`（Vercel Function）
- 其它路径 → 优先走静态文件（filesystem），不存在则回退到 `index.html`（SPA）

## 3. 环境变量配置

### 3.1 在 Vercel Dashboard 设置

进入 Project → Settings → Environment Variables：

- `PANSOU_HOST`
- `PANSOU_USER`
- `PANSOU_PWD`

按需分别设置到 Production / Preview / Development。

### 3.2 vercel.json 中的映射

在 `backend/vercel.json` / `vercel.json` 中默认写法为：

- `PANSOU_HOST`: `@pansou_host`
- `PANSOU_USER`: `@pansou_user`
- `PANSOU_PWD`: `@pansou_pwd`

这表示你可以用 Vercel Secrets：

```bash
vercel secrets add pansou_host 'https://example.com'
vercel secrets add pansou_user 'user'
vercel secrets add pansou_pwd  'pwd'
```

或者直接在 Dashboard 里配置变量（按团队规范选择）。

### 3.3 本地 vercel dev 使用 .env.local

在 `backend/` 目录创建 `.env.local`（不要提交到 git）：

```env
PANSOU_HOST=...
PANSOU_USER=...
PANSOU_PWD=...
```

Vercel CLI 会自动加载。

## 4. vercel dev 本地测试

```bash
cd backend
vercel dev

# 验证
curl 'http://localhost:3000/api/search?q=test'
```

同时打开 `http://localhost:3000/` 检查前端是否能正确调用 `/api/search`。

## 5. 依赖与包体积（Serverless 友好）

后端依赖位于 `backend/requirements.txt`，保持精简：

- `fastapi`
- `uvicorn`（本地/Docker）
- `mangum`（Lambda/Vercel → ASGI 映射）
- `httpx`（与 PanSou 通信）

总包体积远低于 Vercel 限制（通常 250MB）。

## 6. 冷启动优化

已做：

- `httpx` 在首次请求时才导入并创建连接池（延迟初始化）
- 连接池在实例复用期间可复用

建议：

- 避免在 import 顶层执行网络请求
- 把可选模块放到路由内部再 import
- 外部请求设置短超时，并提供 fallback 返回

## 7. 文件系统注意事项（Vercel 只读）

- 不要写入本地文件（日志文件、cache 文件等）
- 日志使用 stdout/stderr（`logging` 默认输出即可）
- 缓存使用内存或外部服务（如 Redis / Vercel KV）

## 8. 自动部署与环境区分

- 每次 push 到连接分支会触发自动构建部署
- Preview：PR/分支预览环境
- Production：主分支/指定分支

建议为 Preview/Production 设置不同的 PanSou 环境变量。

### 8.1 域名绑定（Custom Domain）

1. Vercel Dashboard → Project → Settings → Domains
2. 添加你的域名（例如 `openmeta.example.com`）
3. 按提示在域名服务商处配置 CNAME/A 记录
4. DNS 生效后，Vercel 会自动签发/续期 HTTPS 证书

## 9. 测试与验证

- 验证 `GET /api/search?q=test` 是否返回 JSON
- 验证前端页面是否能调用 `/api/search`
- 观察首次请求（冷启动）耗时与后续请求耗时

## 10. 故障排查指南

### 10.1 502/函数报错

- Vercel Dashboard → Project → Functions → 查看日志
- 确认 `PANSOU_HOST` 等环境变量已设置
- 连接 PanSou 超时会返回 `source=fallback` 并携带 `error`

### 10.2 前端页面可以打开，但 API 调用失败

- 检查请求路径是否为同域 `/api/search`
- 检查 `vercel.json` 是否存在 `/api/*` rewrite
- 进入 Logs 查看 Function 是否被触发

### 10.3 查看 Vercel 日志

- Dashboard → Project → Functions → 选择函数 → Logs

### 10.4 性能监控与优化

- 观察冷启动耗时（首次请求）与后续请求耗时
- 适当降低外部请求超时
- 如果依赖外部缓存/数据库，优先选择低延迟的同区域服务

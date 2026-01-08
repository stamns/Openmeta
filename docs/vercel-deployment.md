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

# OpenMeta Vercel 无服务器部署指南

本指南将帮助您将 OpenMeta 部署到 Vercel 平台，实现本地、Docker、Vercel 三层部署支持。

## 🚀 部署特性

- **三层部署**: 同时支持本地开发、Docker 容器化和 Vercel 无服务器部署
- **全球加速**: 自动获得 HTTPS、CDN、全球边缘节点加速
- **冷启动优化**: 针对无服务器环境的性能优化
- **环境隔离**: 开发、预览、生产环境独立配置

## 📋 部署前准备

### 1. 必要条件

- Vercel 账号 ([注册地址](https://vercel.com/signup))
- GitHub 仓库 (或使用 Vercel 直接上传)
- PanSou 搜索服务地址

### 2. 环境变量配置

#### 本地开发环境

```bash
# 复制环境变量模板
cp backend/.env.local.example backend/.env.local

# 编辑配置文件
vim backend/.env.local
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
   - **Root Directory**: `backend`
   - **Build Command**: `echo "No build needed"`
   - **Output Directory**: `echo "Static files"`

4. **添加环境变量**
   - 在项目设置中添加 PanSou 相关环境变量

5. **部署**
   - 点击 "Deploy" 开始部署

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
   cd backend
   pip install -r requirements.txt
   ```

2. **配置环境变量**
   ```bash
   cp .env.local.example .env.local
   # 编辑 .env.local 填入实际值
   ```

3. **启动服务**
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

4. **本地测试 Vercel 配置**
   ```bash
   # 安装 Vercel CLI
   npm install -g vercel

   # 在 backend 目录下测试
   cd backend
   vercel dev
   ```

## 🔧 高级配置

### 性能优化

1. **冷启动优化**
   - 使用延迟导入减少启动时间
   - HTTP 连接池缓存
   - 环境变量预加载

2. **内存和超时配置**
   ```json
   {
     "functions": {
       "api/index.py": {
         "maxDuration": 30,
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
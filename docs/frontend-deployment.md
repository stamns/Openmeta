# 前端部署优化指南

本文档详细说明了 OpenMeta 前端的部署配置和优化策略。

## 📁 目录结构

```
frontend/
├── index.html          # 主 HTML 文件
├── package.json        # NPM 依赖配置
├── vite.config.js      # Vite 构建配置
├── src/                # 源代码目录
│   └── (源代码文件)
└── dist/               # 构建输出目录（自动生成）
    ├── index.html      # 构建后的 HTML
    └── assets/         # 构建后的静态资源
```

## 🔧 构建配置

### package.json

```json
{
  "name": "openmeta-frontend",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0 --port 5173",
    "build": "vite build",
    "preview": "vite preview --host 0.0.0.0 --port 4173"
  },
  "dependencies": {
    "vue": "^3.4.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^5.0.0",
    "vite": "^5.0.0"
  }
}
```

### 脚本说明

| 脚本 | 用途 |
|------|------|
| `npm run dev` | 启动开发服务器（热重载） |
| `npm run build` | 构建生产版本 |
| `npm run preview` | 预览生产构建 |

### vite.config.js

```javascript
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const backend = env.VITE_BACKEND_URL || 'http://127.0.0.1:8000'

  return {
    plugins: [vue()],
    resolve: {
      alias: {
        '@': resolve(__dirname, 'src')
      }
    },
    build: {
      outDir: 'dist',
      assetsDir: 'assets',
      sourcemap: mode === 'development',
      rollupOptions: {
        output: {
          manualChunks: {
            'vendor': ['vue']
          }
        }
      }
    },
    server: {
      host: '0.0.0.0',
      port: 5173,
      proxy: {
        '/api': backend,
        '/health': backend
      }
    },
    preview: {
      host: '0.0.0.0',
      port: 4173
    }
  }
})
```

## 🚀 部署流程

### 本地开发

```bash
# 进入前端目录
cd frontend

# 安装依赖
npm install

# 启动开发服务器
npm run dev
```

访问 http://localhost:5173

### 生产构建

```bash
# 构建生产版本
npm run build

# 预览构建结果
npm run preview
```

构建产物位于 `frontend/dist/` 目录：

```
dist/
├── index.html      # 主 HTML 文件
└── assets/
    ├── index-[hash].js      # JavaScript 包
    ├── index-[hash].css     # CSS 样式
    └── vendor-[hash].js     # Vendor 库（Vue 等）
```

### Vercel 部署

Vercel 会自动执行以下步骤：

1. **安装依赖**：`npm install`
2. **构建前端**：`npm run build`
3. **部署静态文件**：将 `dist/` 目录部署到 CDN

## ⚡ 性能优化

### 1. 代码分割

```javascript
rollupOptions: {
  output: {
    manualChunks: {
      'vendor': ['vue']
    }
  }
}
```

**效果**：
- 将 Vue 等第三方库单独打包
- 利用浏览器缓存
- 减少主包大小

### 2. 资源压缩

Vite 默认启用：

- JavaScript 压缩（Terser）
- CSS 压缩
- HTML 压缩
- 图片优化（如有）

### 3. Source Maps

```javascript
build: {
  sourcemap: mode === 'development'
}
```

- 开发环境：启用 source maps 便于调试
- 生产环境：禁用 source maps 减少体积

### 4. 路径别名

```javascript
resolve: {
  alias: {
    '@': resolve(__dirname, 'src')
  }
}
```

**使用方式**：
```javascript
// 代替
import MyComponent from '../../../components/MyComponent.vue'

// 使用
import MyComponent from '@/components/MyComponent.vue'
```

## 🔌 API 代理配置

### 开发环境代理

```javascript
server: {
  proxy: {
    '/api': 'http://127.0.0.1:8000',
    '/health': 'http://127.0.0.1:8000'
  }
}
```

**效果**：
- 前端请求 `/api/*` 自动代理到后端
- 避免 CORS 问题
- 便于本地开发

### 生产环境请求

在 Vercel 上部署后，API 请求通过 `vercel.json` 路由配置：

```json
{
  "routes": [
    { "src": "/api/(.*)", "dest": "/backend/api/index.py" },
    { "src": "/health", "dest": "/backend/api/index.py" }
  ]
}
```

前端无需修改代码，直接请求相对路径：

```javascript
// 前端代码
fetch('/api/search?q=test&page=1')
  .then(response => response.json())
  .then(data => console.log(data))
```

## 🌐 环境变量

### 开发环境

创建 `.env.local` 文件：

```bash
# .env.local
VITE_BACKEND_URL=http://127.0.0.1:8000
```

### 生产环境

Vercel 通过 `vercel.json` 路由配置处理 API 请求，无需额外环境变量。

## 📊 构建产物分析

### 查看构建大小

```bash
# 使用 vite-plugin-visualizer
npm install --save-dev rollup-plugin-visualizer

# 在 vite.config.js 中添加
import { visualizer } from 'rollup-plugin-visualizer'

export default {
  plugins: [
    vue(),
    visualizer({ open: true })
  ]
}

# 构建后自动打开可视化报告
npm run build
```

### 典型构建产物大小

```
dist/assets/
├── index-[hash].js       ~10-20 KB (gzip)
├── vendor-[hash].js      ~40-60 KB (gzip)
└── index-[hash].css      ~1-5 KB (gzip)
```

## 🔍 故障排查

### 1. 构建失败

**问题**：`npm run build` 失败

**解决方案**：
```bash
# 清除缓存
rm -rf node_modules dist package-lock.json
npm install
npm run build
```

### 2. API 请求失败

**问题**：前端无法连接后端 API

**解决方案**：
- 检查 `vercel.json` 路由配置
- 确认后端函数正常部署
- 查看 Vercel 部署日志

### 3. 静态资源 404

**问题**：CSS、JS 文件无法加载

**解决方案**：
- 确认 `dist/` 目录包含所有文件
- 检查 `vite.config.js` 中的 `base` 配置
- 验证 `vercel.json` 路由配置

### 4. 样式丢失

**问题**：页面样式不正确

**解决方案**：
- 检查 CSS 文件是否正确导入
- 确认构建产物包含 CSS 文件
- 使用浏览器开发者工具检查资源加载

## 📚 最佳实践

### 1. 依赖管理

- 定期更新依赖包
- 使用固定版本（避免动态版本）
- 定期清理未使用的依赖

### 2. 代码质量

- 使用 ESLint 和 Prettier
- 编写单元测试
- 代码审查

### 3. 性能监控

- 使用 Vercel Analytics
- 监控 Core Web Vitals
- 优化加载速度

### 4. 安全性

- 启用 CSP (Content Security Policy)
- 使用 HTTPS
- 定期检查安全漏洞

## 🔗 相关文档

- [Vite 官方文档](https://vitejs.dev/)
- [Vercel 静态部署](https://vercel.com/docs/concepts/deployments/overview)
- [Vue 3 文档](https://vuejs.org/)
- [Vercel 部署指南](./vercel-deployment.md)

---

**最后更新**: 2025-01-10
**维护者**: OpenMeta Team

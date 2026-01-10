import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const backend = env.VITE_BACKEND_URL || 'http://127.0.0.1:8000'

  return {
    plugins: [vue()],
    base: '/',  // 部署到根路径
    build: {
      outDir: 'dist',
      assetsDir: 'assets',
      sourcemap: mode === 'development'
    },
    server: {
      host: '0.0.0.0',
      port: 5173,
      proxy: {
        '/api': backend,
        '/health': backend
      }
    }
  }
})

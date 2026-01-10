import { createApp } from 'vue'
import App from './App.vue'

const app = createApp(App)

app.config.errorHandler = (err, instance, info) => {
  console.error('Global Error:', err)
  console.log('Error Info:', info)
  // 这里也可以选择上报错误到服务器
}

app.mount('#app')


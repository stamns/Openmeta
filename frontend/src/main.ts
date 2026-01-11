import { createApp } from 'vue'
import App from './App.vue'
import '@/styles/variables.css'
import '@/styles/responsive.css'

const app = createApp(App)

app.config.errorHandler = (err, instance, info) => {
  console.error('Global Error:', err)
  console.log('Error Info:', info)
}

app.mount('#app')

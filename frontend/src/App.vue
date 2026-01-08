<template>
  <main class="wrap">
    <header class="header">
      <h1>OpenMeta</h1>
      <p class="sub">网盘聚合搜索引擎（FastAPI + PanSou + Vue3）</p>
    </header>

    <section class="search">
      <input
        v-model="q"
        class="input"
        placeholder="输入关键词，例如：三体 / 电影 / PDF"
        @keydown.enter="doSearch"
      />
      <button class="btn" :disabled="loading || !q.trim()" @click="doSearch">
        {{ loading ? '搜索中…' : '搜索' }}
      </button>
    </section>

    <section v-if="error" class="error">
      {{ error }}
    </section>

    <section v-if="result" class="result">
      <div class="meta">
        <span>耗时：{{ durationMs }}ms</span>
        <span v-if="result.warning" class="warn">{{ result.warning }}</span>
      </div>

      <ul v-if="items.length" class="list">
        <li v-for="(item, idx) in items" :key="idx" class="item">
          <div class="title">{{ item.title || item.name || item.filename || '未命名资源' }}</div>
          <div class="desc">
            <a v-if="item.url" :href="item.url" target="_blank" rel="noreferrer">打开链接</a>
            <span v-else class="muted">无链接字段</span>
          </div>
        </li>
      </ul>

      <details v-else class="raw">
        <summary>无可展示列表字段，查看原始返回</summary>
        <pre>{{ JSON.stringify(result, null, 2) }}</pre>
      </details>
    </section>

    <footer class="footer">
      <a href="/health" target="_blank" rel="noreferrer">健康检查</a>
      <span class="sep">·</span>
      <a href="https://vercel.com" target="_blank" rel="noreferrer">Vercel</a>
    </footer>
  </main>
</template>

<script setup>
import { computed, ref } from 'vue'

const q = ref('')
const loading = ref(false)
const error = ref('')
const result = ref(null)
const durationMs = ref(0)

const items = computed(() => {
  const r = result.value
  if (!r) return []
  if (Array.isArray(r.items)) return r.items
  if (Array.isArray(r.data)) return r.data
  if (Array.isArray(r.results)) return r.results
  return []
})

async function doSearch() {
  error.value = ''
  loading.value = true
  result.value = null

  const started = performance.now()
  try {
    const resp = await fetch(`/api/search?q=${encodeURIComponent(q.value)}`)
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`)
    result.value = await resp.json()
  } catch (e) {
    error.value = e?.message || String(e)
  } finally {
    durationMs.value = Math.round(performance.now() - started)
    loading.value = false
  }
}
</script>

<style scoped>
.wrap {
  max-width: 900px;
  margin: 0 auto;
  padding: 32px 16px;
  font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial,
    "Apple Color Emoji", "Segoe UI Emoji";
}

.header h1 {
  margin: 0;
  font-size: 32px;
}

.sub {
  margin-top: 6px;
  color: #6b7280;
}

.search {
  display: flex;
  gap: 10px;
  margin-top: 18px;
}

.input {
  flex: 1;
  padding: 10px 12px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  outline: none;
}

.btn {
  padding: 10px 14px;
  border: none;
  border-radius: 8px;
  background: #111827;
  color: white;
  cursor: pointer;
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error {
  margin-top: 14px;
  padding: 10px 12px;
  border-radius: 8px;
  background: #fef2f2;
  color: #991b1b;
  border: 1px solid #fecaca;
}

.result {
  margin-top: 18px;
}

.meta {
  display: flex;
  gap: 12px;
  color: #6b7280;
  font-size: 14px;
  margin-bottom: 10px;
}

.warn {
  color: #b45309;
}

.list {
  list-style: none;
  padding: 0;
  margin: 0;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  overflow: hidden;
}

.item {
  padding: 12px 14px;
  border-top: 1px solid #e5e7eb;
}

.item:first-child {
  border-top: none;
}

.title {
  font-weight: 600;
}

.desc {
  margin-top: 6px;
  color: #374151;
  font-size: 14px;
}

.muted {
  color: #9ca3af;
}

.raw {
  margin-top: 10px;
}

pre {
  background: #111827;
  color: #e5e7eb;
  padding: 12px;
  border-radius: 10px;
  overflow: auto;
}

.footer {
  margin-top: 30px;
  color: #6b7280;
  font-size: 14px;
}

.footer a {
  color: inherit;
}

.sep {
  margin: 0 8px;
}
</style>

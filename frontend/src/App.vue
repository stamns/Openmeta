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
        :disabled="loading"
      />
      <button class="btn" :disabled="loading || !q.trim()" @click="doSearch">
        <span v-if="loading" class="spinner"></span>
        {{ loading ? '搜索中…' : '搜索' }}
      </button>
    </section>

    <!-- 错误提示组件 -->
    <ErrorMessage 
      :error="error" 
      @retry="doSearch" 
      @clear="clearError"
    />

    <section v-if="result && !error" class="result">
      <div class="meta">
        <span>耗时：{{ durationMs }}ms</span>
        <span v-if="result.warning" class="warn">⚠️ {{ result.warning }}</span>
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

    <div v-if="!loading && !error && searched && items.length === 0" class="empty">
      未找到相关资源，请尝试其他关键词
    </div>

    <footer class="footer">
      <a href="/health" target="_blank" rel="noreferrer">健康检查</a>
      <span class="sep">·</span>
      <a href="https://vercel.com" target="_blank" rel="noreferrer">Vercel</a>
      <span class="sep">·</span>
      <span :class="isOffline ? 'offline' : 'online'">
        {{ isOffline ? '离线 (Offline)' : '在线 (Online)' }}
      </span>
    </footer>
  </main>
</template>

<script setup lang="ts">
import { computed, ref, onMounted, onUnmounted } from 'vue';
import { search, SearchItem, SearchResponse } from '@/api/search';
import { useErrorHandler } from '@/hooks/useErrorHandler';
import ErrorMessage from '@/components/ErrorMessage.vue';

const q = ref('');
const loading = ref(false);
const searched = ref(false);
const result = ref<SearchResponse | null>(null);
const durationMs = ref(0);
const isOffline = ref(!window.navigator.onLine);

const { error, handleError, clearError } = useErrorHandler();

const items = computed<SearchItem[]>(() => {
  const r = result.value;
  if (!r) return [];
  return r.items || [];
});

async function doSearch() {
  if (!q.value.trim()) return;
  
  clearError();
  loading.value = true;
  searched.value = true;
  result.value = null;

  const started = performance.now();
  try {
    result.value = await search(q.value);
  } catch (e) {
    handleError(e);
  } finally {
    durationMs.value = Math.round(performance.now() - started);
    loading.value = false;
  }
}

function updateOnlineStatus() {
  isOffline.value = !window.navigator.onLine;
}

onMounted(() => {
  window.addEventListener('online', updateOnlineStatus);
  window.addEventListener('offline', updateOnlineStatus);
});

onUnmounted(() => {
  window.removeEventListener('online', updateOnlineStatus);
  window.removeEventListener('offline', updateOnlineStatus);
});
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
  color: #4f46e5;
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
  padding: 12px 16px;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  outline: none;
  transition: border-color 0.2s;
}

.input:focus {
  border-color: #4f46e5;
  box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
}

.btn {
  padding: 10px 20px;
  border: none;
  border-radius: 12px;
  background: #4f46e5;
  color: white;
  cursor: pointer;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 8px;
  transition: background 0.2s;
}

.btn:hover:not(:disabled) {
  background: #4338ca;
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top: 2px solid white;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
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
  align-items: center;
}

.warn {
  color: #b45309;
  background: #fffbeb;
  padding: 2px 8px;
  border-radius: 4px;
}

.list {
  list-style: none;
  padding: 0;
  margin: 0;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  overflow: hidden;
  background: white;
}

.item {
  padding: 16px;
  border-top: 1px solid #e5e7eb;
  transition: background 0.2s;
}

.item:hover {
  background: #f9fafb;
}

.item:first-child {
  border-top: none;
}

.title {
  font-weight: 600;
  color: #111827;
}

.desc {
  margin-top: 6px;
  color: #4b5563;
  font-size: 14px;
}

.desc a {
  color: #4f46e5;
  text-decoration: none;
}

.desc a:hover {
  text-decoration: underline;
}

.muted {
  color: #9ca3af;
}

.empty {
  margin-top: 40px;
  text-align: center;
  color: #6b7280;
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
  margin-top: 48px;
  color: #9ca3af;
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.footer a {
  color: inherit;
  text-decoration: none;
}

.footer a:hover {
  color: #6b7280;
}

.sep {
  margin: 0 8px;
}

.online {
  color: #10b981;
}

.offline {
  color: #ef4444;
  font-weight: bold;
}
</style>

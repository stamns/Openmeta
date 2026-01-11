<template>
  <main class="wrap">
    <Header @toggle-history="showMobileHistory = !showMobileHistory" />

    <div class="layout-container">
      <!-- 移动端搜索历史抽屉 -->
      <div v-if="showMobileHistory" class="mobile-drawer-overlay" @click="showMobileHistory = false">
        <aside class="mobile-drawer" @click.stop>
          <div class="drawer-header">
            <h3>搜索历史</h3>
            <button @click="showMobileHistory = false">✕</button>
          </div>
          <ul class="history-list">
            <li v-for="item in history" :key="item" @click="q = item; doSearch(); showMobileHistory = false">
              {{ item }}
            </li>
          </ul>
        </aside>
      </div>

      <!-- 左侧边栏 (中大屏) -->
      <aside class="sidebar-left" v-if="searched && history.length > 0">
        <h3>搜索历史</h3>
        <ul class="history-list">
          <li v-for="item in history" :key="item" @click="q = item; doSearch()">
            {{ item }}
          </li>
        </ul>
      </aside>

      <div class="main-content">
        <SearchBar v-model="q" :loading="loading" @search="doSearch" />

        <!-- 错误提示组件 -->
        <ErrorMessage 
          :error="error" 
          @retry="doSearch" 
          @clear="clearError"
        />

        <SearchResults v-if="result && !error" :result="result" :duration-ms="durationMs" />

        <div v-if="!loading && !error && searched && items.length === 0" class="empty">
          未找到相关资源，请尝试其他关键词
        </div>
      </div>

      <!-- 右侧边栏 (大屏) -->
      <aside class="sidebar-right">
        <div class="info-card" v-if="searched && items.length > 0">
          <h3>统计信息</h3>
          <p>找到 {{ items.length }} 条结果</p>
  <main class="page">
    <HeaderBar
      :is-dark="isDark"
      :is-offline="isOffline"
      :history-count="history.length"
      @toggle-theme="toggleTheme"
      @open-history="historyOpen = true"
    />

    <div class="layout">
      <aside class="sidebar sidebar-left">
        <div class="card">
          <HistoryPanel :items="history" @select="selectHistory" @clear="clearHistory" />
        </div>
      </aside>

      <section class="main">
        <div class="card main-card">
          <SearchBar
            v-model="query"
            :loading="loading"
            placeholder="输入关键词，例如：三体 / 电影 / PDF"
            @search="doSearch"
          />

          <ErrorMessage :error="error" @retry="doSearch" @clear="clearError" />

          <SearchResults
            v-if="result && !error"
            :result="result"
            :duration-ms="durationMs"
            :items="items"
          />

          <div v-if="!loading && !error && searched && items.length === 0" class="empty">
            未找到相关资源，请尝试其他关键词
          </div>
        </div>
      </section>

      <aside class="sidebar sidebar-right">
        <div class="card side-card">
          <h2 class="side-title">使用提示</h2>
          <ul class="tips">
            <li>移动端可点右上角「历史」查看搜索记录。</li>
            <li>长按结果文字可复制（已开启文本选择）。</li>
            <li>回车可直接搜索；Tab 可进行键盘导航。</li>
          </ul>
        </div>
      </aside>
    </div>

    <footer class="footer" aria-label="页面底部">
      <a href="/health" target="_blank" rel="noreferrer">健康检查</a>
      <span class="sep" aria-hidden="true">·</span>
      <a href="https://vercel.com" target="_blank" rel="noreferrer">Vercel</a>
      <span class="sep" aria-hidden="true">·</span>
      <span class="muted">Theme: {{ isDark ? 'dark' : 'light' }}</span>
    </footer>

    <HistoryDrawer
      :open="historyOpen"
      :items="history"
      @close="historyOpen = false"
      @select="selectHistory"
      @clear="clearHistory"
    />
  </main>
</template>

<script setup lang="ts">
import { computed, ref, onMounted, onUnmounted } from 'vue';
import { search, type SearchItem, type SearchResponse } from '@/api/search';
import { useErrorHandler } from '@/hooks/useErrorHandler';
import { useTheme } from '@/hooks/useTheme';

import ErrorMessage from '@/components/ErrorMessage.vue';
import Header from '@/components/Header.vue';
import SearchBar from '@/components/SearchBar.vue';
import SearchResults from '@/components/SearchResults.vue';
import '@/styles/variables.css';
import '@/styles/responsive.css';
import HeaderBar from '@/components/HeaderBar.vue';
import SearchBar from '@/components/SearchBar.vue';
import SearchResults from '@/components/SearchResults.vue';
import HistoryPanel from '@/components/HistoryPanel.vue';
import HistoryDrawer from '@/components/HistoryDrawer.vue';

const HISTORY_KEY = 'openmeta-search-history';
const HISTORY_MAX = 20;

function readHistory(): string[] {
  try {
    const raw = window.localStorage.getItem(HISTORY_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((v) => typeof v === 'string') : [];
  } catch {
    return [];
  }
}

function writeHistory(next: string[]) {
  try {
    window.localStorage.setItem(HISTORY_KEY, JSON.stringify(next));
  } catch {
    // ignore
  }
}

const query = ref('');
const loading = ref(false);
const searched = ref(false);
const result = ref<SearchResponse | null>(null);
const durationMs = ref(0);
const isOffline = ref(!window.navigator.onLine);
const showMobileHistory = ref(false);
const historyOpen = ref(false);
const history = ref<string[]>(readHistory());

const { error, handleError, clearError } = useErrorHandler();
const { isDark, toggleTheme } = useTheme();

const history = ref<string[]>(JSON.parse(localStorage.getItem('search_history') || '[]'));

const items = computed<SearchItem[]>(() => {
  const r = result.value;
  if (!r) return [];
  return r.items || [];
});

function pushHistory(q: string) {
  const normalized = q.trim();
  if (!normalized) return;

  const next = [normalized, ...history.value.filter((x) => x !== normalized)].slice(0, HISTORY_MAX);
  history.value = next;
  writeHistory(next);
}

function clearHistory() {
  history.value = [];
  writeHistory([]);
}

function selectHistory(q: string) {
  query.value = q;
  historyOpen.value = false;
  doSearch();
}

async function doSearch() {
  if (!q.value.trim()) return;

  // Add to history
  if (!history.value.includes(q.value.trim())) {
    history.value.unshift(q.value.trim());
    history.value = history.value.slice(0, 10); // Keep last 10
    localStorage.setItem('search_history', JSON.stringify(history.value));
  }
  
  if (!query.value.trim()) return;

  clearError();
  loading.value = true;
  searched.value = true;
  result.value = null;

  pushHistory(query.value);

  const started = performance.now();
  try {
    result.value = await search(query.value);
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
  max-width: 1200px;
  margin: 0 auto;
  padding: 32px 16px;
  font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial,
    "Apple Color Emoji", "Segoe UI Emoji";
  color: var(--text-primary);
  background-color: var(--bg-primary);
  min-height: 100vh;
}

.layout-container {
  display: flex;
  gap: 24px;
}

.sidebar-left, .sidebar-right {
  width: 200px;
  display: none;
}

@media (min-width: 768px) {
  .sidebar-left {
    display: block;
  }
}

@media (min-width: 1024px) {
  .sidebar-right {
    display: block;
  }
}

.main-content {
  flex: 1;
  min-width: 0;
}

.mobile-drawer-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 1000;
  display: flex;
}

.mobile-drawer {
  width: 280px;
  background: var(--bg-primary);
  height: 100%;
  padding: 20px;
  box-shadow: 2px 0 8px rgba(0, 0, 0, 0.2);
  display: flex;
  flex-direction: column;
}

.drawer-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.drawer-header h3 {
  margin: 0;
}

.drawer-header button {
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: var(--text-primary);
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.history-list {
  list-style: none;
  padding: 0;
  margin: 12px 0;
}

.history-list li {
  padding: 8px 12px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 14px;
  color: var(--text-secondary);
  transition: background 0.2s;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.history-list li:hover {
  background: var(--bg-secondary);
  color: var(--accent-color);
}

.info-card {
  padding: 16px;
  background: var(--bg-secondary);
  border-radius: 12px;
  border: 1px solid var(--border-color);
}

.info-card h3 {
  margin: 0 0 12px 0;
  font-size: 16px;
.main-card {
  padding: 18px 16px 14px;
}

.empty {
  margin-top: 18px;
  text-align: center;
  color: var(--text-secondary);
}

.footer {
  margin-top: 48px;
  color: var(--text-muted);
  margin-top: 28px;
  color: var(--text-secondary);
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-wrap: wrap;
  gap: 8px;
  gap: 6px;
}

.footer a {
  color: inherit;
  text-decoration: none;
}

.footer a:hover {
  color: var(--text-secondary);
}

.sep {
  margin: 0 4px;
}

.online {
  color: var(--success-color);
}

.offline {
  color: var(--error-color);
  font-weight: bold;
  color: var(--text-primary);
}

.sep {
  margin: 0 6px;
}

.muted {
  opacity: 0.85;
}

.side-card {
  padding: 14px;
}

.side-title {
  margin: 0;
  font-size: 14px;
  color: var(--text-secondary);
}

.tips {
  margin: 10px 0 0;
  padding-left: 18px;
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.5;
}
</style>

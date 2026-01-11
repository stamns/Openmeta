<template>
  <main class="page">
    <HeaderBar
      :is-dark="isDark"
      :is-offline="isOffline"
      :history-count="history.length"
      @toggle-theme="toggleTheme"
      @open-history="historyOpen = true"
    />

    <div class="layout">
      <!-- 左侧边栏: 搜索历史 (中大屏) -->
      <aside class="sidebar sidebar-left">
        <div class="card">
          <HistoryPanel :items="history" @select="selectHistory" @clear="clearHistory" />
        </div>
      </aside>

      <!-- 主内容区 -->
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

      <!-- 右侧边栏: 使用提示 (大屏) -->
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

    <!-- 页面底部 -->
    <footer class="footer" aria-label="页面底部">
      <a href="/health" target="_blank" rel="noreferrer">健康检查</a>
      <span class="sep" aria-hidden="true">·</span>
      <a href="https://vercel.com" target="_blank" rel="noreferrer">Vercel</a>
      <span class="sep" aria-hidden="true">·</span>
      <span class="muted">Theme: {{ isDark ? 'dark' : 'light' }}</span>
    </footer>

    <!-- 移动端历史抽屉 -->
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

// Reactive state
const query = ref('');
const loading = ref(false);
const searched = ref(false);
const result = ref<SearchResponse | null>(null);
const durationMs = ref(0);
const isOffline = ref(false);
const historyOpen = ref(false);
const history = ref<string[]>(readHistory());

// Error handling
const { error, handleError, clearError } = useErrorHandler();

// Theme
const { isDark, toggleTheme } = useTheme();

// Computed items from result
const items = computed<SearchItem[]>(() => {
  const r = result.value;
  if (!r) return [];
  return r.items || [];
});

// History management
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

// Search functionality
async function doSearch() {
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

// Online/offline status
function updateOnlineStatus() {
  isOffline.value = !window.navigator.onLine;
}

// Lifecycle hooks
onMounted(() => {
  isOffline.value = !window.navigator.onLine;
  window.addEventListener('online', updateOnlineStatus);
  window.addEventListener('offline', updateOnlineStatus);
});

onUnmounted(() => {
  window.removeEventListener('online', updateOnlineStatus);
  window.removeEventListener('offline', updateOnlineStatus);
});
</script>

<style scoped>
/* Page Layout */
.page {
  min-height: 100svh;
  max-width: 1400px;
  margin: 0 auto;
  padding: 24px 16px;
}

@media (min-width: 768px) {
  .page {
    padding: 32px 24px;
  }
}

@media (min-width: 1024px) {
  .page {
    padding: 40px 32px;
  }
}

/* Layout Grid */
.layout {
  display: grid;
  grid-template-columns: 1fr;
  gap: 16px;
  margin-top: 16px;
}

@media (min-width: 768px) {
  .layout {
    grid-template-columns: 240px 1fr;
    gap: 20px;
    margin-top: 20px;
  }
}

@media (min-width: 1024px) {
  .layout {
    grid-template-columns: 260px 1fr 280px;
    gap: 24px;
    margin-top: 24px;
  }
}

/* Sidebar */
.sidebar {
  display: none;
}

.sidebar-left {
  display: none;
}

.sidebar-right {
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

/* Main Content */
.main {
  min-width: 0;
}

.main-card {
  padding: 18px 16px 14px;
}

@media (min-width: 768px) {
  .main-card {
    padding: 24px 20px 18px;
  }
}

/* Empty State */
.empty {
  margin-top: 18px;
  text-align: center;
  color: var(--text-secondary);
  padding: 24px;
}

/* Footer */
.footer {
  margin-top: 28px;
  margin-top: 48px;
  color: var(--text-secondary);
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-wrap: wrap;
  gap: 6px;
  gap: 8px;
}

@media (min-width: 768px) {
  .footer {
    margin-top: 56px;
    gap: 6px;
  }
}

.footer a {
  color: inherit;
  text-decoration: none;
}

.footer a:hover {
  color: var(--text-secondary);
}

.sep {
  margin: 0 6px;
  color: var(--text-primary);
}

.sep {
  margin: 0 4px;
}

.muted {
  opacity: 0.85;
}

/* Side Card (Tips) */
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
  line-height: 1.6;
}

/* Card Styles */
.card {
  background: var(--surface-bg);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
}

/* Visibility */
.mobile-only {
  display: inline-flex;
}

.desktop-only {
  display: none;
}

@media (min-width: 768px) {
  .mobile-only {
    display: none;
  }

  .desktop-only {
    display: inline-flex;
  }
}

/* Online/Offline Status */
.online {
  color: var(--success-color);
}

.offline {
  color: var(--error-color);
  font-weight: 700;
}
</style>

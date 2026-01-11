<template>
  <section class="result" aria-label="搜索结果">
    <div class="meta">
      <span>耗时：{{ durationMs }}ms</span>
      <span class="provider">{{ result.provider }}</span>
      <span v-if="result.warning" class="warn" role="status">{{ result.warning }}</span>
    </div>

    <ul v-if="items.length" class="list">
      <li v-for="(item, idx) in items" :key="idx" class="item">
        <div class="title">
          {{ item.title || item.name || item.filename || '未命名资源' }}
        </div>
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
</template>

<script setup lang="ts">
import type { SearchItem, SearchResponse } from '@/api/search';

defineProps<{
  result: SearchResponse;
  items: SearchItem[];
  durationMs: number;
}>();
</script>

<style scoped>
.result {
  margin-top: 16px;
}

.meta {
  display: flex;
  gap: 10px;
  align-items: center;
  flex-wrap: wrap;
  color: var(--text-secondary);
  font-size: 14px;
  margin-bottom: 10px;
}

.provider {
  padding: 2px 8px;
  border: 1px solid var(--border-color);
  border-radius: 999px;
  background: var(--bg-secondary);
}

.warn {
  color: var(--warning-text);
  background: var(--warning-bg);
  border: 1px solid var(--warning-border);
  padding: 2px 8px;
  border-radius: 999px;
}

.list {
  list-style: none;
  padding: 0;
  margin: 0;
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  overflow: hidden;
  background: var(--surface-bg);
}

.item {
  padding: 16px;
  border-top: 1px solid var(--border-color);
  transition: background var(--transition-fast);
  -webkit-user-select: text;
  user-select: text;
  -webkit-touch-callout: default;
}

.item:hover {
  background: var(--surface-hover);
}

.item:first-child {
  border-top: none;
}

.title {
  font-weight: 700;
  color: var(--text-primary);
}

.desc {
  margin-top: 6px;
  color: var(--text-secondary);
  font-size: 14px;
}

.desc a {
  color: var(--accent-color);
  text-decoration: none;
}

.desc a:hover {
  text-decoration: underline;
}

.muted {
  color: color-mix(in srgb, var(--text-secondary) 60%, transparent);
}

.raw {
  margin-top: 10px;
}

pre {
  background: var(--code-bg);
  color: var(--code-text);
  padding: 12px;
  border-radius: var(--radius-md);
  overflow: auto;
}
</style>

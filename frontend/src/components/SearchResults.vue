<template>
  <section class="result" aria-label="搜索结果">
    <!-- Result metadata -->
    <div class="meta" role="status">
      <span class="duration">耗时：{{ durationMs }}ms</span>
      <span class="provider">{{ result.provider }}</span>
      <span v-if="result.warning" class="warn" role="alert">{{ result.warning }}</span>
    </div>

    <!-- Results list -->
    <ul v-if="items.length" class="list">
      <li v-for="(item, idx) in items" :key="idx" class="item">
        <div class="title">
          {{ item.title || item.name || item.filename || '未命名资源' }}
        </div>
        <div class="desc">
          <a
            v-if="item.url"
            :href="item.url"
            target="_blank"
            rel="noopener noreferrer"
            class="link"
          >
            打开链接
            <span class="sr-only">(在新窗口中打开)</span>
          </a>
          <span v-else class="muted">无链接字段</span>
        </div>
      </li>
    </ul>

    <!-- Raw JSON fallback -->
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
/* Result container */
.result {
  margin-top: 16px;
}

/* Metadata row */
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
  font-size: 12px;
}

.warn {
  color: var(--warning-text);
  background: var(--warning-bg);
  padding: 2px 8px;
  border-radius: 999px;
  border: 1px solid var(--warning-border);
  font-size: 12px;
}

/* Results list */
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
  cursor: default;
  -webkit-user-select: text;
  user-select: text;
}

.item:first-child {
  border-top: none;
}

.item:hover {
  background: var(--surface-hover);
}

.item:focus-within {
  outline: 2px solid var(--accent-color);
  outline-offset: -2px;
}

/* Title styling */
.title {
  font-weight: 700;
  color: var(--text-primary);
  word-break: break-word;
}

/* Description/link styling */
.desc {
  margin-top: 6px;
  color: var(--text-secondary);
  font-size: 14px;
}

.link {
  color: var(--accent-color);
  text-decoration: none;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.link:hover {
  text-decoration: underline;
}

.link:focus {
  outline: 2px solid var(--accent-color);
  outline-offset: 2px;
  border-radius: 4px;
}

.muted {
  color: var(--text-muted);
}

/* Raw JSON fallback */
.raw {
  margin-top: 10px;
  color: var(--text-primary);
}

.raw pre {
  background: var(--code-bg);
  color: var(--code-text);
  padding: 12px;
  border-radius: var(--radius-md);
  overflow: auto;
  max-height: 300px;
  font-size: 13px;
}

/* Screen reader only */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

/* ========================================
   Responsive Styles
   ======================================== */
@media (max-width: 479px) {
  .item {
    padding: 12px;
  }

  .meta {
    font-size: 13px;
  }

  .title {
    font-size: 15px;
  }

  .desc {
    font-size: 13px;
  }
}

@media (min-width: 480px) and (max-width: 767px) {
  .list {
    width: 100%;
  }
}

@media (min-width: 768px) and (max-width: 1023px) {
  .item {
    padding: 18px;
  }
}

@media (min-width: 1024px) {
  .item {
    padding: 18px;
  }
}

/* ========================================
   Print Styles
   ======================================== */
@media print {
  .item {
    break-inside: avoid;
    border: 1px solid #ccc;
  }

  .link {
    color: #000;
    text-decoration: underline;
  }
}
</style>

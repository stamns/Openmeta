<template>
  <section v-if="result" class="result">
    <div class="meta">
      <span>耗时：{{ durationMs }}ms</span>
      <span v-if="result.warning" class="warn">⚠️ {{ result.warning }}</span>
    </div>

    <ul v-if="items.length" class="list">
      <li v-for="(item, idx) in items" :key="idx" class="item" v-longpress="() => copyToClipboard(item.url)">
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
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { SearchItem, SearchResponse } from '@/api/search';

const props = defineProps<{
  result: SearchResponse | null;
  durationMs: number;
}>();

const items = computed<SearchItem[]>(() => {
  const r = props.result;
  if (!r) return [];
  return r.items || [];
});

const copyToClipboard = (text?: string) => {
  if (!text) return;
  navigator.clipboard.writeText(text).then(() => {
    // Optional feedback
  });
};

const vLongpress = {
  mounted(el: HTMLElement, binding: any) {
    let timer: any = null;
    const start = (e: any) => {
      if (e.type === 'click' && e.button !== 0) return;
      if (timer === null) {
        timer = setTimeout(() => {
          binding.value(e);
        }, 600);
      }
    };
    const cancel = () => {
      if (timer !== null) {
        clearTimeout(timer);
        timer = null;
      }
    };
    el.addEventListener('mousedown', start);
    el.addEventListener('touchstart', start);
    el.addEventListener('click', cancel);
    el.addEventListener('mouseout', cancel);
    el.addEventListener('touchend', cancel);
    el.addEventListener('touchcancel', cancel);
  },
};
</script>

<style scoped>
.result {
  margin-top: 18px;
}

.meta {
  display: flex;
  gap: 12px;
  color: var(--text-secondary);
  font-size: 14px;
  margin-bottom: 10px;
  align-items: center;
}

.warn {
  color: var(--warning-text);
  background: var(--warning-bg);
  padding: 2px 8px;
  border-radius: 4px;
}

.list {
  list-style: none;
  padding: 0;
  margin: 0;
  border: 1px solid var(--border-color);
  border-radius: 12px;
  overflow: hidden;
  background: var(--card-bg);
}

.item {
  padding: 16px;
  border-top: 1px solid var(--border-color);
  transition: background 0.2s;
  cursor: default;
}

.item:hover {
  background: var(--bg-secondary);
}

.item:first-child {
  border-top: none;
}

.title {
  font-weight: 600;
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
  color: var(--text-muted);
}

.raw {
  margin-top: 10px;
  color: var(--text-primary);
}

pre {
  background: #111827;
  color: #e5e7eb;
  padding: 12px;
  border-radius: 10px;
  overflow: auto;
}
</style>

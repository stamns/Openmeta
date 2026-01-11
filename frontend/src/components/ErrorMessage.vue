<template>
  <div v-if="error" class="error-container" :class="error.severity">
    <div class="error-icon">
      <span v-if="error.severity === 'critical'">🚨</span>
      <span v-else-if="error.severity === 'error'">❌</span>
      <span v-else>⚠️</span>
    </div>
    <div class="error-content">
      <h3 class="error-title">{{ isZh ? error.message.zh : error.message.en }}</h3>
      <p v-if="error.path" class="error-meta">
        {{ isZh ? '发生位置' : 'Location' }}: {{ error.path }}
      </p>
      <p class="error-meta">
        {{ isZh ? '时间' : 'Time' }}: {{ formatTime(error.timestamp) }}
      </p>
      <div v-if="showDetails && error.details" class="error-details">
        <pre>{{ JSON.stringify(error.details, null, 2) }}</pre>
      </div>
      <div class="error-actions">
        <button class="retry-btn" @click="$emit('retry')">
          {{ isZh ? '重试' : 'Retry' }}
        </button>
        <button class="clear-btn" @click="$emit('clear')">
          {{ isZh ? '关闭' : 'Close' }}
        </button>
        <button v-if="error.details" class="details-btn" @click="showDetails = !showDetails">
          {{ showDetails ? (isZh ? '隐藏详情' : 'Hide Details') : (isZh ? '查看详情' : 'Show Details') }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { AppError } from '@/types/error';

const props = defineProps<{
  error: AppError | null;
  lang?: 'zh' | 'en';
}>();

defineEmits(['retry', 'clear']);

const showDetails = ref(false);
const isZh = computed(() => props.lang !== 'en');

function formatTime(timestamp: string) {
  return new Date(timestamp).toLocaleString(isZh.value ? 'zh-CN' : 'en-US');
}
</script>

<style scoped>
.error-container {
  margin-top: 20px;
  padding: 16px;
  border-radius: 12px;
  display: flex;
  gap: 16px;
  border: 1px solid transparent;
  animation: slideIn 0.3s ease-out;
  background-color: var(--bg-secondary);
  color: var(--text-primary);
}

@keyframes slideIn {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}

.critical {
  background-color: rgba(239, 68, 68, 0.1);
  border-color: var(--error-color);
  color: var(--error-color);
}

.error {
  background-color: rgba(239, 68, 68, 0.05);
  border-color: var(--error-color);
  color: var(--error-color);
}

.warning {
  background-color: var(--warning-bg);
  border-color: var(--warning-text);
  color: var(--warning-text);
}

.error-icon {
  font-size: 24px;
}

.error-content {
  flex: 1;
}

.error-title {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
}

.error-meta {
  margin: 4px 0 0;
  font-size: 12px;
  opacity: 0.8;
}

.error-details {
  margin-top: 12px;
  padding: 10px;
  background: var(--bg-tertiary);
  border-radius: 8px;
  font-size: 12px;
  overflow: auto;
  max-height: 200px;
  color: var(--text-primary);
}

pre {
  margin: 0;
  white-space: pre-wrap;
  word-break: break-all;
}

.error-actions {
  margin-top: 16px;
  display: flex;
  gap: 12px;
}

button {
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 14px;
  cursor: pointer;
  border: 1px solid transparent;
  transition: all 0.2s;
}

.retry-btn {
  background-color: var(--accent-color);
  color: white;
}

.retry-btn:hover {
  background-color: var(--accent-hover);
}

.clear-btn {
  background-color: var(--bg-primary);
  border-color: var(--border-color);
  color: var(--text-primary);
}

.clear-btn:hover {
  background-color: var(--bg-secondary);
}

.details-btn {
  background-color: transparent;
  color: inherit;
  text-decoration: underline;
  padding: 6px 0;
}
</style>

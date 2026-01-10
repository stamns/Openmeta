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
}

@keyframes slideIn {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}

.critical {
  background-color: #fef2f2;
  border-color: #fecaca;
  color: #991b1b;
}

.error {
  background-color: #fffafb;
  border-color: #fee2e2;
  color: #b91c1c;
}

.warning {
  background-color: #fffbeb;
  border-color: #fef3c7;
  color: #92400e;
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
  background: rgba(0, 0, 0, 0.05);
  border-radius: 8px;
  font-size: 12px;
  overflow: auto;
  max-height: 200px;
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
  background-color: #111827;
  color: white;
}

.retry-btn:hover {
  background-color: #374151;
}

.clear-btn {
  background-color: white;
  border-color: #e5e7eb;
  color: #374151;
}

.clear-btn:hover {
  background-color: #f9fafb;
}

.details-btn {
  background-color: transparent;
  color: inherit;
  text-decoration: underline;
  padding: 6px 0;
}
</style>

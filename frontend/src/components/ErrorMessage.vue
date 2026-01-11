<template>
  <div v-if="error" class="error-container" :class="error.severity" role="alert" aria-live="assertive">
    <div class="error-icon">
      <span v-if="error.severity === 'critical'" aria-hidden="true">🚨</span>
      <span v-else-if="error.severity === 'error'" aria-hidden="true">❌</span>
      <span v-else aria-hidden="true">⚠️</span>
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

        <button
          v-if="error.details"
          class="details-btn"
          @click="showDetails = !showDetails"
          :aria-expanded="showDetails"
        >
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
/* Error container */
.error-container {
  margin-top: 20px;
  padding: 16px;
  border-radius: var(--radius-md);
  display: flex;
  gap: 16px;
  border: 1px solid transparent;
  animation: slideIn 0.3s ease-out;
  background-color: var(--bg-secondary);
  color: var(--text-primary);
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* Severity-specific styles */
.critical {
  background-color: var(--critical-bg);
  border-color: var(--critical-border);
  color: var(--critical-text);
}

.error {
  background-color: var(--error-bg);
  border-color: var(--error-border);
  color: var(--error-text);
}

.warning {
  background-color: var(--warning-bg);
  border-color: var(--warning-border);
  color: var(--warning-text);
}

/* Icon */
.error-icon {
  font-size: 24px;
  flex-shrink: 0;
}

/* Content area */
.error-content {
  flex: 1;
  min-width: 0;
}

.error-title {
  margin: 0;
  font-size: 16px;
  font-weight: 700;
}

.error-meta {
  margin: 4px 0 0;
  font-size: 12px;
  opacity: 0.9;
}

/* Details section */
.error-details {
  margin-top: 12px;
  padding: 10px;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-sm);
  font-size: 12px;
  overflow: auto;
  max-height: 200px;
  color: var(--text-primary);
}

.error-details pre {
  margin: 0;
  white-space: pre-wrap;
  word-break: break-all;
}

/* Action buttons */
.error-actions {
  margin-top: 16px;
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.error-actions button {
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  font-size: 14px;
  cursor: pointer;
  border: 1px solid transparent;
  transition: background var(--transition-fast), border-color var(--transition-fast);
  min-height: 44px;
}

.retry-btn {
  background-color: var(--accent-color);
  color: var(--on-accent);
  border-color: var(--accent-color);
}

.retry-btn:hover {
  background-color: var(--accent-hover);
  border-color: var(--accent-hover);
}

.clear-btn {
  background-color: transparent;
  border-color: currentColor;
  color: inherit;
}

.clear-btn:hover {
  background-color: color-mix(in srgb, currentColor 10%, transparent);
}

.details-btn {
  background-color: transparent;
  color: inherit;
  text-decoration: underline;
  border-color: transparent;
}

/* ========================================
   Responsive Styles
   ======================================== */
@media (max-width: 479px) {
  .error-container {
    padding: 12px;
    gap: 12px;
  }

  .error-title {
    font-size: 15px;
  }

  .error-actions {
    flex-direction: column;
  }

  .error-actions button {
    width: 100%;
    justify-content: center;
  }
}

/* ========================================
   Reduced Motion
   ======================================== */
@media (prefers-reduced-motion: reduce) {
  .error-container {
    animation: none;
  }
}
</style>

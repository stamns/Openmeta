<template>
  <header class="header">
    <div class="brand">
      <h1 class="title">OpenMeta</h1>
      <p class="sub">网盘聚合搜索引擎（FastAPI + PanSou + Vue3）</p>
    </div>

    <div class="actions">
      <button
        type="button"
        class="action-btn"
        :aria-label="isDark ? '切换为浅色模式' : '切换为深色模式'"
        :aria-pressed="isDark"
        @click="$emit('toggleTheme')"
      >
        <span aria-hidden="true" class="icon">{{ isDark ? '🌙' : '☀️' }}</span>
        <span class="label">{{ isDark ? '深色' : '浅色' }}</span>
      </button>

      <button
        type="button"
        class="action-btn mobile-only"
        :disabled="historyCount === 0"
        aria-label="打开搜索历史"
        @click="$emit('openHistory')"
      >
        <span aria-hidden="true" class="icon">🕘</span>
        <span class="label">历史</span>
      </button>

      <span class="status" :class="isOffline ? 'offline' : 'online'" aria-live="polite">
        {{ isOffline ? '离线 (Offline)' : '在线 (Online)' }}
      </span>
    </div>
  </header>
</template>

<script setup lang="ts">
defineProps<{
  isDark: boolean;
  isOffline: boolean;
  historyCount: number;
}>();

defineEmits<{
  (e: 'toggleTheme'): void;
  (e: 'openHistory'): void;
}>();
</script>

<style scoped>
.header {
  display: flex;
  gap: 16px;
  align-items: flex-start;
  justify-content: space-between;
}

.brand {
  min-width: 0;
}

.title {
  margin: 0;
  font-size: 28px;
  letter-spacing: 0.2px;
  color: var(--accent-color);
}

.sub {
  margin: 6px 0 0;
  color: var(--text-secondary);
}

.actions {
  display: flex;
  gap: 10px;
  align-items: center;
  flex-wrap: wrap;
  justify-content: flex-end;
}

.action-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 10px 12px;
  border: 1px solid var(--border-color);
  background: var(--surface-bg);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: background var(--transition-fast), border-color var(--transition-fast);
}

.action-btn:hover:not(:disabled) {
  background: var(--surface-hover);
}

.action-btn:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.icon {
  font-size: 16px;
  line-height: 1;
}

.label {
  font-weight: 600;
}

.status {
  font-size: 13px;
  padding: 6px 10px;
  border-radius: 999px;
  border: 1px solid var(--border-color);
  background: var(--bg-secondary);
}

.online {
  color: var(--success-color);
}

.offline {
  color: var(--error-color);
  font-weight: 700;
}

@media (max-width: 479px) {
  .header {
    flex-direction: column;
  }

  .actions {
    justify-content: flex-start;
  }
}
</style>

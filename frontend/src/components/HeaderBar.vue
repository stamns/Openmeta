<template>
  <header class="header">
    <div class="brand">
      <h1 class="title">OpenMeta</h1>
      <p class="sub">网盘聚合搜索引擎（FastAPI + PanSou + Vue3）</p>
    </div>

    <div class="actions">
      <!-- Theme toggle button -->
      <button
        type="button"
        class="action-btn theme-btn"
        :aria-label="isDark ? '切换为浅色模式' : '切换为深色模式'"
        :aria-pressed="isDark"
        @click="$emit('toggleTheme')"
      >
        <span aria-hidden="true" class="icon">{{ isDark ? '☀️' : '🌙' }}</span>
        <span class="label">{{ isDark ? '浅色' : '深色' }}</span>
      </button>

      <!-- History button (mobile only) -->
      <button
        type="button"
        class="action-btn history-btn mobile-only"
        :disabled="historyCount === 0"
        aria-label="打开搜索历史"
        :aria-disabled="historyCount === 0"
        @click="$emit('openHistory')"
      >
        <span aria-hidden="true" class="icon">🕘</span>
        <span class="label">历史</span>
      </button>

      <!-- Online/offline status -->
      <span
        class="status"
        :class="isOffline ? 'offline' : 'online'"
        aria-live="polite"
      >
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
/* Header container */
.header {
  display: flex;
  gap: 16px;
  align-items: flex-start;
  justify-content: space-between;
  flex-wrap: wrap;
}

/* Brand section */
.brand {
  min-width: 0;
  flex: 1;
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
  font-size: 14px;
}

/* Actions section */
.actions {
  display: flex;
  gap: 10px;
  align-items: center;
  flex-wrap: wrap;
  justify-content: flex-end;
}

/* Action buttons */
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
  font-size: 14px;
  min-height: 44px;
}

.action-btn:hover:not(:disabled) {
  background: var(--surface-hover);
  border-color: var(--accent-color);
}

.action-btn:focus {
  outline: 2px solid var(--accent-color);
  outline-offset: 2px;
}

.action-btn:disabled,
.action-btn[aria-disabled="true"] {
  opacity: 0.55;
  cursor: not-allowed;
}

/* Icon styling */
.icon {
  font-size: 16px;
  line-height: 1;
}

/* Label styling */
.label {
  font-weight: 600;
}

/* Online/offline status */
.status {
  font-size: 13px;
  padding: 6px 10px;
  border-radius: 999px;
  border: 1px solid var(--border-color);
  background: var(--bg-secondary);
  font-weight: 500;
}

.online {
  color: var(--success-color);
}

.offline {
  color: var(--error-color);
}

/* ========================================
   Extra Small Devices (< 480px)
   ======================================== */
@media (max-width: 479.98px) {
  .header {
    flex-direction: column;
    gap: 12px;
  }

  .actions {
    justify-content: flex-start;
    width: 100%;
  }

  .title {
    font-size: 24px;
  }

  .sub {
    font-size: 13px;
  }

  .action-btn {
    flex: 1;
    justify-content: flex-start;
  }

  .theme-btn {
    flex: 1;
  }
}

/* ========================================
   Small Devices (480px - 768px)
   ======================================== */
@media (min-width: 480px) and (max-width: 767px) {
  .title {
    font-size: 26px;
  }
}

/* ========================================
   Medium and Large Devices (768px+)
   ======================================== */
@media (min-width: 768px) {
  .action-btn {
    padding: 10px 14px;
  }
}

/* ========================================
   Visibility Utilities
   ======================================== */
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

/* ========================================
   Reduced Motion
   ======================================== */
@media (prefers-reduced-motion: reduce) {
  .action-btn {
    transition: none;
  }
}
</style>

<template>
  <header class="header">
    <div class="header-main">
      <h1>OpenMeta</h1>
      <div class="header-actions">
        <button class="icon-btn mobile-only" @click="$emit('toggleHistory')" aria-label="搜索历史">
          📜
        </button>
        <button class="theme-toggle" @click="toggleTheme" :aria-label="isDark ? '切换到浅色模式' : '切换到深色模式'">
          <span v-if="isDark" aria-hidden="true">☀️</span>
          <span v-else aria-hidden="true">🌙</span>
        </button>
      </div>
    </div>
    <p class="sub">网盘聚合搜索引擎（FastAPI + PanSou + Vue3）</p>
  </header>
</template>

<script setup lang="ts">
import { useTheme } from '@/hooks/useTheme';

defineEmits(['toggleHistory']);
const { isDark, toggleTheme } = useTheme();
</script>

<style scoped>
.header {
  margin-bottom: 32px;
}

.header-main {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.header-actions {
  display: flex;
  gap: 8px;
}

.header h1 {
  margin: 0;
  font-size: 32px;
  color: var(--accent-color);
}

.theme-toggle, .icon-btn {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 50%;
  width: 44px;
  height: 44px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  transition: all 0.2s;
  color: var(--text-primary);
}

.theme-toggle:hover, .icon-btn:hover {
  background: var(--bg-tertiary);
}

.mobile-only {
  display: flex;
  font-size: 18px;
}

@media (min-width: 768px) {
  .mobile-only {
    display: none;
  }
}

.sub {
  margin-top: 6px;
  color: var(--text-secondary);
}
</style>

<template>
  <div class="panel" aria-label="搜索历史">
    <div class="head">
      <h2 class="title">搜索历史</h2>
      <button
        type="button"
        class="clear"
        :disabled="items.length === 0"
        aria-label="清空搜索历史"
        @click="$emit('clear')"
      >
        清空
      </button>
    </div>

    <p v-if="items.length === 0" class="empty">暂无历史记录</p>

    <ul v-else class="list" role="list">
      <li v-for="q in items" :key="q" class="item">
        <button
          type="button"
          class="item-btn"
          :title="q"
          @click="$emit('select', q)"
        >
          <span class="item-text">{{ q }}</span>
        </button>
      </li>
    </ul>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  items: string[];
}>();

defineEmits<{
  (e: 'select', q: string): void;
  (e: 'clear'): void;
}>();
</script>

<style scoped>
/* Panel container */
.panel {
  padding: 14px;
}

/* Header */
.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.title {
  margin: 0;
  font-size: 14px;
  letter-spacing: 0.2px;
  color: var(--text-secondary);
}

/* Clear button */
.clear {
  border: 1px solid var(--border-color);
  background: transparent;
  border-radius: var(--radius-sm);
  padding: 8px 10px;
  cursor: pointer;
  font-size: 13px;
  color: var(--text-secondary);
  transition: background var(--transition-fast), border-color var(--transition-fast);
  min-height: 36px;
}

.clear:hover:not(:disabled) {
  background: var(--surface-hover);
  border-color: var(--accent-color);
  color: var(--accent-color);
}

.clear:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Empty state */
.empty {
  margin: 12px 0 0;
  color: var(--text-secondary);
  font-size: 13px;
}

/* History list */
.list {
  list-style: none;
  padding: 0;
  margin: 12px 0 0;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

/* History item button */
.item-btn {
  width: 100%;
  text-align: left;
  padding: 10px 12px;
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  background: var(--surface-bg);
  cursor: pointer;
  transition: background var(--transition-fast), border-color var(--transition-fast);
  overflow: hidden;
  display: flex;
  align-items: center;
  min-height: 44px;
}

.item-btn:hover {
  background: var(--surface-hover);
  border-color: var(--accent-color);
}

.item-btn:focus {
  outline: 2px solid var(--accent-color);
  outline-offset: 2px;
}

.item-text {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--text-primary);
  font-size: 14px;
}

/* ========================================
   Responsive Styles
   ======================================== */
@media (max-width: 479px) {
  .panel {
    padding: 12px;
  }

  .item-btn {
    padding: 12px 14px;
  }

  .item-text {
    font-size: 15px;
  }
}

@media (min-width: 768px) {
  .panel {
    padding: 16px;
  }
}
</style>

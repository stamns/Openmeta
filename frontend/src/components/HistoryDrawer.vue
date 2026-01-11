<template>
  <Teleport to="body">
    <!-- Backdrop overlay -->
    <Transition name="fade">
      <div
        v-if="open"
        class="overlay"
        @click.self="close"
        aria-hidden="true"
      />
    </Transition>

    <!-- Drawer panel -->
    <Transition name="slide">
      <div
        v-if="open"
        class="drawer"
        role="dialog"
        aria-modal="true"
        aria-label="搜索历史抽屉"
      >
        <div class="drawer-head">
          <h2 class="drawer-title">搜索历史</h2>
          <button
            ref="closeBtn"
            type="button"
            class="close"
            aria-label="关闭历史抽屉"
            @click="close"
          >
            关闭
          </button>
        </div>

        <div class="drawer-body">
          <HistoryPanel
            :items="items"
            @select="selectAndClose"
            @clear="$emit('clear')"
          />
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref, watch } from 'vue';
import HistoryPanel from './HistoryPanel.vue';

const props = defineProps<{
  open: boolean;
  items: string[];
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'select', q: string): void;
  (e: 'clear'): void;
}>();

const closeBtn = ref<HTMLButtonElement | null>(null);

function close() {
  emit('close');
}

function selectAndClose(q: string) {
  emit('select', q);
  emit('close');
}

function onKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape') {
    close();
  }
}

watch(
  () => props.open,
  async (v) => {
    if (!v) {
      document.body.style.overflow = '';
      window.removeEventListener('keydown', onKeydown);
      return;
    }

    document.body.style.overflow = 'hidden';
    window.addEventListener('keydown', onKeydown);
    await nextTick();
    closeBtn.value?.focus();
  },
  { immediate: true }
);

onBeforeUnmount(() => {
  document.body.style.overflow = '';
  window.removeEventListener('keydown', onKeydown);
});
</script>

<style scoped>
/* Overlay backdrop */
.overlay {
  position: fixed;
  inset: 0;
  background: var(--overlay-bg);
  backdrop-filter: blur(2px);
  z-index: 50;
}

/* Drawer panel */
.drawer {
  position: fixed;
  left: 0;
  top: 0;
  height: 100%;
  width: min(92vw, 360px);
  max-width: 400px;
  background: var(--bg-primary);
  border-right: 1px solid var(--border-color);
  z-index: 51;
  display: flex;
  flex-direction: column;
  box-shadow: var(--shadow-md);
}

/* Drawer header */
.drawer-head {
  padding: 12px 16px;
  border-bottom: 1px solid var(--border-color);
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-shrink: 0;
}

.drawer-title {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
}

/* Close button */
.close {
  border: 1px solid var(--border-color);
  background: var(--surface-bg);
  border-radius: var(--radius-md);
  padding: 10px 14px;
  cursor: pointer;
  font-size: 14px;
  color: var(--text-primary);
  transition: background var(--transition-fast);
  min-height: 44px;
}

.close:hover {
  background: var(--surface-hover);
}

.close:focus {
  outline: 2px solid var(--accent-color);
  outline-offset: 2px;
}

/* Drawer body */
.drawer-body {
  flex: 1;
  overflow: auto;
  -webkit-overflow-scrolling: touch;
}

/* Transitions */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.slide-enter-active,
.slide-leave-active {
  transition: transform 0.2s ease;
}

.slide-enter-from,
.slide-leave-to {
  transform: translateX(-100%);
}

/* ========================================
   Responsive Styles
   ======================================== */
@media (min-width: 768px) {
  .drawer {
    width: 320px;
  }
}

/* ========================================
   Reduced Motion
   ======================================== */
@media (prefers-reduced-motion: reduce) {
  .fade-enter-active,
  .fade-leave-active,
  .slide-enter-active,
  .slide-leave-active {
    transition: none;
  }
}
</style>

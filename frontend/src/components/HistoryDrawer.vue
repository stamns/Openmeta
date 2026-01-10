<template>
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="open" class="overlay" @click.self="close" />
    </Transition>

    <Transition name="slide">
      <div
        v-if="open"
        class="drawer"
        role="dialog"
        aria-modal="true"
        aria-label="搜索历史抽屉"
      >
        <div class="drawer-head">
          <button ref="closeBtn" type="button" class="close" aria-label="关闭" @click="close">
            关闭
          </button>
        </div>

        <div class="drawer-body">
          <HistoryPanel :items="items" @select="selectAndClose" @clear="emit('clear')" />
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
    emit('close');
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
.overlay {
  position: fixed;
  inset: 0;
  background: var(--overlay-bg);
  backdrop-filter: blur(2px);
  z-index: 50;
}

.drawer {
  position: fixed;
  right: 0;
  top: 0;
  height: 100%;
  width: min(92vw, 360px);
  background: var(--bg-primary);
  border-left: 1px solid var(--border-color);
  z-index: 51;
  display: flex;
  flex-direction: column;
  box-shadow: var(--shadow-md);
}

.drawer-head {
  padding: 12px;
  border-bottom: 1px solid var(--border-color);
  display: flex;
  justify-content: flex-end;
}

.close {
  border: 1px solid var(--border-color);
  background: var(--surface-bg);
  border-radius: var(--radius-md);
  padding: 10px 12px;
  cursor: pointer;
}

.close:hover {
  background: var(--surface-hover);
}

.drawer-body {
  overflow: auto;
}

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
  transform: translateX(100%);
}
</style>

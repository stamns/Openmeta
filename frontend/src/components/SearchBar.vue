<template>
  <section class="search" aria-label="搜索">
    <input
      ref="inputEl"
      class="input"
      :value="modelValue"
      type="search"
      inputmode="search"
      enterkeyhint="search"
      autocomplete="off"
      spellcheck="false"
      :placeholder="placeholder"
      :disabled="loading"
      aria-label="搜索关键词"
      @input="$emit('update:modelValue', ($event.target as HTMLInputElement).value)"
      @keydown.enter.prevent="$emit('search')"
      @focus="ensureVisible"
    />

    <button
      type="button"
      class="btn"
      :disabled="loading || !modelValue.trim()"
      @click="$emit('search')"
    >
      <span v-if="loading" class="spinner" aria-hidden="true"></span>
      {{ loading ? '搜索中…' : '搜索' }}
    </button>
  </section>
</template>

<script setup lang="ts">
import { ref } from 'vue';

defineProps<{
  modelValue: string;
  loading: boolean;
  placeholder: string;
}>();

defineEmits<{
  (e: 'update:modelValue', v: string): void;
  (e: 'search'): void;
}>();

const inputEl = ref<HTMLInputElement | null>(null);

function ensureVisible() {
  const el = inputEl.value;
  if (!el) return;

  window.setTimeout(() => {
    try {
      el.scrollIntoView({ block: 'center', behavior: 'smooth' });
    } catch {
      // ignore
    }
  }, 250);
}
</script>

<style scoped>
.search {
  display: flex;
  gap: 10px;
  width: 100%;
  margin: 16px auto 0;
}

.input {
  flex: 1;
  padding: 12px 14px;
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  background: var(--surface-bg);
  color: var(--text-primary);
  outline: none;
  transition: border-color var(--transition-fast), box-shadow var(--transition-fast);
}

.input:focus {
  border-color: var(--accent-color);
  box-shadow: var(--focus-ring);
}

.btn {
  padding: 10px 18px;
  border: none;
  border-radius: var(--radius-md);
  background: var(--accent-color);
  color: var(--on-accent);
  cursor: pointer;
  font-weight: 700;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: background var(--transition-fast);
  min-width: 96px;
}

.btn:hover:not(:disabled) {
  background: var(--accent-hover);
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.spinner {
  width: 16px;
  height: 16px;
  border: 2px solid var(--spinner-track);
  border-top: 2px solid var(--on-accent);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}

@media (max-width: 479px) {
  .search {
    flex-direction: column;
  }

  .btn {
    width: 100%;
  }
}

@media (min-width: 480px) and (max-width: 767px) {
  .search {
    width: 95%;
  }
}

@media (min-width: 768px) and (max-width: 1023px) {
  .search {
    width: 80%;
  }
}

@media (min-width: 1024px) {
  .search {
    width: 60%;
  }
}
</style>

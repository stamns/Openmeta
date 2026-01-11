<template>
  <section class="search">
    <input
      :value="modelValue"
      @input="$emit('update:modelValue', ($event.target as HTMLInputElement).value)"
      class="input"
      placeholder="输入关键词，例如：三体 / 电影 / PDF"
      @keydown.enter="$emit('search')"
      :disabled="loading"
      aria-label="搜索关键词"
    />
    <button class="btn" :disabled="loading || !modelValue.trim()" @click="$emit('search')">
      <span v-if="loading" class="spinner"></span>
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
defineProps<{
  modelValue: string;
  loading: boolean;
}>();

defineEmits(['update:modelValue', 'search']);
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
  margin-top: 18px;
  width: 100%;
  margin: 16px auto 0;
}

.input {
  flex: 1;
  padding: 12px 16px;
  border: 1px solid var(--border-color);
  border-radius: 12px;
  outline: none;
  background-color: var(--input-bg);
  color: var(--text-primary);
  transition: border-color 0.2s;
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
  box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
}

.btn {
  padding: 10px 20px;
  border: none;
  border-radius: 12px;
  background: var(--accent-color);
  color: white;
  cursor: pointer;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: background 0.2s;
  min-width: 100px;
  height: 44px;
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
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top: 2px solid white;
  border: 2px solid var(--spinner-track);
  border-top: 2px solid var(--on-accent);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
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

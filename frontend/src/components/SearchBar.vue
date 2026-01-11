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
</script>

<style scoped>
.search {
  display: flex;
  gap: 10px;
  margin-top: 18px;
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
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
</style>

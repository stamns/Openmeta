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
      :aria-describedby="loading ? 'search-status' : undefined"
      @input="$emit('update:modelValue', ($event.target as HTMLInputElement).value)"
      @keydown.enter.prevent="$emit('search')"
      @focus="ensureVisible"
    />

    <button
      type="button"
      class="btn"
      :disabled="loading || !modelValue.trim()"
      @click="$emit('search')"
      aria-label="执行搜索"
    >
      <span v-if="loading" class="spinner" aria-hidden="true"></span>
      {{ loading ? '搜索中…' : '搜索' }}
    </button>

    <!-- Live region for screen readers -->
    <span id="search-status" class="sr-only" role="status" aria-live="polite">
      {{ loading ? '正在搜索...' : '' }}
    </span>
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

/**
 * Ensure input is visible when focused on mobile
 * This prevents the virtual keyboard from hiding the input
 */
function ensureVisible() {
  const el = inputEl.value;
  if (!el) return;

  // Use setTimeout to allow the keyboard to start appearing
  window.setTimeout(() => {
    try {
      el.scrollIntoView({ block: 'center', behavior: 'smooth' });
    } catch {
      // Fallback for older browsers
      el.scrollIntoView(false);
    }
  }, 300);
}
</script>

<style scoped>
/* Search container */
.search {
  display: flex;
  gap: 10px;
  margin: 16px auto 0;
  width: 100%;
}

/* Search input */
.input {
  flex: 1;
  padding: 12px 14px;
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  background: var(--surface-bg);
  color: var(--text-primary);
  outline: none;
  font-size: 16px; /* Prevent iOS zoom on focus */
  transition: border-color var(--transition-fast), box-shadow var(--transition-fast);
  min-height: 48px;
}

.input:focus {
  border-color: var(--accent-color);
  box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.15);
}

.input:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

/* Search button */
.btn {
  padding: 10px 18px;
  border: none;
  border-radius: var(--radius-md);
  background: var(--accent-color);
  color: var(--on-accent);
  cursor: pointer;
  font-weight: 700;
  font-size: 15px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: background var(--transition-fast);
  min-width: 96px;
  min-height: 48px;
  box-shadow: var(--shadow-sm);
}

.btn:hover:not(:disabled) {
  background: var(--accent-hover);
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

/* Loading spinner */
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

/* Screen reader only */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

/* ========================================
   Extra Small Devices (< 480px)
   ======================================== */
@media (max-width: 479.98px) {
  .search {
    flex-direction: column;
  }

  .input {
    width: 100%;
  }

  .btn {
    width: 100%;
    height: 48px; /* Touch-friendly */
  }
}

/* ========================================
   Small Devices (480px - 768px)
   ======================================== */
@media (min-width: 480px) and (max-width: 767.98px) {
  .search {
    width: 95%;
  }
}

/* ========================================
   Medium Devices (768px - 1024px)
   ======================================== */
@media (min-width: 768px) and (max-width: 1023.98px) {
  .search {
    width: 80%;
  }
}

/* ========================================
   Large Devices (1024px+)
   ======================================== */
@media (min-width: 1024px) {
  .search {
    width: 60%;
  }
}
</style>

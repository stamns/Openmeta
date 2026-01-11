import { ref } from 'vue';

export type Theme = 'light' | 'dark';

const theme = ref<Theme>('light');
const isDark = ref(false);
let initialized = false;

export function useTheme() {
  const setTheme = (newTheme: Theme) => {
    theme.value = newTheme;
    isDark.value = newTheme === 'dark';
    if (typeof document !== 'undefined') {
      document.documentElement.setAttribute('data-theme', newTheme);
      localStorage.setItem('theme', newTheme);
import { computed, onMounted, onUnmounted, ref } from 'vue';

export type Theme = 'light' | 'dark';

const STORAGE_KEY = 'openmeta-theme';

const isBrowser = typeof window !== 'undefined' && typeof document !== 'undefined';

function readStoredTheme(): Theme | null {
  if (!isBrowser) return null;

  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (raw === 'light' || raw === 'dark') return raw;
    return null;
  } catch {
    return null;
  }
}

function getSystemTheme(): Theme {
  if (!isBrowser) return 'light';
  return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function applyTheme(theme: Theme) {
  if (!isBrowser) return;
  document.documentElement.dataset.theme = theme;
  document.documentElement.style.colorScheme = theme;
}

const initialStored = readStoredTheme();
const theme = ref<Theme>(initialStored ?? getSystemTheme());
const hasStoredPreference = ref<boolean>(initialStored !== null);

export function useTheme() {
  const isDark = computed(() => theme.value === 'dark');

  const setTheme = (next: Theme, persist = true) => {
    theme.value = next;
    applyTheme(next);

    if (!persist || !isBrowser) return;

    try {
      window.localStorage.setItem(STORAGE_KEY, next);
      hasStoredPreference.value = true;
    } catch {
      // ignore
    }
  };

  const toggleTheme = () => {
    const newTheme = theme.value === 'light' ? 'dark' : 'light';
    setTheme(newTheme);
  };

  if (!initialized && typeof window !== 'undefined') {
    initialized = true;
    const savedTheme = localStorage.getItem('theme') as Theme | null;
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

    if (savedTheme) {
      setTheme(savedTheme);
    } else if (systemPrefersDark) {
      setTheme('dark');
    } else {
      setTheme('light');
    }

    // Listen for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem('theme')) {
        setTheme(e.matches ? 'dark' : 'light');
      }
    });
  }
    setTheme(isDark.value ? 'light' : 'dark');
  };

  const clearThemePreference = () => {
    if (isBrowser) {
      try {
        window.localStorage.removeItem(STORAGE_KEY);
      } catch {
        // ignore
      }
    }

    hasStoredPreference.value = false;
    setTheme(getSystemTheme(), false);
  };

  const syncSystemTheme = () => {
    if (hasStoredPreference.value) return;
    setTheme(getSystemTheme(), false);
  };

  let mql: MediaQueryList | null = null;
  const onChange = () => syncSystemTheme();

  onMounted(() => {
    applyTheme(theme.value);

    mql = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
    if (!mql) return;

    if ('addEventListener' in mql) {
      mql.addEventListener('change', onChange);
    } else {
      // @ts-expect-error Safari < 14
      mql.addListener(onChange);
    }
  });

  onUnmounted(() => {
    if (!mql) return;

    if ('removeEventListener' in mql) {
      mql.removeEventListener('change', onChange);
    } else {
      // @ts-expect-error Safari < 14
      mql.removeListener(onChange);
    }
  });

  return {
    theme,
    isDark,
    toggleTheme,
    setTheme
    setTheme,
    clearThemePreference,
    hasStoredPreference,
  };
}

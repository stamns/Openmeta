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

  return {
    theme,
    isDark,
    toggleTheme,
    setTheme
  };
}

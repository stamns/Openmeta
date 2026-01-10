import { ref } from 'vue';
import { AppError } from '@/types/error';

export function useErrorHandler() {
  const error = ref<AppError | null>(null);

  const handleError = (e: any) => {
    if (e && e.code && e.message) {
      error.value = e as AppError;
    } else {
      console.error('Unhandled error:', e);
    }
  };

  const clearError = () => {
    error.value = null;
  };

  return {
    error,
    handleError,
    clearError,
  };
}

import axios, { AxiosError, AxiosInstance, AxiosResponse, InternalAxiosRequestConfig } from 'axios';
import { ErrorCode, ErrorSeverity, AppError } from '@/types/error';

const apiClient: AxiosInstance = axios.create({
  baseURL: '/',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 请求拦截器
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    // 可以在这里添加 auth token 等
    return config;
  },
  (error: AxiosError) => {
    return Promise.reject(error);
  }
);

// 响应拦截器
apiClient.interceptors.response.use(
  (response: AxiosResponse) => {
    return response;
  },
  async (error: AxiosError) => {
    const appError = transformError(error);
    
    // 自动记录错误日志到后端
    if (appError.severity === ErrorSeverity.ERROR || appError.severity === ErrorSeverity.CRITICAL) {
      logErrorToBackend(appError);
    }
    
    return Promise.reject(appError);
  }
);

export function transformError(error: AxiosError): AppError {
  const timestamp = new Date().toISOString();
  const path = error.config?.url;
  
  if (!window.navigator.onLine) {
    return {
      code: ErrorCode.OFFLINE,
      message: {
        zh: '网络连接已断开，请检查您的网络设置',
        en: 'Network connection lost, please check your settings',
      },
      severity: ErrorSeverity.WARNING,
      timestamp,
      path,
    };
  }

  if (error.code === 'ECONNABORTED') {
    return {
      code: ErrorCode.TIMEOUT,
      message: {
        zh: '请求超时，请稍后重试',
        en: 'Request timeout, please try again later',
      },
      severity: ErrorSeverity.WARNING,
      timestamp,
      path,
    };
  }

  if (!error.response) {
    return {
      code: ErrorCode.NETWORK_ERROR,
      message: {
        zh: '网络错误，无法连接到服务器',
        en: 'Network error, could not connect to server',
      },
      severity: ErrorSeverity.ERROR,
      timestamp,
      path,
    };
  }

  const status = error.response.status;
  const data = error.response.data as any;

  if (status === 401) {
    return {
      code: ErrorCode.AUTH_ERROR,
      message: {
        zh: '认证过期，请重新登录',
        en: 'Session expired, please login again',
      },
      severity: ErrorSeverity.WARNING,
      status,
      timestamp,
      path,
    };
  }

  if (status === 403) {
    return {
      code: ErrorCode.PERMISSION_DENIED,
      message: {
        zh: '您没有权限执行此操作',
        en: 'You do not have permission to perform this action',
      },
      severity: ErrorSeverity.WARNING,
      status,
      timestamp,
      path,
    };
  }

  if (status === 429) {
    return {
      code: ErrorCode.HTTP_ERROR,
      message: {
        zh: '请求过于频繁，请稍后再试',
        en: 'Too many requests, please try again later',
      },
      severity: ErrorSeverity.WARNING,
      status,
      timestamp,
      path,
    };
  }

  if (status >= 500) {
    return {
      code: ErrorCode.SERVER_ERROR,
      message: {
        zh: '服务器内部错误，工程师正在抢修中',
        en: 'Internal server error, our engineers are working on it',
      },
      severity: ErrorSeverity.CRITICAL,
      status,
      timestamp,
      path,
      details: data,
    };
  }

  return {
    code: ErrorCode.HTTP_ERROR,
    message: {
      zh: data?.message || '请求发生错误',
      en: data?.message || 'An error occurred during the request',
    },
    severity: ErrorSeverity.ERROR,
    status,
    timestamp,
    path,
    details: data,
  };
}

async function logErrorToBackend(error: AppError) {
  try {
    // 避免循环调用，使用原生 fetch 或另一个 axios 实例
    await fetch('/api/logs', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        severity: error.severity,
        message: error.message.en,
        context: {
          code: error.code,
          status: error.status,
          path: error.path,
          timestamp: error.timestamp,
          details: error.details,
          userAgent: navigator.userAgent,
        },
      }),
    });
  } catch (e) {
    console.error('Failed to log error to backend:', e);
  }
}

export default apiClient;

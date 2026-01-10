export enum ErrorSeverity {
  INFO = 'info',
  WARNING = 'warning',
  ERROR = 'error',
  CRITICAL = 'critical'
}

export enum ErrorCode {
  NETWORK_ERROR = 'NETWORK_ERROR',
  TIMEOUT = 'TIMEOUT',
  HTTP_ERROR = 'HTTP_ERROR',
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  AUTH_ERROR = 'AUTH_ERROR',
  PERMISSION_DENIED = 'PERMISSION_DENIED',
  SERVER_ERROR = 'SERVER_ERROR',
  PARSE_ERROR = 'PARSE_ERROR',
  OFFLINE = 'OFFLINE',
  UNKNOWN = 'UNKNOWN'
}

export interface AppError {
  code: ErrorCode;
  message: {
    zh: string;
    en: string;
  };
  severity: ErrorSeverity;
  status?: number;
  details?: any;
  timestamp: string;
  path?: string;
}

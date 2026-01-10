import { describe, it, expect, vi } from 'vitest';
import { transformError } from '../api/client';
import { ErrorCode, ErrorSeverity } from '../types/error';
import { AxiosError } from 'axios';

describe('Error Handling', () => {
  it('should handle offline status', () => {
    // Mock navigator.onLine
    vi.stubGlobal('navigator', { onLine: false });
    
    const mockError = {
      config: { url: '/test' }
    } as AxiosError;
    
    const result = transformError(mockError);
    expect(result.code).toBe(ErrorCode.OFFLINE);
    expect(result.severity).toBe(ErrorSeverity.WARNING);
    
    vi.unstubAllGlobals();
  });

  it('should handle timeout error', () => {
    vi.stubGlobal('navigator', { onLine: true });
    
    const mockError = {
      code: 'ECONNABORTED',
      config: { url: '/test' }
    } as AxiosError;
    
    const result = transformError(mockError);
    expect(result.code).toBe(ErrorCode.TIMEOUT);
  });

  it('should handle 401 Unauthorized', () => {
    const mockError = {
      response: {
        status: 401,
        data: {}
      },
      config: { url: '/test' }
    } as AxiosError;
    
    const result = transformError(mockError);
    expect(result.code).toBe(ErrorCode.AUTH_ERROR);
    expect(result.severity).toBe(ErrorSeverity.WARNING);
  });

  it('should handle 500 Server Error', () => {
    const mockError = {
      response: {
        status: 500,
        data: { message: 'Internal Server Error' }
      },
      config: { url: '/test' }
    } as AxiosError;
    
    const result = transformError(mockError);
    expect(result.code).toBe(ErrorCode.SERVER_ERROR);
    expect(result.severity).toBe(ErrorSeverity.CRITICAL);
  });
});

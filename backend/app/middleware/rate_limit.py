"""
速率限制中间件
支持基于 IP 的请求限流，使用内存存储
"""

from __future__ import annotations

import asyncio
import json
import os
import time
from typing import Dict, Optional, Tuple

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


class RateLimiter:
    """速率限制器"""
    
    def __init__(self):
        self.memory_storage: Dict[str, Tuple[int, float]] = {}  # (count, window_start)
        self.memory_lock = asyncio.Lock()
        
        # 速率限制配置
        self.requests_per_minute = int(os.getenv("RATE_LIMIT_PER_MINUTE", "60"))
        self.window_size = 60  # 60 秒窗口
    
    async def is_rate_limited(self, client_ip: str) -> Tuple[bool, Dict[str, int]]:
        """
        检查是否超过速率限制
        
        Returns:
            Tuple[是否被限制, 限流信息字典]
        """
        current_time = time.time()
        window_start = current_time - (current_time % self.window_size)
        
        # 使用内存存储检查速率限制
        return await self._check_memory_rate_limit(client_ip, current_time, window_start)
    
    async def _check_memory_rate_limit(
        self,
        client_ip: str,
        current_time: float,
        window_start: float
    ) -> Tuple[bool, Dict[str, int]]:
        """使用内存存储检查速率限制"""
        async with self.memory_lock:
            key = f"{client_ip}:{window_start}"
            current_count, stored_window_start = self.memory_storage.get(key, (0, window_start))
            
            # 如果窗口已重置，重置计数
            if stored_window_start != window_start:
                current_count = 0
                stored_window_start = window_start
            
            current_count += 1
            self.memory_storage[key] = (current_count, stored_window_start)
            
            # 清理过期数据
            self._cleanup_old_entries(current_time)
            
            if current_count > self.requests_per_minute:
                return True, {
                    "limit": self.requests_per_minute,
                    "remaining": 0,
                    "reset": int(window_start + self.window_size)
                }
            else:
                remaining = max(0, self.requests_per_minute - current_count)
                return False, {
                    "limit": self.requests_per_minute,
                    "remaining": remaining,
                    "reset": int(window_start + self.window_size)
                }
    
    def _cleanup_old_entries(self, current_time: float) -> None:
        """清理过期的内存存储条目"""
        cutoff_time = current_time - (self.window_size * 2)
        keys_to_delete = []
        
        for key, (count, window_start) in self.memory_storage.items():
            if window_start < cutoff_time:
                keys_to_delete.append(key)
        
        for key in keys_to_delete:
            del self.memory_storage[key]


class RateLimitMiddleware(BaseHTTPMiddleware):
    """速率限制中间件"""
    
    def __init__(self, app, rate_limiter: Optional[RateLimiter] = None):
        super().__init__(app)
        self.rate_limiter = rate_limiter or RateLimiter()
    
    async def dispatch(self, request: Request, call_next):
        """处理请求"""
        
        # 获取客户端 IP
        client_ip = self._get_client_ip(request)
        
        # 检查速率限制
        is_limited, limit_info = await self.rate_limiter.is_rate_limited(client_ip)
        
        if is_limited:
            # 被限流，返回 429 响应
            response_data = {
                "error": "Rate limit exceeded",
                "message": f"请求过于频繁，请稍后再试。每分钟最多 {limit_info['limit']} 个请求。",
                "retry_after": limit_info["reset"] - int(time.time())
            }
            
            # 创建响应对象
            response = Response(
                content=json.dumps(response_data, ensure_ascii=False),
                status_code=429,
                media_type="application/json",
                headers={
                    "X-RateLimit-Limit": str(limit_info["limit"]),
                    "X-RateLimit-Remaining": str(limit_info["remaining"]),
                    "X-RateLimit-Reset": str(limit_info["reset"]),
                    "Retry-After": str(limit_info["reset"] - int(time.time())),
                }
            )
            
            return response
        else:
            # 未被限流，继续处理请求
            response = await call_next(request)
            
            # 添加限流响应头
            response.headers["X-RateLimit-Limit"] = str(limit_info["limit"])
            response.headers["X-RateLimit-Remaining"] = str(limit_info["remaining"])
            response.headers["X-RateLimit-Reset"] = str(limit_info["reset"])
            
            return response
    
    def _get_client_ip(self, request: Request) -> str:
        """从请求中获取客户端 IP"""
        # 尝试从 X-Forwarded-For 头获取
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            # X-Forwarded-For 可能包含多个 IP，取第一个
            return forwarded_for.split(",")[0].strip()
        
        # 回退到客户端 IP
        return request.client.host if request.client else "unknown"


# 全局速率限制器实例
_global_rate_limiter = RateLimiter()


def get_rate_limiter() -> RateLimiter:
    """获取全局速率限制器实例"""
    return _global_rate_limiter
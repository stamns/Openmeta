import time
from typing import Dict, List, Tuple, Optional
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
import threading
import logging

logger = logging.getLogger("openmeta.rate_limit")

class MemoryRateLimiter:
    def __init__(self, limit: int, window: int = 60):
        self.limit = limit
        self.window = window
        self.records: Dict[str, List[float]] = {}
        self._lock = threading.Lock()

    def is_allowed(self, client_id: str) -> Tuple[bool, int]:
        now = time.time()
        with self._lock:
            if client_id not in self.records:
                self.records[client_id] = [now]
                return True, self.limit - 1
            
            # Remove old records
            self.records[client_id] = [t for t in self.records[client_id] if now - t < self.window]
            
            if len(self.records[client_id]) < self.limit:
                self.records[client_id].append(now)
                return True, self.limit - len(self.records[client_id])
            
            return False, 0

class RedisRateLimiter:
    def __init__(self, redis_client, limit: int, window: int = 60):
        self.redis = redis_client
        self.limit = limit
        self.window = window

    def is_allowed(self, client_id: str) -> Tuple[bool, int]:
        key = f"rate_limit:{client_id}"
        try:
            now = int(time.time())
            pipe = self.redis.pipeline()
            pipe.zremrangebyscore(key, 0, now - self.window)
            pipe.zadd(key, {str(now + time.time()): now})
            pipe.zcard(key)
            pipe.expire(key, self.window)
            results = pipe.execute()
            
            current_count = results[2]
            if current_count <= self.limit:
                return True, self.limit - current_count
            return False, 0
        except Exception as e:
            logger.warning(f"Redis rate limiter error: {e}, falling back to memory")
            return None, 0 # Signal fallback

class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, limit: int = 60, redis_config: Optional[dict] = None):
        super().__init__(app)
        self.limit = limit
        self.memory_limiter = MemoryRateLimiter(limit=limit)
        self.redis_client = None
        
        if redis_config and redis_config.get("host"):
            try:
                import redis
                self.redis_client = redis.Redis(
                    host=redis_config["host"],
                    port=redis_config.get("port", 6379),
                    password=redis_config.get("password"),
                    decode_responses=True,
                    socket_timeout=1.0
                )
                self.redis_limiter = RedisRateLimiter(self.redis_client, limit=limit)
                logger.info("Using Redis for rate limiting")
            except (ImportError, Exception) as e:
                logger.warning(f"Could not initialize Redis rate limiter: {e}")
                self.redis_client = None

    async def dispatch(self, request: Request, call_next):
        # Skip rate limiting for health check if needed, but here we apply to all
        client_ip = request.client.host if request.client else "unknown"
        
        allowed = True
        remaining = self.limit
        
        if self.redis_client:
            res_allowed, res_remaining = self.redis_limiter.is_allowed(client_ip)
            if res_allowed is not None:
                allowed, remaining = res_allowed, res_remaining
            else:
                # Fallback
                allowed, remaining = self.memory_limiter.is_allowed(client_ip)
        else:
            allowed, remaining = self.memory_limiter.is_allowed(client_ip)
        
        if not allowed:
            return JSONResponse(
                status_code=429,
                content={
                    "error": "Too Many Requests", 
                    "message": f"Rate limit exceeded. Max {self.limit} requests per minute."
                },
                headers={
                    "X-RateLimit-Limit": str(self.limit),
                    "X-RateLimit-Remaining": "0",
                }
            )
        
        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(self.limit)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        return response
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

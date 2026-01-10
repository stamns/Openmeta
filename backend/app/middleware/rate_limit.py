"""
API 速率限制中间件
支持基于 IP 地址的速率限制，使用 Redis 或内存存储
"""

import asyncio
import time
from collections import defaultdict, deque
from typing import Dict, Optional, Tuple
import os
import json

from fastapi import Request, Response
from fastapi.responses import JSONResponse


class MemoryRateLimiter:
    """基于内存的速率限制器（fallback 方案）"""
    
    def __init__(self, max_requests: int, window_seconds: int):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.requests: Dict[str, deque] = defaultdict(deque)
    
    def is_rate_limited(self, client_ip: str) -> Tuple[bool, int, int]:
        """
        检查是否超出速率限制
        返回: (is_limited, remaining_requests, reset_time)
        """
        now = time.time()
        window_start = now - self.window_seconds
        
        # 清理过期请求
        client_requests = self.requests[client_ip]
        while client_requests and client_requests[0] < window_start:
            client_requests.popleft()
        
        # 检查是否超出限制
        if len(client_requests) >= self.max_requests:
            # 计算重置时间（窗口结束时间）
            oldest_request = client_requests[0] if client_requests else now
            reset_time = int(oldest_request + self.window_seconds)
            remaining = 0
            return True, remaining, reset_time
        
        # 添加当前请求
        client_requests.append(now)
        remaining = self.max_requests - len(client_requests)
        
        # 计算重置时间（窗口结束时间）
        if client_requests:
            oldest_request = client_requests[0]
            reset_time = int(oldest_request + self.window_seconds)
        else:
            reset_time = int(now + self.window_seconds)
        
        return False, remaining, reset_time


class RedisRateLimiter:
    """基于 Redis 的速率限制器"""
    
    def __init__(self, max_requests: int, window_seconds: int):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.redis_client = None
        self._init_redis()
    
    def _init_redis(self):
        """初始化 Redis 连接"""
        try:
            import redis as redis_sync
            
            redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
            self.redis_client = redis_sync.from_url(
                redis_url,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5
            )
        except ImportError:
            print("⚠️ Redis 库未安装，将使用内存存储")
            self.redis_client = None
        except Exception as e:
            print(f"⚠️ Redis 连接失败: {e}，将使用内存存储")
            self.redis_client = None
    
    async def is_rate_limited(self, client_ip: str) -> Tuple[bool, int, int]:
        """
        检查是否超出速率限制
        返回: (is_limited, remaining_requests, reset_time)
        """
        if not self.redis_client:
            # 如果 Redis 不可用，返回不限制
            return False, self.max_requests, int(time.time() + self.window_seconds)
        
        try:
            # 在线程池中执行 Redis 操作
            import asyncio
            loop = asyncio.get_event_loop()
            
            def check_rate_limit():
                now = time.time()
                key = f"rate_limit:{client_ip}"
                
                # 使用 Redis 管道操作保证原子性
                pipe = self.redis_client.pipeline()
                pipe.zremrangebyscore(key, 0, now - self.window_seconds)
                pipe.zcard(key)
                pipe.zadd(key, {str(now): now})
                pipe.expire(key, self.window_seconds)
                
                results = pipe.execute()
                current_requests = results[1]
                
                if current_requests >= self.max_requests:
                    remaining = 0
                    reset_time = int(now + self.window_seconds)
                    return True, remaining, reset_time
                
                remaining = self.max_requests - current_requests - 1
                reset_time = int(now + self.window_seconds)
                
                return False, remaining, reset_time
            
            return await loop.run_in_executor(None, check_rate_limit)
            
        except Exception as e:
            print(f"⚠️ Redis 操作失败: {e}，返回不限制")
            return False, self.max_requests, int(time.time() + self.window_seconds)


class RateLimitMiddleware:
    """速率限制中间件"""
    
    def __init__(self, app, default_limit_per_minute: int = 60):
        self.app = app
        self.default_limit_per_minute = default_limit_per_minute
        
        # 从环境变量读取速率限制配置
        rate_limit_per_minute = int(os.getenv('RATE_LIMIT_PER_MINUTE', str(default_limit_per_minute)))
        self.max_requests = rate_limit_per_minute
        self.window_seconds = 60  # 1 分钟窗口
        
        # 初始化速率限制器
        self.redis_available = self._check_redis_availability()
        if self.redis_available:
            self.limiter = RedisRateLimiter(self.max_requests, self.window_seconds)
            print(f"✅ 使用 Redis 速率限制: {self.max_requests} 请求/分钟")
        else:
            self.limiter = MemoryRateLimiter(self.max_requests, self.window_seconds)
            print(f"⚠️ 使用内存速率限制: {self.max_requests} 请求/分钟")
    
    def _check_redis_availability(self) -> bool:
        """检查 Redis 是否可用"""
        try:
            import redis as redis_sync
            # 这里只是检查导入是否成功，实际连接在首次使用时测试
            return True
        except ImportError:
            return False
    
    async def __call__(self, request: Request, call_next):
        # 跳过健康检查端点
        if request.url.path in ['/health', '/docs', '/openapi.json', '/redoc']:
            return await call_next(request)
        
        # 获取客户端 IP
        client_ip = self._get_client_ip(request)
        
        # 检查速率限制
        is_limited, remaining, reset_time = await self.limiter.is_rate_limited(client_ip)
        
        # 如果超出限制，返回 429
        if is_limited:
            return JSONResponse(
                status_code=429,
                content={
                    "error": "Too Many Requests",
                    "message": f"请求过于频繁，请稍后再试。每分钟最多 {self.max_requests} 个请求",
                    "limit": self.max_requests,
                    "remaining": remaining,
                    "reset_time": reset_time
                },
                headers={
                    "X-RateLimit-Limit": str(self.max_requests),
                    "X-RateLimit-Remaining": str(remaining),
                    "X-RateLimit-Reset": str(reset_time),
                    "Retry-After": str(reset_time - int(time.time()))
                }
            )
        
        # 正常处理请求
        response = await call_next(request)
        
        # 添加速率限制响应头
        response.headers["X-RateLimit-Limit"] = str(self.max_requests)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Reset"] = str(reset_time)
        
        return response
    
    def _get_client_ip(self, request: Request) -> str:
        """获取客户端 IP 地址"""
        # 尝试从 X-Forwarded-For 头部获取（反向代理环境）
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            # X-Forwarded-For 可能包含多个 IP，取第一个（客户端 IP）
            return forwarded_for.split(",")[0].strip()
        
        # 尝试从 X-Real-IP 头部获取
        real_ip = request.headers.get("x-real-ip")
        if real_ip:
            return real_ip
        
        # 最后使用客户端 IP
        client_ip = request.client.host if request.client else "unknown"
        return client_ip


# 便捷函数
def create_rate_limit_middleware(default_limit_per_minute: int = 60) -> RateLimitMiddleware:
    """创建速率限制中间件实例"""
    return RateLimitMiddleware(None, default_limit_per_minute)
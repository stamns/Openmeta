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

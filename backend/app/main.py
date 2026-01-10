"""
OpenMeta FastAPI 主应用配置
支持生产级日志、速率限制、监控和健康检查
"""

from __future__ import annotations

import logging
import os
import time
import uuid
import psutil
from datetime import datetime
from typing import Any, Optional

from fastapi import FastAPI, Request, Query, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from .services.pansou import pansou_search, get_token_manager
from .settings import settings
from .logging_config import setup_logging
from .metrics import metrics
from .middleware.rate_limit import RateLimitMiddleware

# 1. 设置结构化日志
logger = setup_logging(settings.log_level)

# 2. 请求追踪中间件
class RequestTracingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        request.state.request_id = request_id
        
        start_time = time.time()
        ip = request.client.host if request.client else "unknown"
        user_agent = request.headers.get("user-agent", "unknown")
        
        # 记录请求开始
        logger.info(
            f"开始请求: {request.method} {request.url.path}",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "ip": ip,
                "user_agent": user_agent
            }
        )
        
        try:
            response = await call_next(request)
            process_time = (time.time() - start_time) * 1000
            
            # 记录指标
            metrics.record_request(response.status_code, process_time)
            
            # 记录请求结束
            logger.info(
                f"完成请求: {request.method} {request.url.path} - {response.status_code}",
                extra={
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": response.status_code,
                    "duration_ms": round(process_time, 2),
                    "ip": ip
                }
            )
            
            response.headers["X-Request-ID"] = request_id
            return response
            
        except Exception as e:
            process_time = (time.time() - start_time) * 1000
            metrics.record_request(500, process_time)
            
            logger.error(
                f"请求发生异常: {str(e)}",
                extra={
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.url.path,
                    "duration_ms": round(process_time, 2),
                    "ip": ip
                },
                exc_info=True
            )
            return JSONResponse(
                status_code=500,
                content={"error": "Internal Server Error", "request_id": request_id}
            )

def create_app() -> FastAPI:
    app = FastAPI(
        title="OpenMeta",
        description="一个基于 PanSou 搜索的元数据聚合平台",
        version="1.1.0"
    )

    # 添加中间件 (注意顺序)
    app.add_middleware(RequestTracingMiddleware)
    
    # 速率限制中间件
    redis_config = {
        "host": settings.redis_host,
        "port": settings.redis_port,
        "password": settings.redis_password
    } if settings.redis_host else None
    
    app.add_middleware(
        RateLimitMiddleware, 
        limit=settings.rate_limit_per_minute,
        redis_config=redis_config
    )

    # CORS 配置
    origins = [o.strip() for o in settings.cors_allow_origins.split(",") if o.strip()]
    allow_origins = ["*"] if not origins or origins == ["*"] else origins

    app.add_middleware(
        CORSMiddleware,
        allow_origins=allow_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # 健康检查端点
    @app.get("/health", tags=["健康检查"])
    async def health_check(detail: bool = Query(False, description="是否显示详细信息")) -> dict[str, Any]:
        """
        健康检查端点
        - **detail**: True 返回详细监控指标
        """
        start_time = time.time()
        
        # 基础响应
        response = {
            "status": "ok",
            "service": "OpenMeta",
            "version": "1.1.0",
            "timestamp": datetime.now().isoformat()
        }
        
        if detail:
            # 1. 后端响应时间 (当前请求的简单计时)
            response["backend_latency_ms"] = round((time.time() - start_time) * 1000, 2)
            
            # 2. PanSou 连接状态
            tm = get_token_manager()
            response["pansou"] = tm.get_status()
            response["pansou"]["host"] = settings.pansou_host
            
            # 3. Redis 可用性 (如果配置了)
            if settings.redis_host:
                try:
                    import redis
                    r = redis.Redis(
                        host=settings.redis_host, 
                        port=settings.redis_port, 
                        password=settings.redis_password,
                        socket_timeout=0.5
                    )
                    response["redis"] = {"status": "ok" if r.ping() else "failed"}
                except Exception as e:
                    response["redis"] = {"status": "error", "message": str(e)}
            else:
                response["redis"] = {"status": "not_configured"}
                
            # 4. 内存使用
            process = psutil.Process(os.getpid())
            mem_info = process.memory_info()
            response["memory_mb"] = {
                "rss": round(mem_info.rss / (1024 * 1024), 2),
                "vms": round(mem_info.vms / (1024 * 1024), 2)
            }
            
            # 5. 请求统计
            response["metrics"] = metrics.get_stats()
            
        return response

    @app.get("/api/search", tags=["搜索"])
    async def search(
        request: Request,
        q: str = Query(..., min_length=1, max_length=100, description="搜索关键词"),
        page: int = Query(1, ge=1, le=100, description="页码")
    ) -> dict[str, Any]:
        request_id = getattr(request.state, "request_id", "unknown")
        
        try:
            result = await pansou_search(q)
            
            response = {
                "q": q,
                "page": page,
                "items": result.get("results", []),
                "provider": result.get("provider", "unknown"),
                "enabled": result.get("enabled", False),
                "request_id": request_id
            }
            
            if "error" in result:
                response["warning"] = result.get("error")
                
            return response
            
        except Exception as e:
            logger.error(f"搜索失败: {str(e)}", extra={"request_id": request_id}, exc_info=True)
            return {
                "q": q,
                "page": page,
                "items": [],
                "error": "搜索服务暂时不可用",
                "request_id": request_id
            }

    @app.get("/", include_in_schema=False)
    async def root():
        return JSONResponse(
            content={
                "message": "OpenMeta API",
                "version": "1.1.0",
                "endpoints": {
                    "health": "/health",
                    "search": "/api/search?q=关键词"
                }
            }
        )

    @app.on_event("startup")
    async def startup_event():
        logger.info("OpenMeta 应用启动")
        try:
            settings.validate()
            logger.info("✅ 环境变量验证通过")
        except ValueError as e:
            logger.error(f"❌ 环境变量验证失败: {e}")

    return app

app = create_app()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=settings.backend_host, port=settings.backend_port)

"""
OpenMeta FastAPI 主应用配置
支持本地开发、Docker 部署和 Vercel 无服务器部署
包含生产级日志系统、API 速率限制和监控健康检查
"""

from __future__ import annotations

import os
import time
import uuid
from typing import Any

import psutil
from fastapi import FastAPI, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .logging_config import logger, log_request_start, log_request_end, log_error
from .metrics import get_metrics_collector, record_request_metrics
from .services.pansou import pansou_search
from .settings import settings

# 全局速率限制存储
from collections import defaultdict, deque
import time as time_module

_rate_limit_storage = defaultdict(deque)

def check_rate_limit(client_ip: str, rate_limit_per_minute: int = 60) -> tuple[bool, int, int]:
    """检查速率限制"""
    now = time_module.time()
    window_seconds = 60
    
    # 清理过期请求
    window_start = now - window_seconds
    client_requests = _rate_limit_storage[client_ip]
    while client_requests and client_requests[0] < window_start:
        client_requests.popleft()
    
    # 检查是否超出限制
    if len(client_requests) >= rate_limit_per_minute:
        oldest_request = client_requests[0] if client_requests else now
        reset_time = int(oldest_request + window_seconds)
        remaining = 0
        return True, remaining, reset_time
    
    # 添加当前请求
    client_requests.append(now)
    remaining = rate_limit_per_minute - len(client_requests)
    reset_time = int(now + window_seconds)
    return False, remaining, reset_time

# 创建 FastAPI 应用
app = FastAPI(
    title="OpenMeta",
    description="一个基于 PanSou 搜索的元数据聚合平台",
    version="1.1.0"
)

# 配置 CORS
origins = [o.strip() for o in settings.cors_allow_origins.split(",") if o.strip()]
if origins == ["*"]:
    allow_origins = ["*"]
else:
    allow_origins = origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# 添加速率限制中间件
@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    """速率限制中间件"""
    # 跳过健康检查端点和监控端点
    if request.url.path in ['/health', '/docs', '/openapi.json', '/redoc', '/metrics']:
        return await call_next(request)
    
    # 获取客户端 IP
    client_ip = get_client_ip(request)
    
    # 检查速率限制
    rate_limit_per_minute = int(os.getenv('RATE_LIMIT_PER_MINUTE', '60'))
    is_limited, remaining, reset_time = check_rate_limit(client_ip, rate_limit_per_minute)
    
    # 如果超出限制，返回 429
    if is_limited:
        return JSONResponse(
            status_code=429,
            content={
                "error": "Too Many Requests",
                "message": f"请求过于频繁，请稍后再试。每分钟最多 {rate_limit_per_minute} 个请求",
                "limit": rate_limit_per_minute,
                "remaining": remaining,
                "reset_time": reset_time
            },
            headers={
                "X-RateLimit-Limit": str(rate_limit_per_minute),
                "X-RateLimit-Remaining": str(remaining),
                "X-RateLimit-Reset": str(reset_time),
                "Retry-After": str(reset_time - int(time_module.time()))
            }
        )
    
    # 正常处理请求
    response = await call_next(request)
    
    # 添加速率限制响应头
    response.headers["X-RateLimit-Limit"] = str(rate_limit_per_minute)
    response.headers["X-RateLimit-Remaining"] = str(remaining)
    response.headers["X-RateLimit-Reset"] = str(reset_time)
    
    return response

# 请求追踪中间件
@app.middleware("http")
async def request_tracking_middleware(request: Request, call_next):
    """请求追踪中间件，为每个请求分配唯一 ID"""
    request_id = str(uuid.uuid4())
    
    # 记录请求开始
    start_time = time.time()
    client_ip = get_client_ip(request)
    user_agent = request.headers.get("user-agent", "")
    
    log_request_start(request_id, request.method, str(request.url.path), client_ip, user_agent)
    
    # 添加 request_id 到请求状态
    request.state.request_id = request_id
    
    try:
        # 处理请求
        response = await call_next(request)
        
        # 记录请求结束
        duration_ms = (time.time() - start_time) * 1000
        log_request_end(request_id, request.method, str(request.url.path), 
                      response.status_code, duration_ms, client_ip)
        
        # 记录指标
        record_request_metrics(request.method, str(request.url.path), 
                             response.status_code, duration_ms)
        
        # 添加响应头
        response.headers["X-Request-ID"] = request_id
        
        return response
        
    except Exception as e:
        # 记录错误
        duration_ms = (time.time() - start_time) * 1000
        log_error(request_id, e, {"method": request.method, "path": str(request.url.path)})
        record_request_metrics(request.method, str(request.url.path), 500, duration_ms, str(e))
        
        # 返回错误响应
        return JSONResponse(
            status_code=500,
            content={
                "error": "Internal server error",
                "request_id": request_id,
                "message": "服务暂时不可用，请稍后重试"
            }
        )

def get_client_ip(request: Request) -> str:
    """获取客户端 IP 地址"""
    # 尝试从 X-Forwarded-For 头部获取（反向代理环境）
    forwarded_for = request.headers.get("x-forwarded-for")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    
    # 尝试从 X-Real-IP 头部获取
    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip
    
    # 最后使用客户端 IP
    client_ip = request.client.host if request.client else "unknown"
    return client_ip

# 健康检查端点
@app.get("/health", tags=["健康检查"])
async def health_check(request: Request, detail: bool = False) -> dict[str, Any]:
    """健康检查端点
    - detail: 是否返回详细信息（包含性能指标）
    """
    base_info = {
        "status": "ok",
        "service": "OpenMeta",
        "version": "1.1.0",
        "timestamp": time.time()
    }
    
    if not detail:
        # 简单模式
        base_info.update({
            "pansou_configured": bool(settings.pansou_host),
            "pansou_host": settings.pansou_host if settings.pansou_host else "not configured"
        })
        return base_info
    
    # 详细模式 - 获取完整监控信息
    try:
        metrics_collector = get_metrics_collector()
        metrics = metrics_collector.get_metrics()
        memory_info = metrics_collector.get_memory_usage()
        
        # 测试 PanSou 连接状态
        pansou_status = "unknown"
        try:
            # 简单的连接测试（不需要实际搜索）
            if settings.pansou_host:
                import httpx
                with httpx.Client() as client:
                    response = client.get(
                        f"{settings.pansou_host.rstrip('/')}/api/health", 
                        timeout=5.0
                    )
                    if response.status_code == 200:
                        pansou_status = "healthy"
                    else:
                        pansou_status = f"unhealthy ({response.status_code})"
            else:
                pansou_status = "not configured"
        except Exception:
            pansou_status = "connection_failed"
        
        # 获取 Redis 状态（同步方法）
        redis_status = metrics_collector.get_redis_status()
        
        # 系统信息
        cpu_percent = psutil.cpu_percent(interval=1)
        disk_usage = psutil.disk_usage('/')
        
        # 完整的健康检查响应
        detailed_info = {
            **base_info,
            "pansou": {
                "configured": bool(settings.pansou_host),
                "host": settings.pansou_host if settings.pansou_host else "not configured",
                "status": pansou_status,
                "user": settings.pansou_user if settings.pansou_user else "not configured"
            },
            "redis": redis_status,
            "performance": {
                **metrics,
                "memory": memory_info,
                "cpu_percent": cpu_percent,
                "disk_usage": {
                    "total_gb": round(disk_usage.total / 1024 / 1024 / 1024, 2),
                    "used_gb": round(disk_usage.used / 1024 / 1024 / 1024, 2),
                    "free_gb": round(disk_usage.free / 1024 / 1024 / 1024, 2),
                    "usage_percent": round((disk_usage.used / disk_usage.total) * 100, 2)
                }
            },
            "environment": {
                "log_level": settings.log_level,
                "cors_origins": settings.cors_allow_origins,
                "rate_limit_per_minute": os.getenv('RATE_LIMIT_PER_MINUTE', '60'),
                "redis_url": os.getenv('REDIS_URL', 'not configured')
            }
        }
        
        return detailed_info
        
    except Exception as e:
        # 如果详细模式失败，返回基本信息 + 错误
        error_info = {
            **base_info,
            "error": f"Failed to get detailed health info: {str(e)}",
            "detail_available": False
        }
        return error_info

# 主要搜索端点
@app.get("/api/search", tags=["搜索"])
async def search(
    request: Request,
    q: str = Query(..., min_length=1, max_length=100, description="搜索关键词"),
    page: int = Query(1, ge=1, le=100, description="页码")
) -> dict[str, Any]:
    """
    搜索端点
    - **q**: 搜索关键词（必需）
    - **page**: 页码（默认：1）
    """
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    # 使用结构化日志
    logger.info(
        f"搜索请求: q='{q}', page={page}", 
        extra={
            "request_id": request_id,
            "query": q,
            "page": page,
            "event": "search_request"
        }
    )
    
    try:
        # 记录 PanSou 请求开始
        from .metrics import record_pansou_metrics
        
        # 使用优化的 PanSou 搜索服务
        start_time = time.time()
        result = await pansou_search(q)
        duration_ms = (time.time() - start_time) * 1000
        
        # 记录 PanSou 指标
        success = "error" not in result and result.get("enabled", False)
        record_pansou_metrics(success, result.get("error"))
        
        # 标准化返回格式
        response = {
            "q": q,
            "page": page,
            "items": result.get("results", []),
            "provider": result.get("provider", "unknown"),
            "enabled": result.get("enabled", False),
            "response_time_ms": round(duration_ms, 2)
        }
        
        # 如果有错误信息，添加到响应中
        if "error" in result:
            response["warning"] = result.get("error", "搜索出现错误")
        
        # 如果服务未启用，添加提示信息
        if not result.get("enabled", False):
            response["warning"] = result.get("message", "搜索服务未配置")
        
        logger.info(
            f"搜索完成: q='{q}', 找到 {len(response.get('items', []))} 个结果, 耗时 {duration_ms:.2f}ms", 
            extra={
                "request_id": request_id,
                "query": q,
                "results_count": len(response.get('items', [])),
                "duration_ms": round(duration_ms, 2),
                "success": success,
                "event": "search_completed"
            }
        )
        return response
        
    except Exception as e:
        # 记录错误
        logger.error(
            f"搜索失败: {str(e)}", 
            extra={
                "request_id": request_id,
                "query": q,
                "error_type": type(e).__name__,
                "error_message": str(e),
                "event": "search_error"
            }
        )
        
        # 记录 PanSou 指标
        from .metrics import record_pansou_metrics
        record_pansou_metrics(False, str(e))
        
        return {
            "q": q,
            "page": page,
            "items": [],
            "error": "搜索服务暂时不可用",
            "details": str(e) if os.getenv("DEBUG") else "Internal server error",
            "provider": "error",
            "enabled": False
        }

# 根路径重定向到搜索页面
@app.get("/", include_in_schema=False)
async def root():
    """根路径重定向到前端页面"""
    return JSONResponse(
        content={
            "message": "OpenMeta API",
            "version": "1.1.0",
            "endpoints": {
                "health": "/health",
                "health_detailed": "/health?detail=true",
                "search": "/api/search?q=关键词&page=1"
            },
            "docs": "/docs",
            "pansou_configured": bool(settings.pansou_host)
        }
    )

# 错误处理
@app.exception_handler(404)
async def not_found_handler(request, exc):
    """404 错误处理"""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    logger.warning(
        f"404 错误: {request.method} {request.url.path}", 
        extra={
            "request_id": request_id,
            "method": request.method,
            "path": str(request.url.path),
            "status_code": 404,
            "event": "not_found"
        }
    )
    
    return JSONResponse(
        status_code=404,
        content={
            "error": "Endpoint not found",
            "path": str(request.url.path),
            "method": request.method,
            "request_id": request_id
        }
    )

@app.exception_handler(500)
async def internal_error_handler(request, exc):
    """500 错误处理"""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    logger.error(
        f"内部服务器错误: {exc}", 
        extra={
            "request_id": request_id,
            "method": request.method,
            "path": str(request.url.path),
            "error_type": type(exc).__name__,
            "error_message": str(exc),
            "status_code": 500,
            "event": "internal_error"
        },
        exc_info=True
    )
    
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "message": "服务暂时不可用，请稍后重试",
            "request_id": request_id
        }
    )

# 应用启动事件
@app.on_event("startup")
async def startup_event():
    """应用启动时的初始化"""
    logger.info(
        "OpenMeta 应用启动", 
        extra={
            "event": "app_startup",
            "version": "1.1.0",
            "features": ["logging", "rate_limiting", "monitoring", "health_checks"]
        }
    )

    # 验证必要的环境变量
    try:
        settings.validate()
        logger.info(
            "✅ 所有必要的环境变量已配置", 
            extra={
                "event": "config_validated",
                "pansou_host": settings.pansou_host,
                "pansou_user": settings.pansou_user,
                "log_level": settings.log_level,
                "cors_origins": settings.cors_allow_origins
            }
        )
    except ValueError as e:
        logger.error(
            f"环境变量配置错误: {e}", 
            extra={
                "event": "config_error",
                "error": str(e)
            }
        )
        logger.warning("⚠️  搜索功能将不可用，请配置必要的环境变量")

# 应用关闭事件
@app.on_event("shutdown")
async def shutdown_event():
    """应用关闭时的清理"""
    logger.info(
        "OpenMeta 应用关闭", 
        extra={
            "event": "app_shutdown"
        }
    )

# 监控端点 - 暴露指标
@app.get("/metrics", tags=["监控"])
async def get_metrics():
    """获取监控指标"""
    metrics_collector = get_metrics_collector()
    return metrics_collector.get_metrics()

# 为了兼容性，提供 create_app 函数
def create_app() -> FastAPI:
    """创建 FastAPI 应用的工厂函数"""
    return app

# 导出
__all__ = ["app", "create_app"]

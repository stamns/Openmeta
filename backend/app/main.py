"""
OpenMeta FastAPI 主应用配置
支持生产级日志、速率限制、监控和健康检查
支持本地开发、Docker 部署和 Vercel 无服务器部署
包含生产级日志系统、请求追踪和速率限制
"""

from __future__ import annotations

import asyncio
import os
import time
import uuid
import psutil
from datetime import datetime
from typing import Any, Optional

from fastapi import FastAPI, Request, Query, Depends
from typing import Any, Callable

from fastapi import FastAPI, Query, Request, Response
from fastapi import FastAPI
from fastapi import FastAPI, Query
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
from .logging_config import setup_logging, log_request, log_error
from .middleware.rate_limit import RateLimitMiddleware
from .metrics import get_metrics_collector, record_request
from .services.pansou import pansou_search
from .settings import settings

# 配置结构化日志
logger = setup_logging()

# 初始化指标收集器
metrics_collector = get_metrics_collector()


class RequestTracingMiddleware(BaseHTTPMiddleware):
    """请求追踪中间件，为每个请求分配唯一 ID 并记录日志"""
    
    async def dispatch(self, request: Request, call_next):
        # 生成请求 ID
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        
        # 记录请求开始
        start_time = time.time()
        client_ip = self._get_client_ip(request)
        user_agent = request.headers.get("user-agent", "")
        
        logger.info("请求开始处理", extra={
            "request_id": request_id,
            "method": request.method,
            "path": str(request.url.path),
            "client_ip": client_ip,
            "user_agent": user_agent
        })
        
        try:
            # 处理请求
            response = await call_next(request)
            
            # 计算处理时间
            duration_ms = (time.time() - start_time) * 1000
            
            # 记录成功响应
            log_request(
                logger=logger,
                request_id=request_id,
                method=request.method,
                path=str(request.url.path),
                client_ip=client_ip,
                user_agent=user_agent,
                status_code=response.status_code,
                duration_ms=duration_ms
            )
            
            # 记录指标
            record_request(
                method=request.method,
                path=str(request.url.path),
                status_code=response.status_code,
                duration_ms=duration_ms,
                client_ip=client_ip,
                user_agent=user_agent,
                error=None
            )
            
            return response
            
        except Exception as e:
            # 计算处理时间
            duration_ms = (time.time() - start_time) * 1000
            
            # 记录错误
            log_error(
                logger=logger,
                request_id=request_id,
                error=e,
                context={
                    "method": request.method,
                    "path": str(request.url.path),
                    "client_ip": client_ip,
                    "user_agent": user_agent,
                    "duration_ms": duration_ms
                }
            )
            
            # 记录错误指标
            record_request(
                method=request.method,
                path=str(request.url.path),
                status_code=500,
                duration_ms=duration_ms,
                client_ip=client_ip,
                user_agent=user_agent,
                error=e
            )
            
            # 重新抛出异常
            raise
    
    def _get_client_ip(self, request: Request) -> str:
        """获取客户端 IP"""
        # 尝试从 X-Forwarded-For 头获取
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()
        
        # 回退到客户端 IP
        return request.client.host if request.client else "unknown"


def create_app() -> FastAPI:
    """创建并配置 FastAPI 应用的工厂函数"""
    app = FastAPI(
        title="OpenMeta",
        description="一个基于 PanSou 搜索的元数据聚合平台",
        version="1.0.0"
    )

    # 配置 CORS
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
    async def health_check() -> dict[str, str]:
        """健康检查端点"""
        return {
            "status": "ok",
            "service": "OpenMeta",
            "version": "1.0.0",
            "pansou_host": settings.pansou_host
        }

    # 包含搜索路由
    app.include_router(search_router, prefix="/api", tags=["搜索"])

    # 根路径
    @app.get("/", include_in_schema=False)
    async def root():
        """根路径重定向到前端页面信息"""
        return JSONResponse(
            content={
                "message": "OpenMeta API",
                "version": "1.0.0",
                "endpoints": {
                    "health": "/health",
                    "search": "/api/search?q=关键词"
                },
                "docs": "/docs",
                "pansou_configured": bool(settings.pansou_host)
            }
        )

    # 错误处理
    @app.exception_handler(404)
    async def not_found_handler(request, exc):
        """404 错误处理"""
        return JSONResponse(
            status_code=404,
            content={
                "error": "Endpoint not found",
                "path": str(request.url.path),
                "method": request.method
            }
        )

    @app.exception_handler(500)
    async def internal_error_handler(request, exc):
        """500 错误处理"""
        logger.error(f"内部服务器错误: {exc}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "Internal server error",
                "message": "服务暂时不可用，请稍后重试"
            }
        )

    # 应用启动事件
    @app.on_event("startup")
    async def startup_event():
        """应用启动时的初始化"""
        logger.info("OpenMeta 应用启动")
        # 验证必要的环境变量
        try:
            settings.validate()
            logger.info("✅ 所有必要的环境变量已配置")
        except ValueError as e:
            logger.error(f"⚠️ 环境变量配置错误: {e}")
            logger.warning("⚠️ 搜索功能将不可用，请配置必要的环境变量")

    return app

# 创建应用实例
app = create_app()

# 导出
__all__ = ["app", "create_app"]
# 创建 FastAPI 应用
app = FastAPI(
    title="OpenMeta",
    description="一个基于 PanSou 搜索的元数据聚合平台",
    version="1.0.0"
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

# 添加请求追踪中间件和速率限制中间件
app.add_middleware(RequestTracingMiddleware)
app.add_middleware(RateLimitMiddleware)

# 健康检查端点
@app.get("/health", tags=["健康检查"])
async def health_check(detail: bool = Query(False, description="是否返回详细信息")):
    """健康检查端点"""
    
    base_info = {
        "status": "ok",
        "service": "OpenMeta",
        "version": "1.0.0",
        "timestamp": time.time(),
        "pansou_configured": bool(settings.pansou_host)
    }
    
    if not detail:
        # 基础信息
        return base_info
    
    # 详细信息
    from .metrics import SystemMetrics
    
    # 检查 PanSou 连接状态
    pansou_status = "unavailable"
    token_info = None
    
    try:
        if settings.pansou_host:
            # 简单的连接测试
            from .services.pansou import _token_manager
            if _token_manager.token and _token_manager.is_token_valid():
                pansou_status = "connected"
                token_info = {
                    "token_expires_at": _token_manager.token_exp,
                    "time_remaining_seconds": max(0, _token_manager.token_exp - time.time())
                }
            else:
                pansou_status = "disconnected"
    except Exception as e:
        logger.warning(f"检查 PanSou 状态失败: {e}")
        pansou_status = "error"
    
    # 系统指标
    try:
        memory_usage = SystemMetrics.get_memory_usage()
        cpu_info = SystemMetrics.get_cpu_info()
        disk_usage = SystemMetrics.get_disk_usage()
    except Exception as e:
        logger.warning(f"获取系统指标失败: {e}")
        memory_usage = {"error": str(e)}
        cpu_info = {"error": str(e)}
        disk_usage = {"error": str(e)}
    
    # 应用指标
    metrics_summary = metrics_collector.get_metrics_summary()
    
    # 计算后端响应时间（简单测试）
    backend_start = time.time()
    backend_status = "ok"
    try:
        # 模拟简单的后端检查
        await asyncio.sleep(0.001)  # 1ms 模拟检查时间
        backend_duration = (time.time() - backend_start) * 1000
    except Exception as e:
        backend_status = "error"
        backend_duration = 0
    
    detailed_info = {
        **base_info,
        "backend": {
            "status": backend_status,
            "response_time_ms": round(backend_duration, 2)
        },
        "pansou": {
            "status": pansou_status,
            "host": settings.pansou_host,
            "token_info": token_info
        },
        "system": {
            "memory": memory_usage,
            "cpu": cpu_info,
            "disk": disk_usage
        },
        "metrics": metrics_summary
    }
    
    return detailed_info


# 主要搜索端点
@app.get("/api/search", tags=["搜索"])
async def search(
    q: str = Query(..., min_length=1, max_length=100, description="搜索关键词"),
    page: int = Query(1, ge=1, le=100, description="页码")
) -> dict[str, Any]:
    """
    搜索端点
    - **q**: 搜索关键词（必需）
    - **page**: 页码（默认：1）
    """
    # 获取当前请求的 request_id
    # 这里我们创建一个新的 request_id，因为中间件可能还没设置
    request_id = str(uuid.uuid4())
    
    logger.info("搜索请求开始", extra={
        "request_id": request_id,
        "query": q,
        "page": page
    })
    
    try:
        # 使用优化的 PanSou 搜索服务
        result = await pansou_search(q)
        
        # 标准化返回格式
        response = {
            "q": q,
            "page": page,
            "items": result.get("results", []),
            "provider": result.get("provider", "unknown"),
            "enabled": result.get("enabled", False)
        }
        
        # 如果有错误信息，添加到响应中
        if "error" in result:
            response["warning"] = result.get("error", "搜索出现错误")
        
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
        logger.info("搜索请求完成", extra={
            "request_id": request_id,
            "query": q,
            "result_count": len(response.get("items", [])),
            "enabled": response["enabled"]
        })
        
        return response
        
    except Exception as e:
        logger.error("搜索请求失败", extra={
            "request_id": request_id,
            "query": q,
            "error": str(e)
        }, exc_info=True)
        
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
            "version": "1.0.0",
            "endpoints": {
                "health": "/health",
                "health_detail": "/health?detail=true",
                "search": "/api/search?q=关键词&page=1"
            },
            "docs": "/docs",
            "pansou_configured": bool(settings.pansou_host)
        }
    )


# 错误处理
@app.exception_handler(404)
async def not_found_handler(request: Request, exc):
    """404 错误处理"""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    logger.warning("请求的资源不存在", extra={
        "request_id": request_id,
        "path": str(request.url.path),
        "method": request.method
    })
    
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
async def internal_error_handler(request: Request, exc):
    """500 错误处理"""
    request_id = getattr(request.state, 'request_id', 'unknown')
    
    logger.error("内部服务器错误", extra={
        "request_id": request_id,
        "error": str(exc)
    }, exc_info=True)
    
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
    logger.info("🚀 OpenMeta 应用启动", extra={
        "version": "1.0.0",
        "log_level": os.getenv("LOG_LEVEL", "INFO")
    })

    # 验证必要的环境变量
    try:
        settings.validate()
        logger.info("✅ 所有必要的环境变量已配置", extra={
            "pansou_host": settings.pansou_host,
            "pansou_user": settings.pansou_user,
            "log_level": settings.log_level,
            "cors_origins": settings.cors_allow_origins
        })
    except ValueError as e:
        logger.error("环境变量配置错误", extra={
            "error": str(e)
        })
        logger.warning("⚠️ 搜索功能将不可用，请配置必要的环境变量")


# 应用关闭事件
@app.on_event("shutdown")
async def shutdown_event():
    """应用关闭时的清理"""
    logger.info("👋 OpenMeta 应用关闭", extra={
        "uptime_seconds": time.time() - app.state.start_time if hasattr(app.state, 'start_time') else 0
    })


# 为了兼容性，提供 create_app 函数
def create_app() -> FastAPI:
    """创建 FastAPI 应用的工厂函数"""
    return app


# 导出
__all__ = ["app", "create_app"]
def create_app() -> FastAPI:
    """创建 FastAPI 应用的工厂函数"""
    app = FastAPI(
        title="OpenMeta",
        description="一个基于 PanSou 搜索的元数据聚合平台",
        version="1.0.0"
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
            
    async def health_check() -> dict[str, str]:
        """健康检查端点"""
        return {
            "status": "ok",
            "service": "OpenMeta",
            "version": "1.0.0",
            "pansou_host": settings.pansou_host
        }

    # 主要搜索端点
    @app.get("/api/search", tags=["搜索"])
    async def search(
        q: str = Query(..., min_length=1, max_length=100, description="搜索关键词"),
        page: int = Query(1, ge=1, le=100, description="页码")
    ) -> dict[str, Any]:
        """
        搜索端点
        - **q**: 搜索关键词（必需）
        - **page**: 页码（默认：1）
        """
        logger.info(f"搜索请求: q='{q}', page={page}")

        try:
            # 使用优化的 PanSou 搜索服务
            result = await pansou_search(q)

            # 标准化返回格式
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
                "enabled": result.get("enabled", False)
            }

            # 如果有错误信息，添加到响应中
            if "error" in result:
                response["warning"] = result.get("error", "搜索出现错误")

            # 如果服务未启用，添加提示信息
            if not result.get("enabled", False):
                response["warning"] = result.get("message", "搜索服务未配置")

            logger.info(f"搜索完成: q='{q}', 找到 {len(response.get('items', []))} 个结果")
            return response

        except Exception as e:
            logger.error(f"搜索失败: {str(e)}", exc_info=True)
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
                "version": "1.0.0",
                "endpoints": {
                    "health": "/health",
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
        return JSONResponse(
            status_code=404,
            content={
                "error": "Endpoint not found",
                "path": str(request.url.path),
                "method": request.method
            }
        )

    @app.exception_handler(500)
    async def internal_error_handler(request, exc):
        """500 错误处理"""
        logger.error(f"内部服务器错误: {exc}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "Internal server error",
                "message": "服务暂时不可用，请稍后重试"
            }
        )

    # 应用启动事件
    @app.on_event("startup")
    async def startup_event():
        """应用启动时的初始化"""
        logger.info("OpenMeta 应用启动")

        # 验证必要的环境变量
        try:
            settings.validate()
            logger.info("✅ 所有必要的环境变量已配置")
            logger.info(f"PanSou 主机: {settings.pansou_host}")
            logger.info(f"PanSou 用户: {settings.pansou_user}")
            logger.info(f"日志级别: {settings.log_level}")
            logger.info(f"CORS 允许源: {settings.cors_allow_origins}")
        except ValueError as e:
            logger.error(f"环境变量配置错误: {e}")
            logger.warning("⚠️  搜索功能将不可用，请配置必要的环境变量")

    # 应用关闭事件
    @app.on_event("shutdown")
    async def shutdown_event():
        """应用关闭时的清理"""
        logger.info("OpenMeta 应用关闭")

    return app


# 创建应用实例
app = create_app()

# 导出
__all__ = ["app", "create_app"]
    return app

# 导出
__all__ = ["app", "create_app"]


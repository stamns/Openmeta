"""
OpenMeta FastAPI 主应用配置
支持本地开发、Docker 部署和 Vercel 无服务器部署
"""

from __future__ import annotations

import logging
import os
from typing import Any

from fastapi import FastAPI
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .services.pansou import pansou_search
from .routers.search import router as search_router
from .settings import settings

# 配置日志
log_level = getattr(logging, settings.log_level.upper(), logging.INFO)
logging.basicConfig(
    level=log_level,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("openmeta")

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


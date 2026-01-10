"""
Vercel 无服务器函数入口点
支持 FastAPI 应用在 Vercel 平台上运行
"""

from __future__ import annotations

import sys
import os
from pathlib import Path

# 确保正确的模块路径
BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[2]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

# 延迟导入以优化冷启动
def get_app():
    """
    延迟导入 FastAPI 应用以减少冷启动时间
    使用 lazy loading 方式，只在首次请求时导入重型依赖
    """
    try:
        from backend.app.main import app
        return app
    except Exception as e:
        # 如果导入失败，返回一个基本的错误处理应用
        from fastapi import FastAPI
        from fastapi.responses import JSONResponse

        error_app = FastAPI(title="OpenMeta - Error")

        @error_app.get("/api/search")
        async def error_endpoint():
            return JSONResponse(
                status_code=503,
                content={
                    "error": "Service temporarily unavailable",
                    "details": str(e),
                    "q": "",
                    "page": 1,
                    "items": []
                }
            )

        @error_app.get("/health")
        async def health_error():
            return JSONResponse(
                status_code=503,
                content={
                    "status": "error",
                    "message": "Application failed to initialize",
                    "details": str(e)
                }
            )

        return error_app

# Mangum handler for Vercel - 在模块级别只导入 mangum，不立即初始化
try:
    from mangum import Mangum
    # 初始化 handler，使用延迟导入的应用
    handler = Mangum(get_app())
except ImportError:
    # 如果 mangum 不可用，提供一个 fallback
    handler = None

# 为了兼容性，导出 app 和 handler
app = get_app()
__all__ = ["app", "handler"]

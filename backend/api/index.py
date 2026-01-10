"""
Vercel 无服务器函数入口点
支持 FastAPI 应用在 Vercel 平台上运行
"""

from __future__ import annotations

import sys
import os
from pathlib import Path

# 设置正确的模块路径
BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# 延迟导入以优化冷启动
def get_app():
    """延迟导入 FastAPI 应用以减少冷启动时间"""
    try:
        from main import app
        return app
    except Exception as e:
        # 如果导入失败，返回一个基本的错误处理应用
        from fastapi import FastAPI
        from fastapi.responses import JSONResponse
        from fastapi.middleware.cors import CORSMiddleware

        error_app = FastAPI(title="OpenMeta - Error")

        error_app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["GET", "POST", "OPTIONS"],
            allow_headers=["*"],
        )

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
        async def health_endpoint():
            return JSONResponse(
                status_code=503,
                content={
                    "status": "error",
                    "error": "Service initialization failed"
                }
            )

        return error_app

# 获取 FastAPI 应用
app = get_app()

# Mangum handler for Vercel
from mangum import Mangum

handler = Mangum(app)

# 导出
__all__ = ["app", "handler"]

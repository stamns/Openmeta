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

        return error_app

# Vercel 入口点
app = get_app()

# 为了向后兼容，导出 app
__all__ = ["app"]

# Mangum handler for Vercel
from mangum import Mangum

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.app.main import app  # noqa: E402

handler = Mangum(app)

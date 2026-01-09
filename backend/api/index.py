"""
Vercel 无服务器函数入口点
支持 FastAPI 应用在 Vercel 平台上运行
"""

import os
import sys

BACKEND_ROOT = os.path.dirname(os.path.dirname(__file__))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

from mangum import Mangum

from openmeta.main import app

handler = Mangum(app)
from __future__ import annotations

import sys
import os
from pathlib import Path

# 确保正确的模块路径
BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# Vercel 环境变量检测和配置
if os.getenv("VERCEL"):
    # 在 Vercel 环境中，使用环境变量而非 .env 文件
    os.environ.setdefault("PANSOU_HOST", os.getenv("PANSOU_HOST", "http://112.124.53.114:8888"))
    os.environ.setdefault("PANSOU_USER", os.getenv("PANSOU_USER", "admin"))
    os.environ.setdefault("PANSOU_PWD", os.getenv("PANSOU_PWD", ""))

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
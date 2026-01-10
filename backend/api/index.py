"""
Vercel 无服务器函数入口点
支持 FastAPI 应用在 Vercel 平台上运行
"""

from __future__ import annotations

import sys
from pathlib import Path

# 确保正确的模块路径
BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[2]

for path in [str(BACKEND_DIR), str(REPO_ROOT)]:
    if path not in sys.path:
        sys.path.insert(0, path)

# 延迟导入以优化冷启动
def get_handler():
    """延迟导入 FastAPI 应用并返回 Mangum 处理器"""
    try:
        from backend.app.main import app
        from mangum import Mangum
        return Mangum(app, lifespan="off")
    except Exception as e:
        # 导入失败时返回错误处理器
        return create_error_handler(e)


def create_error_handler(error: Exception):
    """创建错误处理应用"""
    from fastapi import FastAPI
    from fastapi.responses import JSONResponse
    from mangum import Mangum

    error_app = FastAPI(title="OpenMeta - Error")

    @error_app.get("/health")
    async def health():
        return JSONResponse(
            status_code=503,
            content={
                "status": "error",
                "service": "OpenMeta",
                "error": "Service temporarily unavailable",
                "details": str(error) if hasattr(error, '__str__') else "Unknown error"
            }
        )

    @error_app.get("/api/search")
    async def search():
        return JSONResponse(
            status_code=503,
            content={
                "error": "Service temporarily unavailable",
                "details": str(error) if hasattr(error, '__str__') else "Unknown error",
                "q": "",
                "page": 1,
                "items": []
            }
        )

    return Mangum(error_app, lifespan="off")


# 创建 handler
handler = get_handler()

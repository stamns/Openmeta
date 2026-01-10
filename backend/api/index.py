"""
Vercel Serverless Function Entry Point
Supports FastAPI app running on Vercel.
"""

import sys
import os
from pathlib import Path

# Optimize path for module resolution
current_dir = Path(__file__).resolve().parent
backend_dir = current_dir.parent
repo_root = backend_dir.parent

if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))
if str(repo_root) not in sys.path:
    sys.path.insert(0, str(repo_root))

# Set environment variables for Vercel if needed
os.environ["VERCEL_DEPLOYMENT"] = "1"

def get_application():
    """
    Deferred import of the FastAPI application to reduce cold start time.
    """
    try:
        # Import the main FastAPI app
        from backend.app.main import app as fastapi_app
        return fastapi_app
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
        # Fallback error application
        from fastapi import FastAPI
        from fastapi.responses import JSONResponse
        
        error_app = FastAPI(title="OpenMeta - Startup Error")
        
        @error_app.get("/api/{rest_of_path:path}")
        @error_app.get("/health")
        async def startup_error(rest_of_path: str = None):
            return JSONResponse(
                status_code=503,
                content={
                    "error": "Application failed to start",
                    "details": str(e),
                    "context": "Vercel Serverless Function"
                }
            )
        return error_app

# Create the app instance for Vercel
app = get_application()

# Optional: Mangum wrapper
# Although Vercel supports ASGI natively, some configurations might prefer Mangum
from mangum import Mangum
handler = Mangum(app)

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

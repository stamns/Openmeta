"""
Vercel Serverless Function Entry Point
Supports FastAPI app running on Vercel.
"""

import sys
from pathlib import Path

# 设置正确的模块路径
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
        return error_app

# Create the app instance for Vercel
app = get_application()

# Optional: Mangum wrapper
# Although Vercel supports ASGI natively, some configurations might prefer Mangum
from mangum import Mangum
handler = Mangum(app)

handler = Mangum(app)

# 导出
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

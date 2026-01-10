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

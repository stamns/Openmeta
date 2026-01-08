from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

web_root = Path(__file__).resolve().parent

if not os.getenv("VERCEL"):
    try:
        from dotenv import load_dotenv

        load_dotenv(web_root / ".env")
        load_dotenv(web_root / ".env.local", override=True)
    except Exception:  # noqa: BLE001
        pass

from app.main import create_app as create_api_app  # noqa: E402

api_app = create_api_app()

app = FastAPI(title="OpenMeta")
app.mount("/api", api_app)

index_file = web_root / "index.html"
assets_dir = web_root / "assets"

if assets_dir.is_dir():
    app.mount("/assets", StaticFiles(directory=str(assets_dir)), name="assets")

if index_file.is_file():

    @app.get("/", include_in_schema=False)
    async def index():
        return FileResponse(index_file)

    @app.get("/{full_path:path}", include_in_schema=False)
    async def spa_fallback(full_path: str):
        requested = web_root / full_path
        if requested.is_file():
            return FileResponse(requested)
        return FileResponse(index_file)


__all__ = ["app"]

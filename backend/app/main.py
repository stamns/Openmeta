from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .routers.search import router as search_router
from .settings import settings


def create_app() -> FastAPI:
    logging.basicConfig(level=getattr(logging, settings.log_level.upper(), logging.INFO))

    app = FastAPI(title="OpenMeta", version="1.0.0")

    origins = [o.strip() for o in settings.cors_allow_origins.split(",") if o.strip()]
    allow_origins = ["*"] if not origins or origins == ["*"] else origins

    app.add_middleware(
        CORSMiddleware,
        allow_origins=allow_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/health", tags=["health"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(search_router, prefix="/api", tags=["search"])
    return app


app = create_app()

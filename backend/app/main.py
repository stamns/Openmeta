from __future__ import annotations

import logging

from fastapi import FastAPI

from app.routers.search import router as search_router

logger = logging.getLogger("openmeta")


def create_app() -> FastAPI:
    logging.basicConfig(level=logging.INFO)

    app = FastAPI(title="OpenMeta")
    app.include_router(search_router)
    return app


app = create_app()

from __future__ import annotations

import logging

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware

from .pansou_client import search_pansou
from .settings import settings


logging.basicConfig(level=getattr(logging, settings.log_level.upper(), logging.INFO))

app = FastAPI(title="OpenMeta", version="0.1.0")

origins = [o.strip() for o in settings.cors_allow_origins.split(",") if o.strip()]
if origins == ["*"]:
    allow_origins = ["*"]
else:
    allow_origins = origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/search")
async def search(q: str = Query(min_length=1), page: int = 1) -> dict:
    return await search_pansou(q, page=page)

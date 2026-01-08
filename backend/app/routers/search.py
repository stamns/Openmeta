from __future__ import annotations

from fastapi import APIRouter, Query

from app.services.pansou import pansou_search

router = APIRouter()


@router.get("/search")
async def search(q: str = Query(..., min_length=1, description="Search query")):
    return await pansou_search(q)


@router.get("/health")
async def health():
    return {"ok": True}

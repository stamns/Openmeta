from fastapi import APIRouter, Query

from openmeta.services.pansou import search as pansou_search

router = APIRouter(tags=["search"])


@router.get("/search")
async def search(q: str = Query(..., min_length=1), limit: int = Query(20, ge=1, le=50)):
    return await pansou_search(q=q, limit=limit)

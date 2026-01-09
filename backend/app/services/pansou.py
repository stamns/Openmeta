from __future__ import annotations

from functools import lru_cache
from typing import Any

from ..settings import settings


async def pansou_search(query: str) -> dict[str, Any]:
    """Search via PanSou.

    If PANSOU_HOST is not configured, returns an empty result set.

    Cold start optimization:
    - httpx is imported lazily
    - client is cached across invocations (best effort, depends on runtime reuse)
    """

    if not settings.pansou_host:
        return {
            "provider": "pansou",
            "enabled": False,
            "query": query,
            "results": [],
            "message": "PANSOU_HOST is not configured",
        }

    base_url = settings.pansou_host.rstrip("/")
    url = f"{base_url}/api/search"

    auth = None
    if settings.pansou_user and settings.pansou_pwd:
        auth = (settings.pansou_user, settings.pansou_pwd)

    client = _get_async_client()
    try:
        resp = await client.get(
            url,
            params={"q": query},
            auth=auth,
            timeout=float(settings.search_timeout),
        )
        resp.raise_for_status()
        data = resp.json()
        return {
            "provider": "pansou",
            "enabled": True,
            "query": query,
            "results": data,
        }
    except Exception as exc:  # noqa: BLE001
        return {
            "provider": "pansou",
            "enabled": True,
            "query": query,
            "results": [],
            "error": str(exc),
        }


@lru_cache(maxsize=1)
def _get_async_client():
    import httpx

    limits = httpx.Limits(max_connections=20, max_keepalive_connections=10)
    return httpx.AsyncClient(limits=limits, headers={"User-Agent": "openmeta/1.0"})

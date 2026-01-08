from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from typing import Any


@dataclass(frozen=True)
class PanSouConfig:
    host: str | None
    user: str | None
    password: str | None


@lru_cache(maxsize=1)
def get_pansou_config() -> PanSouConfig:
    return PanSouConfig(
        host=os.getenv("PANSOU_HOST"),
        user=os.getenv("PANSOU_USER"),
        password=os.getenv("PANSOU_PWD"),
    )


async def pansou_search(query: str) -> dict[str, Any]:
    """Search via PanSou.

    Cold start optimization:
    - httpx is imported lazily
    - client is cached across invocations (best effort, depends on runtime reuse)

    If PANSOU_HOST is not configured, returns an empty result set.
    """

    cfg = get_pansou_config()
    if not cfg.host:
        return {
            "provider": "pansou",
            "enabled": False,
            "query": query,
            "results": [],
            "message": "PANSOU_HOST is not configured",
        }

    import httpx

    base_url = cfg.host.rstrip("/")
    url = f"{base_url}/api/search"

    auth = None
    if cfg.user and cfg.password:
        auth = (cfg.user, cfg.password)

    client = _get_async_client()
    try:
        resp = await client.get(url, params={"q": query}, auth=auth, timeout=10.0)
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

import os
import time
from typing import Any


def _get_env(name: str) -> str | None:
    value = os.getenv(name)
    if value is None:
        return None
    value = value.strip()
    return value or None


async def _get_client():
    import httpx

    if not hasattr(_get_client, "_client"):
        timeout = httpx.Timeout(connect=3.0, read=5.0, write=5.0, pool=5.0)
        _get_client._client = httpx.AsyncClient(timeout=timeout)
    return _get_client._client


async def search(q: str, limit: int = 20) -> dict[str, Any]:
    started = time.perf_counter()

    host = _get_env("PANSOU_HOST")
    user = _get_env("PANSOU_USER")
    pwd = _get_env("PANSOU_PWD")

    if not host:
        return {
            "query": q,
            "limit": limit,
            "source": "mock",
            "items": [{"title": f"Result {i + 1} for {q}", "url": None} for i in range(min(limit, 5))],
            "took_ms": int((time.perf_counter() - started) * 1000),
        }

    try:
        client = await _get_client()
        headers = {"Accept": "application/json"}
        auth = (user, pwd) if user and pwd else None

        resp = await client.get(
            host.rstrip("/") + "/search",
            params={"q": q, "limit": limit},
            headers=headers,
            auth=auth,
        )
        resp.raise_for_status()

        data = resp.json()
        return {
            "query": q,
            "limit": limit,
            "source": "pansou",
            "data": data,
            "took_ms": int((time.perf_counter() - started) * 1000),
        }
    except Exception as exc:
        return {
            "query": q,
            "limit": limit,
            "source": "fallback",
            "error": str(exc),
            "items": [{"title": f"Result {i + 1} for {q}", "url": None} for i in range(min(limit, 5))],
            "took_ms": int((time.perf_counter() - started) * 1000),
        }

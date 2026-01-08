from __future__ import annotations

from typing import Any

import httpx

from .settings import settings


def _normalize_host(host: str) -> str:
    return host.rstrip("/")


async def search_pansou(q: str, *, page: int = 1) -> dict[str, Any]:
    base = _normalize_host(settings.pansou_host)

    candidates = [
        (f"{base}/api/search", {"q": q, "page": page}),
        (f"{base}/search", {"q": q, "page": page}),
    ]

    auth = (settings.pansou_user, settings.pansou_pwd)
    timeout = httpx.Timeout(settings.search_timeout)

    async with httpx.AsyncClient(timeout=timeout) as client:
        last_error: str | None = None
        for url, params in candidates:
            try:
                resp = await client.get(url, params=params, auth=auth)
                if resp.status_code >= 400:
                    last_error = f"{resp.status_code} {resp.text[:200]}"
                    continue
                data = resp.json()
                if isinstance(data, dict):
                    return data
                return {"items": data}
            except Exception as e:  # noqa: BLE001
                last_error = str(e)
                continue

    return {
        "q": q,
        "page": page,
        "items": [],
        "warning": "PanSou 未响应，已降级返回空结果",
        "error": last_error,
    }

"""
PanSou 搜索服务 - 带 Token 认证和并发控制

改进：
1. Token 过期管理（动态读取 expires_in，提前 60 秒刷新）
2. 并发安全（使用 asyncio.Lock 和 Double-check locking）
3. 搜索超时配置（使用环境变量）
4. 友好的错误处理
5. 集成监控指标收集
"""

from __future__ import annotations

import asyncio
import time
from functools import lru_cache
from typing import Any

from ..settings import settings


# 全局 token 管理
class TokenManager:
    """Token 管理器，支持并发安全的登录和刷新"""

    def __init__(self):
        self.token: str | None = None
        self.token_exp: float = 0.0
        self._login_lock = asyncio.Lock()

    def is_token_valid(self) -> bool:
        """检查 token 是否有效（提前 60 秒过期以留安全余量）"""
        if not self.token:
            return False
        # 提前 60 秒刷新，避免在请求过程中过期
        return time.time() < self.token_exp - 60

    async def ensure_token(self) -> bool:
        """
        确保有有效的 token，使用 Double-check locking 模式避免并发重复登录
        返回 True 表示有有效 token，False 表示登录失败
        """
        # 第一次检查（不上锁，快速路径）
        if self.is_token_valid():
            return True

        # 需要登录，上锁
        async with self._login_lock:
            # 第二次检查（上锁后重新检查，防止其他协程已登录）
            if self.is_token_valid():
                return True

            # 执行登录
            return await self._do_login()

    async def _do_login(self) -> bool:
        """执行登录操作"""
        base_url = settings.pansou_host.rstrip("/")
        login_url = f"{base_url}/api/auth/login"

        print(f"🔌 正在连接 PanSou 节点: {settings.pansou_host} ...")

        client = _get_async_client()
        try:
            resp = await client.post(
                login_url,
                json={
                    "username": settings.pansou_user,
                    "password": settings.pansou_pwd,
                },
                timeout=5.0,
            )

            if resp.status_code == 200:
                data = resp.json()
                self.token = data.get("token")

                # 从响应中读取真实的有效期，默认 1 小时（3600 秒）
                expires_in = data.get("expires_in", 3600)

                # 计算过期时间
                self.token_exp = time.time() + expires_in

                print(f"✅ PanSou 认证成功，Token 有效期: {expires_in} 秒")
                
                # 记录 Token 刷新成功指标
                try:
                    from ..metrics import record_token_metrics
                    record_token_metrics(True)
                except ImportError:
                    pass
                
                return True
            else:
                self.token = None  # 清空失败的 token
                print(f"❌ PanSou 认证失败 ({resp.status_code}): {resp.text}")
                
                # 记录 Token 刷新失败指标
                try:
                    from ..metrics import record_token_metrics
                    record_token_metrics(False)
                except ImportError:
                    pass
                
                return False

        except Exception as exc:
            self.token = None
            print(f"❌ PanSou 连接错误: {exc}")
            
            # 记录 Token 刷新失败指标
            try:
                from ..metrics import record_token_metrics
                record_token_metrics(False)
            except ImportError:
                pass
            
            return False

    def clear_token(self):
        """清空 token（用于强制重新登录）"""
        self.token = None
        self.token_exp = 0.0


# 全局单例
_token_manager = TokenManager()


async def pansou_search(query: str) -> dict[str, Any]:
    """
    通过 PanSou 搜索

    如果 PANSOU_HOST 未配置，返回空结果集。
    如果登录失败，返回友好的错误消息。
    """

    if not settings.pansou_host:
        return {
            "provider": "pansou",
            "enabled": False,
            "query": query,
            "results": [],
            "message": "PANSOU_HOST is not configured",
        }

    # 确保有有效的 token
    if not await _token_manager.ensure_token():
        return {
            "provider": "pansou",
            "enabled": True,
            "query": query,
            "results": [],
            "error": "无法连接到 PanSou 服务或认证失败，请检查配置",
        }

    # 执行搜索
    base_url = settings.pansou_host.rstrip("/")
    search_url = f"{base_url}/api/search"

    client = _get_async_client()
    try:
        resp = await client.post(
            search_url,
            headers={"Authorization": f"Bearer {_token_manager.token}"},
            json={"kw": query},
            timeout=float(settings.search_timeout),
        )

        # 如果 token 过期（401），清空 token 让下次请求重新登录
        if resp.status_code == 401:
            print("⚠️ Token 已过期，清空缓存")
            _token_manager.clear_token()
            return {
                "provider": "pansou",
                "enabled": True,
                "query": query,
                "results": [],
                "error": "Token 已过期，请重试",
            }

        resp.raise_for_status()
        data = resp.json()

        # 解析搜索结果
        results = []
        merged = data.get("merged_by_type", {})

        # 提取夸克（权重最高）
        for item in merged.get("quark", []):
            results.append({
                "title": item.get("note") or query,
                "url": item.get("url"),
                "description": f"更新时间: {item.get('datetime', '未知')}",
                "source": "夸克",
                "time": item.get("datetime", ""),
            })

        # 提取其他网盘
        for ptype, items in merged.items():
            if ptype == "quark":
                continue
            for item in items:
                results.append({
                    "title": item.get("note") or query,
                    "url": item.get("url"),
                    "description": f"来源: {ptype}",
                    "source": ptype,
                    "time": "",
                })

        print(f"✅ 搜索完成: '{query}' 共 {len(results)} 条结果")

        # 记录搜索成功指标
        try:
            from ..metrics import record_pansou_metrics
            record_pansou_metrics(True)
        except ImportError:
            pass

        return {
            "provider": "pansou",
            "enabled": True,
            "query": query,
            "results": results,
        }

    except asyncio.TimeoutError:
        print(f"⏱️ 搜索超时（{settings.search_timeout} 秒）")
        
        # 记录搜索失败指标
        try:
            from ..metrics import record_pansou_metrics
            record_pansou_metrics(False, "timeout")
        except ImportError:
            pass
        
        return {
            "provider": "pansou",
            "enabled": True,
            "query": query,
            "results": [],
            "error": f"搜索超时（{settings.search_timeout} 秒），请稍后重试",
        }
    except Exception as exc:
        print(f"⚠️ 搜索过程异常: {exc}")
        
        # 记录搜索失败指标
        try:
            from ..metrics import record_pansou_metrics
            record_pansou_metrics(False, str(exc))
        except ImportError:
            pass
        
        return {
            "provider": "pansou",
            "enabled": True,
            "query": query,
            "results": [],
            "error": str(exc),
        }


@lru_cache(maxsize=1)
def _get_async_client():
    """获取复用的 HTTP 客户端（冷启动优化）"""
    import httpx

    limits = httpx.Limits(max_connections=20, max_keepalive_connections=10)
    return httpx.AsyncClient(limits=limits, headers={"User-Agent": "openmeta/1.0"})

from __future__ import annotations

import logging
from typing import Any
from fastapi import APIRouter, Query
from ..services.pansou import pansou_search

router = APIRouter()
logger = logging.getLogger("openmeta.search")

@router.get("/search", tags=["搜索"])
async def search(
    q: str = Query(..., min_length=1, max_length=100, description="搜索关键词"),
    page: int = Query(1, ge=1, le=100, description="页码")
) -> dict[str, Any]:
    """
    搜索端点
    - **q**: 搜索关键词（必需）
    - **page**: 页码（默认：1）
    """
    logger.info(f"搜索请求: q='{q}', page={page}")
    
    try:
        # 使用优化的 PanSou 搜索服务
        result = await pansou_search(q)
        
        # 标准化返回格式
        response = {
            "q": q,
            "page": page,
            "items": result.get("results", []),
            "provider": result.get("provider", "unknown"),
            "enabled": result.get("enabled", False)
        }
        
        # 如果有错误信息，添加到响应中
        if "error" in result:
            response["warning"] = result.get("error", "搜索出现错误")
        
        # 如果服务未启用，添加提示信息
        if not result.get("enabled", False):
            response["warning"] = result.get("message", "搜索服务未配置")
        
        logger.info(f"搜索完成: q='{q}', 找到 {len(response.get('items', []))} 个结果")
        return response
        
    except Exception as e:
        logger.error(f"搜索失败: {str(e)}", exc_info=True)
        return {
            "q": q,
            "page": page,
            "items": [],
            "error": "搜索服务暂时不可用",
            "details": str(e),
            "provider": "error",
            "enabled": False
        }

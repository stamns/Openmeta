from fastapi import APIRouter, Request, Body
from typing import Any, Dict
import logging
from ..logging_config import logger

router = APIRouter()

@router.post("/logs", tags=["日志"])
async def receive_frontend_logs(
    request: Request,
    log_data: Dict[str, Any] = Body(...)
):
    """
    接收前端上传的错误日志
    """
    severity = log_data.get("severity", "error").lower()
    message = log_data.get("message", "No message provided")
    context = log_data.get("context", {})
    
    log_msg = f"[Frontend] {message}"
    
    if severity == "critical":
        logger.critical(log_msg, extra={"frontend_context": context})
    elif severity == "error":
        logger.error(log_msg, extra={"frontend_context": context})
    elif severity == "warning":
        logger.warning(log_msg, extra={"frontend_context": context})
    else:
        logger.info(log_msg, extra={"frontend_context": context})
        
    return {"status": "ok"}

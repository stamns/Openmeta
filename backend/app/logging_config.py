import logging
import json
import time
from datetime import datetime
from typing import Any
import os

class JsonFormatter(logging.Formatter):
    """
    JSON log formatter.
    """
    def format(self, record: logging.LogRecord) -> str:
        log_record = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "filename": record.filename,
            "lineno": record.lineno,
        }
        
        # Add extra fields if they exist
        if hasattr(record, "request_id"):
            log_record["request_id"] = record.request_id
        if hasattr(record, "method"):
            log_record["method"] = record.method
        if hasattr(record, "path"):
            log_record["path"] = record.path
        if hasattr(record, "status_code"):
            log_record["status_code"] = record.status_code
        if hasattr(record, "duration_ms"):
            log_record["duration_ms"] = record.duration_ms
        if hasattr(record, "ip"):
            log_record["ip"] = record.ip
        if hasattr(record, "user_agent"):
            log_record["user_agent"] = record.user_agent

        if record.exc_info:
            log_record["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_record, ensure_ascii=False)

def setup_logging(log_level_str: str = "INFO"):
    """
    Setup logging configuration.
    """
    log_level = getattr(logging, log_level_str.upper(), logging.INFO)
    
    # Root logger
    logger = logging.getLogger()
    logger.setLevel(log_level)
    
    # Remove existing handlers
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    # Console handler
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    logger.addHandler(handler)
    
    # Specific loggers
    logging.getLogger("uvicorn.access").handlers = [handler]
    logging.getLogger("uvicorn.error").handlers = [handler]
    
    return logger
"""
结构化日志配置
支持 JSON 格式日志和动态级别配置
"""

from __future__ import annotations

import json
import logging
import os
import sys
import time
from datetime import datetime
from typing import Any


class JSONFormatter(logging.Formatter):
    """JSON 格式日志格式化器"""
    
    def format(self, record: logging.LogRecord) -> str:
        """将日志记录格式化为 JSON"""
        log_data = {
            "timestamp": datetime.fromtimestamp(record.created).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno
        }
        
        # 添加异常信息
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        
        # 添加额外的上下文信息
        if hasattr(record, 'request_id'):
            log_data["request_id"] = record.request_id
        
        if hasattr(record, 'client_ip'):
            log_data["client_ip"] = record.client_ip
            
        if hasattr(record, 'method'):
            log_data["method"] = record.method
            
        if hasattr(record, 'path'):
            log_data["path"] = record.path
            
        if hasattr(record, 'status_code'):
            log_data["status_code"] = record.status_code
            
        if hasattr(record, 'duration_ms'):
            log_data["duration_ms"] = record.duration_ms
            
        if hasattr(record, 'user_agent'):
            log_data["user_agent"] = record.user_agent
        
        return json.dumps(log_data, ensure_ascii=False)


class RequestLoggingFilter(logging.Filter):
    """请求日志过滤器，添加请求上下文信息"""
    
    def __init__(self, request_id: str | None = None, client_ip: str | None = None):
        super().__init__()
        self.request_id = request_id
        self.client_ip = client_ip
    
    def filter(self, record: logging.LogRecord) -> bool:
        """添加上下文信息到日志记录"""
        if self.request_id:
            record.request_id = self.request_id
        if self.client_ip:
            record.client_ip = self.client_ip
        return True


def setup_logging() -> logging.Logger:
    """配置结构化日志系统"""
    
    # 获取日志级别配置
    log_level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    log_level = getattr(logging, log_level_name, logging.INFO)
    
    # 创建根日志记录器
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    
    # 清除现有的处理器
    root_logger.handlers.clear()
    
    # 控制台处理器（使用 JSON 格式）
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level)
    console_handler.setFormatter(JSONFormatter())
    
    # 错误处理器（如果需要，可以扩展为文件处理器）
    error_handler = logging.StreamHandler(sys.stderr)
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(JSONFormatter())
    
    # 添加处理器到根日志记录器
    root_logger.addHandler(console_handler)
    root_logger.addHandler(error_handler)
    
    # 设置第三方库的日志级别
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    logging.getLogger("fastapi").setLevel(logging.INFO)
    
    # 创建应用专用日志记录器
    app_logger = logging.getLogger("openmeta")
    
    # 记录日志配置信息
    app_logger.info("📝 日志系统初始化完成", extra={
        "log_level": log_level_name,
        "format": "json",
        "handlers": ["console", "error"]
    })
    
    return app_logger


def get_logger(name: str = "openmeta") -> logging.Logger:
    """获取指定名称的日志记录器"""
    return logging.getLogger(name)


def log_request(
    logger: logging.Logger,
    request_id: str,
    method: str,
    path: str,
    client_ip: str,
    user_agent: str,
    status_code: int,
    duration_ms: float
) -> None:
    """记录 HTTP 请求日志"""
    logger.info("HTTP 请求处理完成", extra={
        "request_id": request_id,
        "method": method,
        "path": path,
        "client_ip": client_ip,
        "user_agent": user_agent,
        "status_code": status_code,
        "duration_ms": duration_ms
    })


def log_error(
    logger: logging.Logger,
    request_id: str,
    error: Exception,
    context: dict[str, Any] | None = None
) -> None:
    """记录错误日志"""
    error_data = {
        "request_id": request_id,
        "error_type": type(error).__name__,
        "error_message": str(error)
    }
    
    if context:
        error_data.update(context)
    
    logger.error("处理请求时发生错误", extra=error_data, exc_info=True)

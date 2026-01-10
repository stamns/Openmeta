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

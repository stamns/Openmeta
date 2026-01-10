"""
结构化日志配置
支持 JSON 格式日志，包含请求 ID 和关键信息
"""

import json
import logging
import os
import sys
from datetime import datetime
from typing import Any, Dict


class StructuredLogger:
    """结构化日志记录器，输出 JSON 格式日志"""
    
    def __init__(self, name: str, level: int = logging.INFO):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(level)
        
        # 防止重复添加处理器
        if not self.logger.handlers:
            self._setup_handler()
    
    def _setup_handler(self):
        """设置 JSON 格式的日志处理器"""
        # 创建自定义格式化器
        formatter = StructuredFormatter()
        
        # 控制台处理器
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        self.logger.addHandler(console_handler)
        
        # 文件处理器（如果设置了日志文件路径）
        log_file = os.getenv('LOG_FILE')
        if log_file:
            try:
                from logging.handlers import RotatingFileHandler
                file_handler = RotatingFileHandler(
                    log_file, 
                    maxBytes=10*1024*1024,  # 10MB
                    backupCount=5
                )
                file_handler.setFormatter(formatter)
                self.logger.addHandler(file_handler)
            except Exception:
                # 如果文件处理器创建失败，仍然使用控制台输出
                pass
    
    def _log(self, level: int, message: str, extra: Dict[str, Any] = None):
        """内部日志方法"""
        if extra is None:
            extra = {}
        
        # 添加默认字段
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": logging.getLevelName(level),
            "message": message,
            "service": "openmeta",
            **extra
        }
        
        self.logger.log(level, json.dumps(log_data, ensure_ascii=False))
    
    def debug(self, message: str, extra: Dict[str, Any] = None):
        """DEBUG 级别日志"""
        self._log(logging.DEBUG, message, extra)
    
    def info(self, message: str, extra: Dict[str, Any] = None):
        """INFO 级别日志"""
        self._log(logging.INFO, message, extra)
    
    def warning(self, message: str, extra: Dict[str, Any] = None):
        """WARNING 级别日志"""
        self._log(logging.WARNING, message, extra)
    
    def error(self, message: str, extra: Dict[str, Any] = None):
        """ERROR 级别日志"""
        self._log(logging.ERROR, message, extra)
    
    def critical(self, message: str, extra: Dict[str, Any] = None):
        """CRITICAL 级别日志"""
        self._log(logging.CRITICAL, message, extra)


class StructuredFormatter(logging.Formatter):
    """JSON 格式日志格式化器"""
    
    def format(self, record: logging.LogRecord) -> str:
        """格式化日志记录"""
        # 基础信息
        log_data = {
            "timestamp": datetime.utcfromtimestamp(record.created).isoformat() + "Z",
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        
        # 添加异常信息
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        
        # 添加额外的自定义字段
        for key, value in record.__dict__.items():
            if key not in ['name', 'msg', 'args', 'levelname', 'levelno', 'pathname',
                          'filename', 'module', 'lineno', 'funcName', 'created', 'msecs',
                          'relativeCreated', 'thread', 'threadName', 'processName', 'process',
                          'getMessage', 'exc_info', 'exc_text', 'stack_info']:
                log_data[key] = value
        
        return json.dumps(log_data, ensure_ascii=False, default=str)


def setup_logging() -> StructuredLogger:
    """设置结构化日志系统"""
    # 获取日志级别
    log_level_name = os.getenv('LOG_LEVEL', 'INFO').upper()
    log_level = getattr(logging, log_level_name, logging.INFO)
    
    # 创建结构化日志记录器
    logger = StructuredLogger("openmeta", log_level)
    
    return logger


# 创建全局日志记录器实例
logger = setup_logging()

# 便捷函数
def get_logger(name: str = None) -> StructuredLogger:
    """获取指定名称的日志记录器"""
    if name:
        return StructuredLogger(name)
    return logger


def log_request_start(request_id: str, method: str, path: str, client_ip: str = None, user_agent: str = None):
    """记录请求开始"""
    extra = {
        "request_id": request_id,
        "event": "request_start",
        "method": method,
        "path": path,
    }
    if client_ip:
        extra["client_ip"] = client_ip
    if user_agent:
        extra["user_agent"] = user_agent
    
    logger.info(f"请求开始: {method} {path}", extra=extra)


def log_request_end(request_id: str, method: str, path: str, status_code: int, 
                   duration_ms: float, client_ip: str = None):
    """记录请求结束"""
    extra = {
        "request_id": request_id,
        "event": "request_end",
        "method": method,
        "path": path,
        "status_code": status_code,
        "duration_ms": round(duration_ms, 2),
    }
    if client_ip:
        extra["client_ip"] = client_ip
    
    if 200 <= status_code < 300:
        logger.info(f"请求完成: {method} {path} - {status_code} ({duration_ms:.2f}ms)", extra=extra)
    elif 400 <= status_code < 500:
        logger.warning(f"客户端错误: {method} {path} - {status_code} ({duration_ms:.2f}ms)", extra=extra)
    else:
        logger.error(f"服务器错误: {method} {path} - {status_code} ({duration_ms:.2f}ms)", extra=extra)


def log_error(request_id: str, error: Exception, context: Dict[str, Any] = None):
    """记录错误"""
    extra = {
        "request_id": request_id,
        "event": "error",
        "error_type": type(error).__name__,
        "error_message": str(error),
    }
    if context:
        extra.update(context)
    
    logger.error(f"发生错误: {str(error)}", extra=extra)
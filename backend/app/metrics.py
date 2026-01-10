import time
from dataclasses import dataclass, field
from typing import Dict, List
import threading

@dataclass
class Metrics:
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    total_response_time: float = 0.0
    status_codes: Dict[int, int] = field(default_factory=dict)
    response_times: List[float] = field(default_factory=list)
    start_time: float = field(default_factory=time.time)
    _lock: threading.Lock = field(default_factory=threading.Lock)

    def record_request(self, status_code: int, duration_ms: float):
        with self._lock:
            self.total_requests += 1
            self.status_codes[status_code] = self.status_codes.get(status_code, 0) + 1
            self.total_response_time += duration_ms
"""
监控指标收集
用于收集和计算 API 性能指标
"""

from __future__ import annotations

import asyncio
import time
import threading
from collections import defaultdict, deque
from typing import Dict, Any, Optional
from dataclasses import dataclass, field
from datetime import datetime, timedelta


@dataclass
class RequestMetrics:
    """请求指标数据结构"""
    timestamp: float
    method: str
    path: str
    status_code: int
    duration_ms: float
    client_ip: str
    user_agent: str = ""
    error: bool = False


@dataclass 
class ResponseTimeMetrics:
    """响应时间指标"""
    count: int = 0
    total_time: float = 0.0
    min_time: float = float('inf')
    max_time: float = 0.0
    p95_time: float = 0.0
    p99_time: float = 0.0
    recent_times: deque = field(default_factory=lambda: deque(maxlen=1000))
    
    def add_response_time(self, duration_ms: float):
        """添加响应时间"""
        self.count += 1
        self.total_time += duration_ms
        self.min_time = min(self.min_time, duration_ms)
        self.max_time = max(self.max_time, duration_ms)
        self.recent_times.append(duration_ms)
        
        # 计算平均响应时间
        self.avg_time = self.total_time / self.count if self.count > 0 else 0
        
        # 计算百分位数
        if len(self.recent_times) >= 100:
            sorted_times = sorted(self.recent_times)
            p95_index = int(len(sorted_times) * 0.95)
            p99_index = int(len(sorted_times) * 0.99)
            self.p95_time = sorted_times[p95_index]
            self.p99_time = sorted_times[p99_index]


class MetricsCollector:
    """指标收集器"""
    
    def __init__(self):
        # 总体指标
        self.total_requests: int = 0
        self.successful_requests: int = 0
        self.failed_requests: int = 0
        self.start_time: float = time.time()
        
        # 按状态码分组
        self.status_code_counts: Dict[int, int] = defaultdict(int)
        
        # 按路径分组
        self.path_metrics: Dict[str, ResponseTimeMetrics] = defaultdict(
            lambda: ResponseTimeMetrics()
        )
        
        # 按错误类型分组
        self.error_types: Dict[str, int] = defaultdict(int)
        
        # 最近请求记录
        self.recent_requests: deque = deque(maxlen=1000)
        
        # 锁确保线程安全
        self._lock = threading.RLock()
    
    def record_request(
        self,
        method: str,
        path: str,
        status_code: int,
        duration_ms: float,
        client_ip: str,
        user_agent: str = "",
        error: Optional[Exception] = None
    ) -> None:
        """记录一个请求的指标"""
        with self._lock:
            current_time = time.time()
            
            # 创建请求指标
            request_metrics = RequestMetrics(
                timestamp=current_time,
                method=method,
                path=path,
                status_code=status_code,
                duration_ms=duration_ms,
                client_ip=client_ip,
                user_agent=user_agent,
                error=error is not None
            )
            
            # 更新总体指标
            self.total_requests += 1
            
            if 200 <= status_code < 400:
                self.successful_requests += 1
            else:
                self.failed_requests += 1
            
            # Keep only last 1000 response times for percentile calculation
            self.response_times.append(duration_ms)
            if len(self.response_times) > 1000:
                self.response_times.pop(0)

    def get_stats(self):
        with self._lock:
            avg_response_time = (
                self.total_response_time / self.total_requests 
                if self.total_requests > 0 else 0
            )
            
            p95 = 0
            p99 = 0
            if self.response_times:
                sorted_times = sorted(self.response_times)
                p95 = sorted_times[int(len(sorted_times) * 0.95)]
                p99 = sorted_times[int(len(sorted_times) * 0.99)]
            
            success_rate = (
                self.successful_requests / self.total_requests * 100 
                if self.total_requests > 0 else 100
            )
            
            error_rate = 100 - success_rate
            
            return {
                "total_requests": self.total_requests,
                "successful_requests": self.successful_requests,
                "failed_requests": self.failed_requests,
                "success_rate": f"{success_rate:.2f}%",
                "error_rate": f"{error_rate:.2f}%",
                "avg_response_time_ms": round(avg_response_time, 2),
                "p95_ms": round(p95, 2),
                "p99_ms": round(p99, 2),
                "status_code_distribution": self.status_codes.copy(),
                "uptime_seconds": int(time.time() - self.start_time)
            }

# Global metrics instance
metrics = Metrics()
            # 更新状态码统计
            self.status_code_counts[status_code] += 1
            
            # 更新路径指标
            path_metrics = self.path_metrics[path]
            path_metrics.add_response_time(duration_ms)
            
            # 记录错误
            if error:
                error_type = type(error).__name__
                self.error_types[error_type] += 1
            
            # 添加到最近请求记录
            self.recent_requests.append(request_metrics)
    
    def get_metrics_summary(self) -> Dict[str, Any]:
        """获取指标摘要"""
        with self._lock:
            uptime_seconds = time.time() - self.start_time
            uptime_td = timedelta(seconds=uptime_seconds)
            
            # 计算总体指标
            success_rate = (
                (self.successful_requests / self.total_requests * 100)
                if self.total_requests > 0 else 0
            )
            
            error_rate = (
                (self.failed_requests / self.total_requests * 100)
                if self.total_requests > 0 else 0
            )
            
            avg_response_time = (
                sum(r.duration_ms for r in self.recent_requests) / len(self.recent_requests)
                if self.recent_requests else 0
            )
            
            # 计算最近 1 分钟的请求数
            one_minute_ago = time.time() - 60
            recent_requests_count = sum(
                1 for r in self.recent_requests if r.timestamp >= one_minute_ago
            )
            
            return {
                "uptime_seconds": uptime_seconds,
                "uptime_human": str(uptime_td).split('.')[0],  # 移除微秒
                "total_requests": self.total_requests,
                "successful_requests": self.successful_requests,
                "failed_requests": self.failed_requests,
                "success_rate_percent": round(success_rate, 2),
                "error_rate_percent": round(error_rate, 2),
                "average_response_time_ms": round(avg_response_time, 2),
                "requests_last_minute": recent_requests_count,
                "status_code_distribution": dict(self.status_code_counts),
                "error_types": dict(self.error_types),
                "top_paths": self._get_top_paths()
            }
    
    def get_detailed_metrics(self) -> Dict[str, Any]:
        """获取详细指标"""
        with self._lock:
            summary = self.get_metrics_summary()
            
            # 添加详细路径指标
            path_details = {}
            for path, metrics in self.path_metrics.items():
                path_details[path] = {
                    "total_requests": metrics.count,
                    "average_ms": round(metrics.avg_time if hasattr(metrics, 'avg_time') else 0, 2),
                    "min_ms": round(metrics.min_time if metrics.min_time != float('inf') else 0, 2),
                    "max_ms": round(metrics.max_time, 2),
                    "p95_ms": round(metrics.p95_time, 2),
                    "p99_ms": round(metrics.p99_time, 2)
                }
            
            summary["path_details"] = path_details
            
            return summary
    
    def _get_top_paths(self) -> Dict[str, int]:
        """获取请求最多的路径"""
        path_counts = {}
        for path, metrics in self.path_metrics.items():
            path_counts[path] = metrics.count
        
        # 按请求数排序，返回前 10 个
        sorted_paths = sorted(path_counts.items(), key=lambda x: x[1], reverse=True)
        return dict(sorted_paths[:10])
    
    def reset_metrics(self) -> None:
        """重置指标（用于测试）"""
        with self._lock:
            self.total_requests = 0
            self.successful_requests = 0
            self.failed_requests = 0
            self.status_code_counts.clear()
            self.path_metrics.clear()
            self.error_types.clear()
            self.recent_requests.clear()
            self.start_time = time.time()


class SystemMetrics:
    """系统指标收集器"""
    
    @staticmethod
    def get_memory_usage() -> Dict[str, Any]:
        """获取内存使用情况"""
        try:
            import psutil
            process = psutil.Process()
            memory_info = process.memory_info()
            
            return {
                "rss_mb": round(memory_info.rss / 1024 / 1024, 2),  # 物理内存
                "vms_mb": round(memory_info.vms / 1024 / 1024, 2),  # 虚拟内存
                "percent": process.memory_percent()
            }
        except ImportError:
            # 如果没有 psutil，返回模拟数据
            return {
                "rss_mb": 0,
                "vms_mb": 0,
                "percent": 0
            }
    
    @staticmethod
    def get_cpu_info() -> Dict[str, Any]:
        """获取 CPU 信息"""
        try:
            import psutil
            return {
                "cpu_percent": psutil.cpu_percent(interval=1),
                "cpu_count": psutil.cpu_count()
            }
        except ImportError:
            return {
                "cpu_percent": 0,
                "cpu_count": 0
            }
    
    @staticmethod
    def get_disk_usage() -> Dict[str, Any]:
        """获取磁盘使用情况"""
        try:
            import psutil
            disk = psutil.disk_usage('/')
            return {
                "total_gb": round(disk.total / 1024 / 1024 / 1024, 2),
                "used_gb": round(disk.used / 1024 / 1024 / 1024, 2),
                "free_gb": round(disk.free / 1024 / 1024 / 1024, 2),
                "percent": round((disk.used / disk.total) * 100, 2)
            }
        except ImportError:
            return {
                "total_gb": 0,
                "used_gb": 0,
                "free_gb": 0,
                "percent": 0
            }


# 全局指标收集器实例
_metrics_collector = MetricsCollector()


def get_metrics_collector() -> MetricsCollector:
    """获取全局指标收集器实例"""
    return _metrics_collector


def record_request(
    method: str,
    path: str,
    status_code: int,
    duration_ms: float,
    client_ip: str,
    user_agent: str = "",
    error: Optional[Exception] = None
) -> None:
    """记录请求指标（便捷函数）"""
    _metrics_collector.record_request(
        method=method,
        path=path,
        status_code=status_code,
        duration_ms=duration_ms,
        client_ip=client_ip,
        user_agent=user_agent,
        error=error
    )

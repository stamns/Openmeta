"""
监控指标收集模块
收集请求统计、响应时间、错误分布等监控数据
"""

import time
import threading
from collections import defaultdict, deque
from typing import Dict, List, Optional, Tuple
import os
import psutil


class MetricsCollector:
    """监控指标收集器"""
    
    def __init__(self, max_history: int = 10000):
        self.max_history = max_history
        
        # 基础指标
        self.total_requests = 0
        self.successful_requests = 0
        self.failed_requests = 0
        self.start_time = time.time()
        
        # 响应时间统计（滑动窗口）
        self.response_times = deque(maxlen=max_history)
        self.response_times_lock = threading.Lock()
        
        # 状态码统计
        self.status_codes = defaultdict(int)
        self.status_codes_lock = threading.Lock()
        
        # 方法统计
        self.methods = defaultdict(int)
        self.methods_lock = threading.Lock()
        
        # 路径统计（最近访问的路径）
        self.paths = defaultdict(int)
        self.paths_lock = threading.Lock()
        
        # 错误统计
        self.errors = defaultdict(int)
        self.errors_lock = threading.Lock()
        
        # PanSou 指标
        self.pansou_requests = 0
        self.pansou_successes = 0
        self.pansou_failures = 0
        self.pansou_lock = threading.Lock()
        
        # Token 指标
        self.token_refreshes = 0
        self.token_failures = 0
        self.token_lock = threading.Lock()
    
    def record_request(self, method: str, path: str, status_code: int, duration_ms: float, error: str = None):
        """记录请求指标"""
        with self.response_times_lock:
            self.response_times.append(duration_ms)
        
        with self.status_codes_lock:
            self.status_codes[status_code] += 1
        
        with self.methods_lock:
            self.methods[method] += 1
        
        with self.paths_lock:
            # 简化路径（移除参数）
            simple_path = path.split('?')[0]
            self.paths[simple_path] += 1
        
        with threading.Lock():
            self.total_requests += 1
        
        if 200 <= status_code < 300:
            with threading.Lock():
                self.successful_requests += 1
        else:
            with threading.Lock():
                self.failed_requests += 1
            
            if error:
                with self.errors_lock:
                    self.errors[error] += 1
    
    def record_pansou_request(self, success: bool, error: str = None):
        """记录 PanSou 请求指标"""
        with self.pansou_lock:
            self.pansou_requests += 1
        
        if success:
            with self.pansou_lock:
                self.pansou_successes += 1
        else:
            with self.pansou_lock:
                self.pansou_failures += 1
    
    def record_token_refresh(self, success: bool):
        """记录 Token 刷新指标"""
        with self.token_lock:
            if success:
                self.token_refreshes += 1
            else:
                self.token_failures += 1
    
    def get_metrics(self) -> Dict:
        """获取当前指标"""
        uptime_seconds = time.time() - self.start_time
        
        with self.response_times_lock:
            rt_list = list(self.response_times)
        
        # 计算响应时间统计
        if rt_list:
            avg_response_time = sum(rt_list) / len(rt_list)
            sorted_times = sorted(rt_list)
            p50 = sorted_times[int(len(sorted_times) * 0.5)]
            p95 = sorted_times[int(len(sorted_times) * 0.95)]
            p99 = sorted_times[int(len(sorted_times) * 0.99)]
            min_response_time = min(rt_list)
            max_response_time = max(rt_list)
        else:
            avg_response_time = p50 = p95 = p99 = min_response_time = max_response_time = 0
        
        # 计算请求率
        if uptime_seconds > 0:
            requests_per_minute = (self.total_requests / uptime_seconds) * 60
            requests_per_second = self.total_requests / uptime_seconds
        else:
            requests_per_minute = requests_per_second = 0
        
        # 错误率
        error_rate = (self.failed_requests / self.total_requests * 100) if self.total_requests > 0 else 0
        
        # 成功率
        success_rate = (self.successful_requests / self.total_requests * 100) if self.total_requests > 0 else 0
        
        return {
            "timestamp": time.time(),
            "uptime_seconds": round(uptime_seconds, 2),
            "uptime_hours": round(uptime_seconds / 3600, 2),
            
            # 基础统计
            "total_requests": self.total_requests,
            "successful_requests": self.successful_requests,
            "failed_requests": self.failed_requests,
            "success_rate": round(success_rate, 2),
            "error_rate": round(error_rate, 2),
            
            # 性能指标
            "requests_per_minute": round(requests_per_minute, 2),
            "requests_per_second": round(requests_per_second, 3),
            "avg_response_time_ms": round(avg_response_time, 2),
            "p50_response_time_ms": round(p50, 2),
            "p95_response_time_ms": round(p95, 2),
            "p99_response_time_ms": round(p99, 2),
            "min_response_time_ms": round(min_response_time, 2),
            "max_response_time_ms": round(max_response_time, 2),
            
            # 状态码分布
            "status_codes": dict(self.status_codes),
            
            # 方法分布
            "methods": dict(self.methods),
            
            # 热门路径
            "top_paths": dict(sorted(self.paths.items(), key=lambda x: x[1], reverse=True)[:10]),
            
            # 错误分布
            "errors": dict(self.errors),
            
            # PanSou 指标
            "pansou": {
                "total_requests": self.pansou_requests,
                "successes": self.pansou_successes,
                "failures": self.pansou_failures,
                "success_rate": round((self.pansou_successes / self.pansou_requests * 100) if self.pansou_requests > 0 else 0, 2)
            },
            
            # Token 指标
            "token": {
                "refreshes": self.token_refreshes,
                "failures": self.token_failures,
                "success_rate": round((self.token_refreshes / (self.token_refreshes + self.token_failures) * 100) 
                                    if (self.token_refreshes + self.token_failures) > 0 else 0, 2)
            }
        }
    
    def get_memory_usage(self) -> Dict:
        """获取内存使用情况"""
        try:
            process = psutil.Process()
            memory_info = process.memory_info()
            memory_percent = process.memory_percent()
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
                "memory_percent": round(memory_percent, 2),
                "available_mb": round(psutil.virtual_memory().available / 1024 / 1024, 2),
                "total_mb": round(psutil.virtual_memory().total / 1024 / 1024, 2)
            }
        except Exception:
            return {
                "rss_mb": 0,
                "vms_mb": 0,
                "memory_percent": 0,
                "available_mb": 0,
                "total_mb": 0
            }
    
    def get_redis_status(self) -> Dict:
        """获取 Redis 状态（同步方法）"""
        try:
            import redis as redis_sync
            
            redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
            redis_client = redis_sync.from_url(
                redis_url,
                socket_connect_timeout=5,
                socket_timeout=5
            )
            
            # 尝试 Ping
            start_time = time.time()
            redis_client.ping()
            ping_time = (time.time() - start_time) * 1000
            
            # 获取 Redis 信息
            info = redis_client.info()
            
            return {
                "available": True,
                "ping_ms": round(ping_time, 2),
                "version": info.get('redis_version', 'unknown'),
                "connected_clients": info.get('connected_clients', 0),
                "used_memory_mb": round(info.get('used_memory', 0) / 1024 / 1024, 2),
                "total_commands_processed": info.get('total_commands_processed', 0)
            }
        except ImportError:
            return {
                "available": False,
                "error": "Redis library not installed"
            }
        except Exception as e:
            return {
                "available": False,
                "error": str(e)
            }
    
    def reset(self):
        """重置所有指标（用于测试）"""
        with self.response_times_lock:
            self.response_times.clear()
        
        with self.status_codes_lock:
            self.status_codes.clear()
        
        with self.methods_lock:
            self.methods.clear()
        
        with self.paths_lock:
            self.paths.clear()
        
        with self.errors_lock:
            self.errors.clear()
        
        with self.pansou_lock:
            self.pansou_requests = 0
            self.pansou_successes = 0
            self.pansou_failures = 0
        
        with self.token_lock:
            self.token_refreshes = 0
            self.token_failures = 0
        
        with threading.Lock():
            self.total_requests = 0
            self.successful_requests = 0
            self.failed_requests = 0
            self.start_time = time.time()
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


def record_request_metrics(method: str, path: str, status_code: int, duration_ms: float, error: str = None):
    """记录请求指标（便捷函数）"""
    _metrics_collector.record_request(method, path, status_code, duration_ms, error)


def record_pansou_metrics(success: bool, error: str = None):
    """记录 PanSou 指标（便捷函数）"""
    _metrics_collector.record_pansou_request(success, error)


def record_token_metrics(success: bool):
    """记录 Token 指标（便捷函数）"""
    _metrics_collector.record_token_refresh(success)


def get_current_metrics() -> Dict:
    """获取当前指标（便捷函数）"""
    return _metrics_collector.get_metrics()
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

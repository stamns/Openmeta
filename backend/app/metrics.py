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
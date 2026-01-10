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

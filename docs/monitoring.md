# OpenMeta 监控与可观测性指南

OpenMeta 实现了生产级的监控系统，包括结构化日志、请求追踪、速率限制和详细的健康检查端点。

## 1. 结构化日志系统

所有日志均以 JSON 格式输出到标准输出（Stdout），便于集成到日志聚合平台（如 ELK, Loki, Datadog）。

### 日志格式
```json
{
  "timestamp": "2025-01-10 15:00:00",
  "level": "INFO",
  "message": "完成请求: GET /api/search - 200",
  "logger": "root",
  "request_id": "uuid-v4-string",
  "method": "GET",
  "path": "/api/search",
  "status_code": 200,
  "duration_ms": 150.5,
  "ip": "127.0.0.1"
}
```

### 配置
通过 `LOG_LEVEL` 环境变量调整日志级别（DEBUG, INFO, WARNING, ERROR）。

## 2. 请求追踪 (Request Tracing)

每个 API 请求都会被分配一个唯一的 `X-Request-ID`。
- 如果客户端在请求头中提供了 `X-Request-ID`，系统将沿用该 ID。
- 否则，系统将自动生成一个新的 UUID。
- 该 ID 会出现在响应头和所有相关的日志条目中。

## 3. 速率限制 (Rate Limiting)

系统通过 `RateLimitMiddleware` 提供基于 IP 的速率限制。

- **默认限制**: 每分钟 60 个请求。
- **可配置性**: 通过 `RATE_LIMIT_PER_MINUTE` 环境变量调整。
- **存储**:
  - 生产环境建议配置 Redis (`REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`)。
  - 如果 Redis 不可用，系统会自动降级到内存存储（Memory Storage）。
- **响应头**:
  - `X-RateLimit-Limit`: 限制额度
  - `X-RateLimit-Remaining`: 剩余可用请求数

## 4. 健康检查端点

访问 `/health` 获取基本状态。

### 详细监控指标
访问 `/health?detail=true` 获取详细信息，包括：

- **Backend Latency**: 当前请求的处理耗时。
- **PanSou Status**: Token 有效期、最后登录时间、登录计数。
- **Redis Status**: 连接状态。
- **Memory Usage**: RSS 和 VMS 内存占用（MB）。
- **Metrics**:
  - 总请求数、成功/失败次数
  - 平均响应时间
  - P95, P99 响应时间
  - 状态码分布
  - Uptime (服务运行时间)

## 5. 告警建议 (容量规划)

根据监控指标，建议设置以下告警：

1. **错误率告警**: `failed_requests / total_requests > 5%` 持续 5 分钟。
2. **高延迟告警**: `p95_ms > 2000ms`（排除 PanSou 搜索本身的延迟影响）。
3. **速率限制告警**: 429 状态码激增可能表示受到攻击。
4. **PanSou 认证失败**: `pansou.token_valid == false` 时发出告警。
5. **内存泄露**: `memory_mb.rss` 持续增长。

## 6. 环境变量参考

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `LOG_LEVEL` | 日志级别 | `INFO` |
| `RATE_LIMIT_PER_MINUTE` | 每分钟请求限制 | `60` |
| `REDIS_HOST` | Redis 主机名 | - |
| `REDIS_PORT` | Redis 端口 | `6379` |
| `REDIS_PASSWORD` | Redis 密码 | - |

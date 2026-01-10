# OpenMeta 监控和运维指南

## 概述

OpenMeta 提供了完整的生产级监控和日志系统，包括：
- 结构化 JSON 日志
- API 速率限制
- 健康检查端点
- 性能指标收集
- 请求追踪

## 监控端点

### 1. 基础健康检查
```bash
GET /health
```

返回基础服务状态：
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
# OpenMeta 监控和运维指南

本文档提供了 OpenMeta 应用的监控、日志记录和运维最佳实践指南。

## 📊 监控端点

### 健康检查端点

#### 基础健康检查
```bash
curl http://localhost:8000/health
```

返回基础服务状态信息：
```json
{
  "status": "ok",
  "service": "OpenMeta",
  "version": "1.1.0",
  "timestamp": 1640995200.0,
  "pansou_configured": true,
  "pansou_host": "https://your-pansou-host.com"
}
```

### 2. 详细健康检查
```bash
GET /health?detail=true
```

返回完整的监控信息，包括：
- 服务状态
- PanSou 连接状态
- Redis 可用性
- 性能指标
- 内存使用
- 请求统计
- 系统资源

### 3. 监控指标
```bash
GET /metrics
```

返回详细的性能指标，包括：
- 总请求数
- 成功率/错误率
- 平均响应时间
- p95/p99 响应时间
- 状态码分布
- PanSou 请求统计
- Token 刷新统计

## 环境变量配置

### 日志配置
```bash
LOG_LEVEL=INFO              # 日志级别: DEBUG, INFO, WARNING, ERROR
LOG_FILE=/var/log/openmeta.log  # 日志文件路径（可选）
```

### 速率限制配置
```bash
RATE_LIMIT_PER_MINUTE=60    # 每分钟最大请求数（默认 60）
REDIS_URL=redis://localhost:6379/0  # Redis 连接 URL（可选）
```

### 监控配置
```bash
PANSOU_HOST=https://your-pansou-host.com  # PanSou 服务器地址
PANSOU_USER=your_username                   # PanSou 用户名
PANSOU_PWD=your_password                   # PanSou 密码
SEARCH_TIMEOUT=15                          # 搜索超时（秒，默认 15）
```

## 日志系统

### 结构化日志格式

所有日志都是 JSON 格式，便于日志聚合和分析：

```json
{
  "timestamp": "2024-01-01T12:00:00.000Z",
  "level": "INFO",
  "message": "搜索完成: query='test', 找到 10 个结果, 耗时 245.67ms",
  "service": "openmeta",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "query": "test",
  "results_count": 10,
  "duration_ms": 245.67,
  "success": true,
  "event": "search_completed"
}
```

### 日志级别

- **DEBUG**: 详细调试信息
- **INFO**: 一般信息记录
- **WARNING**: 警告信息
- **ERROR**: 错误信息
- **CRITICAL**: 严重错误

### 请求追踪

每个请求都会被分配一个唯一的 `request_id`，用于追踪：

```json
{
  "event": "request_start",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "method": "GET",
  "path": "/api/search",
  "client_ip": "192.168.1.100",
  "user_agent": "Mozilla/5.0..."
}
```

## 速率限制

### 工作原理

- 基于 IP 地址的速率限制
- 默认限制：60 请求/分钟
- 使用 Redis（如果可用）或内存存储
- 返回 429 状态码和相关信息

### 响应头

当请求被限制时，返回以下头部：
```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1640995200
Retry-After: 60
```

### 配置示例

```bash
# 设置更严格的限制
RATE_LIMIT_PER_MINUTE=30

# 使用 Redis 进行分布式限制
REDIS_URL=redis://redis-server:6379/0
```

## 性能监控

### 关键指标

1. **请求率**
   - 总请求数
   - 每分钟请求数
   - 每秒请求数

2. **响应时间**
   - 平均响应时间
   - p50（中位数）
   - p95
   - p99

3. **成功率**
   - 成功请求百分比
   - 错误请求百分比
   - 状态码分布

4. **资源使用**
   - 内存使用（RSS, VMS）
   - CPU 使用率
   - 磁盘使用情况

### PanSou 监控

- 总请求数
- 成功请求数
- 失败请求数
- Token 刷新统计
- 搜索超时统计

### Redis 监控（如果可用）

- 连接状态
- 响应时间
- 内存使用
- 连接数
- 处理命令数

## 告警配置

### 建议的告警阈值

1. **错误率告警**
   ```bash
   # 错误率超过 5%
   ALERT_ERROR_RATE_THRESHOLD=5
   ```

2. **响应时间告警**
   ```bash
   # 平均响应时间超过 1 秒
   ALERT_RESPONSE_TIME_THRESHOLD=1000
   ```

3. **内存使用告警**
   ```bash
   # 内存使用超过 80%
   ALERT_MEMORY_THRESHOLD=80
   ```

### 健康检查集成

```bash
# 检查服务状态
curl -s http://localhost:8000/health | jq '.status'

# 检查详细状态
curl -s http://localhost:8000/health?detail=true | jq '.performance.error_rate'

# 检查 Redis 连接
curl -s http://localhost:8000/health?detail=true | jq '.redis.available'
```

## 日志聚合和分析

### 使用 ELK Stack

```yaml
# filebeat 配置示例
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/openmeta.log
  json.keys_under_root: true
  json.add_error_key: true

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  index: "openmeta-%{+yyyy.MM.dd}"
```

### 使用 Grafana + Prometheus

1. 将日志转换为 Prometheus 指标
2. 在 Grafana 中创建仪表板
3. 设置告警规则

### 日志查询示例

```bash
# 查找错误请求
jq 'select(.level == "ERROR")' /var/log/openmeta.log

# 查找特定请求 ID
jq 'select(.request_id == "550e8400-e29b-41d4-a716-446655440000")' /var/log/openmeta.log

# 查找慢请求（> 1秒）
jq 'select(.duration_ms > 1000)' /var/log/openmeta.log

# 统计每分钟请求数
jq 'select(.event == "request_end") | .timestamp[11:16]' /var/log/openmeta.log | sort | uniq -c
```

## 故障排查

### 常见问题

1. **PanSou 连接失败**
   ```bash
   # 检查 PanSou 健康状态
   curl -s /health?detail=true | jq '.pansou.status'
   
   # 检查环境变量
   echo $PANSOU_HOST $PANSOU_USER
   ```

2. **Redis 不可用**
   ```bash
   # 检查 Redis 状态
   curl -s /health?detail=true | jq '.redis.available'
   
   # 如果 Redis 不可用，系统会自动降级到内存存储
   ```

3. **速率限制问题**
   ```bash
   # 检查当前限制
   curl -I http://localhost:8000/api/search?q=test
   
   # 查看响应头中的限制信息
   grep -i rateLimit response.headers
   ```

4. **内存泄漏检测**
   ```bash
   # 监控内存使用
   curl -s /metrics | jq '.performance.memory'
   
   # 检查长时间运行的进程
   uptime
   ```

### 调试模式

```bash
# 启用调试日志
export LOG_LEVEL=DEBUG

# 启用详细错误信息
export DEBUG=1
```

## 容量规划

### 基于指标的容量规划

1. **响应时间分析**
   ```bash
   # 获取 p99 响应时间
   curl -s /metrics | jq '.p99_response_time_ms'
   ```

2. **请求增长趋势**
   ```bash
   # 分析请求增长
   curl -s /metrics | jq '.requests_per_minute'
   ```

3. **资源使用趋势**
   ```bash
   # 监控资源使用
   curl -s /health?detail=true | jq '.performance.memory'
   ```

### 扩展建议

1. **水平扩展**
   - 当请求率超过单实例处理能力时
   - 使用负载均衡器分发请求

2. **垂直扩展**
   - 当响应时间持续超过阈值时
   - 增加 CPU 和内存资源

3. **数据库优化**
   - 使用 Redis 进行缓存
   - 优化 PanSou 连接池

## 最佳实践

1. **监控覆盖**
   - 监控所有关键路径
   - 设置合理的告警阈值
   - 定期检查日志聚合

2. **日志管理**
   - 使用结构化日志
   - 定期轮转日志文件
   - 设置合适的日志级别

3. **性能优化**
   - 监控响应时间分布
   - 识别性能瓶颈
   - 优化慢查询

4. **安全考虑**
   - 限制访问监控端点
   - 使用 HTTPS
   - 实施访问控制

## 联系支持

如果遇到监控相关问题，请：
1. 检查日志文件
2. 运行健康检查
3. 收集相关指标
4. 联系技术支持
  "version": "1.0.0",
  "timestamp": 1640995200.123,
  "pansou_configured": true
}
```

#### 详细健康检查
```bash
curl http://localhost:8000/health?detail=true
```

返回完整的系统状态信息，包括：
- **Backend**: 后端服务状态和响应时间
- **PanSou**: 连接状态和 Token 信息
- **System**: 内存、CPU、磁盘使用情况
- **Metrics**: 应用性能指标

## 📈 性能指标

### 关键指标说明

#### 请求指标
- **total_requests**: 总请求数
- **successful_requests**: 成功请求数（2xx 状态码）
- **failed_requests**: 失败请求数（4xx/5xx 状态码）
- **success_rate_percent**: 成功率百分比
- **error_rate_percent**: 错误率百分比

#### 响应时间指标
- **average_response_time_ms**: 平均响应时间（毫秒）
- **p95_ms**: 95% 请求的响应时间
- **p99_ms**: 99% 请求的响应时间

#### 业务指标
- **requests_last_minute**: 最近一分钟请求数
- **status_code_distribution**: 状态码分布
- **error_types**: 错误类型统计
- **top_paths**: 热门请求路径

### 监控建议

#### 告警阈值建议
- **成功率**: < 95% 告警
- **错误率**: > 5% 告警
- **平均响应时间**: > 1000ms 告警
- **内存使用**: > 80% 告警
- **CPU 使用**: > 80% 告警

#### 监控工具集成
```bash
# Prometheus 集成示例
curl -s http://localhost:8000/health?detail=true | jq '.metrics'

# Grafana 仪表板数据源
# 使用 /health?detail=true 作为数据源
```

## 🚦 速率限制

### 配置

通过环境变量配置速率限制：

```bash
# 每分钟最大请求数（默认：60）
RATE_LIMIT_PER_MINUTE=60

# 日志级别
LOG_LEVEL=INFO
```

### 响应头

所有 API 响应都包含速率限制信息：

```
X-RateLimit-Limit: 60          # 每分钟限制
X-RateLimit-Remaining: 45     # 剩余请求数
X-RateLimit-Reset: 1640995260 # 重置时间戳
```

### 限流响应

当超过限制时，返回 429 状态码：

```json
{
  "error": "Rate limit exceeded",
  "message": "请求过于频繁，请稍后再试。每分钟最多 60 个请求。",
  "retry_after": 30
}
```

## 📝 日志系统

### 结构化日志

OpenMeta 使用 JSON 格式的结构化日志，便于日志聚合和分析：

```json
{
  "timestamp": "2023-12-31T12:00:00.123456Z",
  "level": "INFO",
  "logger": "openmeta",
  "message": "请求开始处理",
  "module": "main",
  "function": "process_request",
  "line": 45,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "method": "GET",
  "path": "/api/search",
  "client_ip": "192.168.1.100",
  "user_agent": "Mozilla/5.0..."
}
```

### 日志级别

- **DEBUG**: 详细的调试信息
- **INFO**: 一般信息记录
- **WARNING**: 警告信息
- **ERROR**: 错误信息

### 请求追踪

每个请求都会被分配唯一的 `request_id`，便于追踪：

```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "method": "GET",
  "path": "/api/search",
  "status_code": 200,
  "duration_ms": 125.45
}
```

## 🔧 运维脚本

### 健康检查脚本

```bash
#!/bin/bash
# health-check.sh

HEALTH_URL="http://localhost:8000/health"
DETAILED_URL="http://localhost:8000/health?detail=true"

# 基础健康检查
response=$(curl -s -w "%{http_code}" $HEALTH_URL)
status_code=${response: -3}

if [ "$status_code" -eq 200 ]; then
    echo "✅ 服务健康"
else
    echo "❌ 服务异常 (HTTP $status_code)"
    exit 1
fi

# 详细检查
detailed_response=$(curl -s $DETAILED_URL)
pansou_status=$(echo $detailed_response | jq -r '.pansou.status')

if [ "$pansou_status" != "connected" ]; then
    echo "⚠️ PanSou 连接异常: $pansou_status"
fi
```

### 性能监控脚本

```bash
#!/bin/bash
# performance-monitor.sh

URL="http://localhost:8000/health?detail=true"

while true; do
    response=$(curl -s $URL)
    
    # 提取指标
    avg_response_time=$(echo $response | jq -r '.backend.response_time_ms')
    success_rate=$(echo $response | jq -r '.metrics.success_rate_percent')
    error_rate=$(echo $response | jq -r '.metrics.error_rate_percent')
    
    echo "$(date): 平均响应时间: ${avg_response_time}ms, 成功率: ${success_rate}%, 错误率: ${error_rate}%"
    
    # 检查告警阈值
    if (( $(echo "$success_rate < 95" | bc -l) )); then
        echo "🚨 告警: 成功率低于 95%"
    fi
    
    sleep 60
done
```

## 🐳 Docker 部署

### 环境变量配置

```bash
# .env 文件
PANSOU_HOST=https://your-pansou-instance.com
PANSOU_USER=your_username
PANSOU_PWD=your_password
RATE_LIMIT_PER_MINUTE=60
LOG_LEVEL=INFO
CORS_ALLOW_ORIGINS=*
```

### Docker Compose 监控

```yaml
# docker-compose.monitoring.yml
version: '3.8'
services:
  openmeta:
    build: .
    ports:
      - "8000:8000"
    environment:
      - RATE_LIMIT_PER_MINUTE=60
      - LOG_LEVEL=INFO
    volumes:
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## 🚀 Vercel 部署

### 环境变量配置

在 Vercel Dashboard 中配置环境变量：

```
PANSOU_HOST=https://your-pansou-instance.com
PANSOU_USER=your_username
PANSOU_PWD=your_password
RATE_LIMIT_PER_MINUTE=60
LOG_LEVEL=INFO
```

### 无服务器函数监控

Vercel 会自动提供：
- 函数执行时间监控
- 冷启动时间统计
- 内存使用监控

## 🔍 故障排查

### 常见问题

#### 1. PanSou 连接失败
```bash
# 检查配置
curl -H "Authorization: Bearer $TOKEN" https://your-pansou-instance.com/api/health

# 检查日志
docker logs openmeta-container | grep PanSou
```

#### 2. 速率限制过严
```bash
# 调整限制
export RATE_LIMIT_PER_MINUTE=120

# 检查当前使用情况
curl -I http://localhost:8000/api/search
```

#### 3. 内存使用过高
```bash
# 检查系统指标
curl http://localhost:8000/health?detail=true | jq '.system.memory'

# 监控内存趋势
watch -n 5 'curl -s http://localhost:8000/health?detail=true | jq ".system.memory"'
```

### 日志分析

#### 搜索错误分析
```bash
# 查找错误日志
grep "ERROR" logs/app.log | jq 'select(.message | contains("搜索失败"))'

# 按请求 ID 查找
grep "550e8400-e29b-41d4-a716-446655440000" logs/app.log
```

#### 性能分析
```bash
# 慢请求分析
grep '"duration_ms":' logs/app.log | jq 'select(.duration_ms > 1000)' | jq '.path, .duration_ms'

# 高频访问分析
jq 'group_by(.path) | map({path: .[0].path, count: length}) | sort_by(.count) | reverse' logs/app.log
```

## 📊 仪表板建议

### Grafana 仪表板指标

1. **请求概览**
   - 总请求数（实时）
   - 成功率趋势
   - 错误率趋势

2. **性能指标**
   - 平均响应时间
   - P95/P99 响应时间
   - 请求分布

3. **业务指标**
   - 热门搜索词
   - PanSou 连接状态
   - 缓存命中率

4. **系统指标**
   - CPU 使用率
   - 内存使用率
   - 磁盘使用率

### 告警规则

```yaml
# prometheus-rules.yml
groups:
  - name: openmeta-alerts
    rules:
      - alert: OpenMetaHighErrorRate
        expr: openmeta_error_rate > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "OpenMeta 错误率过高"
          
      - alert: OpenMetaSlowResponse
        expr: openmeta_response_time_p95 > 1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "OpenMeta 响应时间过长"
```

## 🔒 安全监控

### 异常检测

1. **异常请求量**: 突增的请求可能表示攻击
2. **异常路径访问**: 访问管理端点或 API 文档
3. **异常 User-Agent**: 识别爬虫或恶意工具

### 日志安全

- 敏感信息过滤（密码、Token）
- IP 地址脱敏处理
- 请求体内容过滤

---

## 📞 技术支持

如遇到监控或运维问题，请：

1. 检查 `/health?detail=true` 端点
2. 查看应用日志
3. 验证环境变量配置
4. 检查 PanSou 服务状态

更多详细信息请参考项目 README 和代码注释。

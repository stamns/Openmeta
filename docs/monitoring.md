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
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
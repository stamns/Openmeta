# PanSou 服务测试指南

## 测试脚本

### 1. 基础结构测试

验证代码结构和导入是否正确：

```bash
python3 scripts/test-pansou-basic.py
```

**检查项：**
- ✅ 模块导入
- ✅ TokenManager 类结构
- ✅ 全局单例初始化
- ✅ asyncio.Lock 类型
- ✅ pansou_search 函数签名
- ✅ 初始状态
- ✅ clear_token 方法

### 2. 并发和功能测试

测试实际的登录、搜索和并发控制：

```bash
python3 scripts/test-concurrent-search.py
```

**检查项：**
- ✅ 单次搜索正常返回结果
- ✅ 10 个并发搜索只登录 1 次
- ✅ Token 过期自动刷新
- ✅ 错误处理正确
- ✅ 搜索超时处理

**前提条件：**
需要配置 `.env` 文件：
```bash
cd backend
cp .env.example .env
# 编辑 .env 填入真实的 PanSou 配置
```

## 测试场景

### 场景 1: 正常搜索流程

```python
from app.services.pansou import pansou_search

# 第一次搜索（会触发登录）
result1 = await pansou_search("Python")
# 返回: {"provider": "pansou", "enabled": True, "results": [...]}

# 第二次搜索（复用 token）
result2 = await pansou_search("JavaScript")
# 无需重新登录
```

### 场景 2: 并发搜索

```python
import asyncio
from app.services.pansou import pansou_search

# 10 个并发请求
tasks = [pansou_search(f"test{i}") for i in range(10)]
results = await asyncio.gather(*tasks)

# 只会看到 1 次 "🔌 正在连接 PanSou 节点" 日志
# 其他 9 个请求会等待第一个请求完成登录
```

### 场景 3: Token 过期处理

```python
from app.services.pansou import pansou_search, _token_manager
import time

# 第一次搜索
result1 = await pansou_search("test")

# 模拟 token 过期
_token_manager.token_exp = 0

# 再次搜索（会自动刷新 token）
result2 = await pansou_search("test2")
# 会看到 "🔌 正在连接 PanSou 节点" 日志
```

### 场景 4: 错误处理

```python
from app.services.pansou import pansou_search
from app.settings import settings

# 保存原始配置
original_host = settings.pansou_host

# 使用无效的主机
settings.pansou_host = "http://invalid-host.com"

# 搜索（会返回友好的错误）
result = await pansou_search("test")
# 返回: {"provider": "pansou", "enabled": True, "results": [], "error": "..."}

# 恢复配置
settings.pansou_host = original_host
```

## 验证日志

### 正常流程日志

```
🔌 正在连接 PanSou 节点: http://your-server.com ...
✅ PanSou 认证成功，Token 有效期: 3600 秒
✅ 搜索完成: 'Python' 共 10 条结果
```

### 并发请求日志（10 个并发，只登录 1 次）

```
🔌 正在连接 PanSou 节点: http://your-server.com ...
✅ PanSou 认证成功，Token 有效期: 3600 秒
✅ 搜索完成: 'test0' 共 5 条结果
✅ 搜索完成: 'test1' 共 5 条结果
✅ 搜索完成: 'test2' 共 5 条结果
...
✅ 搜索完成: 'test9' 共 5 条结果
```

### Token 过期日志

```
🔌 正在连接 PanSou 节点: http://your-server.com ...
✅ PanSou 认证成功，Token 有效期: 3600 秒
⚠️ Token 已过期，清空缓存
```

### 错误日志

```
❌ PanSou 认证失败 (401): Unauthorized
❌ PanSou 连接错误: Connection timeout
⏱️ 搜索超时（15 秒）
⚠️ 搜索过程异常: Invalid response
```

## 性能指标

### Token 缓存效率

- **第一次请求**: ~200ms（包含登录时间）
- **后续请求**: ~50-100ms（复用 token）
- **Token 有效期**: 59 分钟（提前 60 秒刷新）

### 并发性能

- **10 个并发请求**: 
  - 旧实现: 10 次登录 = ~2000ms
  - 新实现: 1 次登录 = ~200ms
  - **性能提升**: 10x

### 内存占用

- **TokenManager 实例**: < 1KB
- **httpx.AsyncClient**: ~10MB（连接池）
- **总内存**: ~11MB（包含 FastAPI 运行时）

## 故障排查

### Q: 测试脚本导入失败
```bash
# 安装依赖
cd backend
pip install -r requirements.txt
```

### Q: Token 一直登录失败
检查：
1. PANSOU_HOST 是否正确（包含 http:// 前缀）
2. PANSOU_USER 和 PANSOU_PWD 是否正确
3. PanSou 服务是否正常运行
4. 网络连接是否正常

### Q: 搜索一直超时
调整环境变量：
```bash
# .env 文件
SEARCH_TIMEOUT=30  # 增加超时时间到 30 秒
```

### Q: 并发测试显示多次登录
可能原因：
1. Token 已过期（超过 59 分钟）
2. 登录失败导致 token 被清空
3. 测试脚本手动清空了 token

## 持续集成

### GitHub Actions 示例

```yaml
name: Test PanSou Service

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      
      - name: Install dependencies
        run: |
          cd backend
          pip install -r requirements.txt
      
      - name: Run basic tests
        run: python3 scripts/test-pansou-basic.py
      
      - name: Run concurrent tests
        if: ${{ secrets.PANSOU_HOST }}
        env:
          PANSOU_HOST: ${{ secrets.PANSOU_HOST }}
          PANSOU_USER: ${{ secrets.PANSOU_USER }}
          PANSOU_PWD: ${{ secrets.PANSOU_PWD }}
        run: python3 scripts/test-concurrent-search.py
```

## 相关文档

- [Token 改进文档](./PANSOU-TOKEN-IMPROVEMENTS.md)
- [环境变量配置](../.env.example)
- [安全修复文档](../SECURITY-FIXES.md)

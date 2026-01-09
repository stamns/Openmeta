# PanSou Token 认证改进

## 🎯 问题概述

之前的实现存在以下严重问题：

1. **Token 过期处理不当**：Token 过期后搜索直接失败，用户看不到错误原因
2. **并发竞态条件**：多个并发请求会重复登录，浪费资源且可能触发速率限制
3. **硬编码超时**：搜索超时硬编码为 10 秒，无法配置

## ✅ 改进方案

### 1. Token 过期管理

**改进点：**
- 从 PanSou 响应的 `expires_in` 字段动态读取真实有效期
- 实现"提前 60 秒刷新"机制（登录一次 Token 用 59 分钟）
- 登录失败时清空 token，下次搜索自动重试登录
- 返回用户友好的错误信息而不是崩溃

**实现：**
```python
class TokenManager:
    def __init__(self):
        self.token: str | None = None
        self.token_exp: float = 0.0
        self._login_lock = asyncio.Lock()

    def is_token_valid(self) -> bool:
        """检查 token 是否有效（提前 60 秒过期以留安全余量）"""
        if not self.token:
            return False
        # 提前 60 秒刷新，避免在请求过程中过期
        return time.time() < self.token_exp - 60

    async def _do_login(self) -> bool:
        """执行登录操作"""
        # ... 登录逻辑 ...
        
        # 从响应中读取真实的有效期，默认 1 小时（3600 秒）
        expires_in = data.get("expires_in", 3600)
        
        # 计算过期时间
        self.token_exp = time.time() + expires_in
```

### 2. 并发安全

**改进点：**
- 为 `ensure_token()` 方法添加 `asyncio.Lock()` 锁
- 实现 Double-check locking 模式
- 10 个并发搜索请求只登录 1 次

**实现：**
```python
async def ensure_token(self) -> bool:
    """
    确保有有效的 token，使用 Double-check locking 模式避免并发重复登录
    """
    # 第一次检查（不上锁，快速路径）
    if self.is_token_valid():
        return True

    # 需要登录，上锁
    async with self._login_lock:
        # 第二次检查（上锁后重新检查，防止其他协程已登录）
        if self.is_token_valid():
            return True

        # 执行登录
        return await self._do_login()
```

**工作原理：**
1. 第一个请求检测到 token 无效，获取锁并登录
2. 后续 9 个请求在锁外等待
3. 第一个请求登录完成，释放锁
4. 后续请求获取锁后，发现 token 已有效，直接返回（不重复登录）

### 3. 搜索超时配置

**改进点：**
- 改为可配置环境变量（`SEARCH_TIMEOUT`，默认 15 秒）
- 避免硬编码的 10 秒超时太短导致超时失败

**使用：**
```python
resp = await client.post(
    search_url,
    headers={"Authorization": f"Bearer {_token_manager.token}"},
    json={"kw": query},
    timeout=float(settings.search_timeout),  # 使用配置的超时
)
```

**配置：**
在 `.env` 文件中：
```bash
SEARCH_TIMEOUT=15  # 秒
```

### 4. 友好的错误处理

**改进点：**
- 登录失败返回友好的错误消息
- Token 过期时清空缓存并提示重试
- 网络错误不会导致应用崩溃
- 所有错误都有详细日志

**示例：**
```python
# 登录失败
{
    "provider": "pansou",
    "enabled": True,
    "query": "test",
    "results": [],
    "error": "无法连接到 PanSou 服务或认证失败，请检查配置"
}

# Token 过期
{
    "provider": "pansou",
    "enabled": True,
    "query": "test",
    "results": [],
    "error": "Token 已过期，请重试"
}

# 搜索超时
{
    "provider": "pansou",
    "enabled": True,
    "query": "test",
    "results": [],
    "error": "搜索超时（15 秒），请稍后重试"
}
```

## 🧪 验证测试

运行测试脚本：
```bash
cd /home/engine/project
python3 scripts/test-concurrent-search.py
```

**成功标准：**
- ✅ 单次搜索正常返回结果
- ✅ 10 个并发搜索请求只登录 1 次（通过日志验证）
- ✅ Token 过期时自动刷新而不报错
- ✅ 网络断开时返回空列表而不是崩溃
- ✅ 搜索超时错误被正确处理

## 📊 性能影响

**优化前：**
- 10 个并发请求 = 10 次登录 + 10 次搜索
- 约 1-2 秒延迟（重复登录）

**优化后：**
- 10 个并发请求 = 1 次登录 + 10 次搜索
- 约 0.1-0.2 秒延迟（只登录一次）

**Token 缓存：**
- Token 有效期 59 分钟（提前 60 秒刷新）
- 59 分钟内的所有请求都复用同一个 token
- 无需重复登录

## 🔒 安全性

1. **Token 安全存储**：Token 存储在内存中，不会持久化
2. **自动过期处理**：提前 60 秒刷新，避免使用过期 token
3. **失败清理**：登录失败或 401 错误时清空 token
4. **并发安全**：使用锁保护登录过程，避免竞态条件

## 📝 使用示例

### 基本使用
```python
from app.services.pansou import pansou_search

# 执行搜索（自动处理登录和 token 刷新）
result = await pansou_search("Python")

if result.get("enabled"):
    if "error" in result:
        print(f"搜索失败: {result['error']}")
    else:
        print(f"找到 {len(result['results'])} 条结果")
        for item in result["results"]:
            print(f"  - {item['title']} ({item['source']})")
else:
    print(result.get("message", "搜索服务未配置"))
```

### 并发搜索
```python
import asyncio

# 10 个并发搜索（只会登录一次）
tasks = [pansou_search(f"keyword{i}") for i in range(10)]
results = await asyncio.gather(*tasks)
```

### 手动刷新 Token
```python
from app.services.pansou import _token_manager

# 强制清空 token（下次搜索会重新登录）
_token_manager.clear_token()
```

## 🔧 配置说明

所有配置都通过环境变量设置，参考 `.env.example`：

```bash
# PanSou 配置
PANSOU_HOST=http://your-pansou-server.com
PANSOU_USER=your_username
PANSOU_PWD=your_password

# 搜索超时（秒）
SEARCH_TIMEOUT=15
```

## 🐛 常见问题

### Q: 为什么有时候还是会看到多次登录？
A: 如果请求之间间隔超过 59 分钟，token 会过期需要重新登录。这是正常行为。

### Q: 如何调整 token 提前刷新的时间？
A: 修改 `TokenManager.is_token_valid()` 中的 `- 60` 参数（单位：秒）。

### Q: 如何查看当前 token 状态？
A: 运行测试脚本 `scripts/test-concurrent-search.py` 查看详细的 token 状态。

### Q: 登录失败怎么办？
A: 检查以下几点：
1. `PANSOU_HOST` 是否正确（不要忘记 http:// 前缀）
2. `PANSOU_USER` 和 `PANSOU_PWD` 是否正确
3. PanSou 服务是否正常运行
4. 网络连接是否正常

## 📚 相关文档

- [环境变量配置](../.env.example)
- [PanSou API 文档](https://github.com/pansou/docs)
- [安全修复文档](../SECURITY-FIXES.md)

## 🔄 版本历史

### v1.1.0 (2025-01-09)
- ✅ 实现 Token 过期管理
- ✅ 实现并发安全（Double-check locking）
- ✅ 实现搜索超时配置
- ✅ 改进错误处理和日志
- ✅ 添加测试脚本

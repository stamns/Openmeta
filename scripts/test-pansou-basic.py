#!/usr/bin/env python3
"""
PanSou 服务基础测试

快速验证：
1. 模块导入
2. TokenManager 类结构
3. 基本方法存在
"""

import sys
from pathlib import Path

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent.parent / "backend"
sys.path.insert(0, str(backend_dir))

print("="*60)
print("PanSou 服务基础测试")
print("="*60)

# 测试 1: 导入模块
print("\n✅ 测试 1: 导入模块...")
try:
    from app.services.pansou import pansou_search, _token_manager, TokenManager
    print("   ✓ 成功导入: pansou_search, _token_manager, TokenManager")
except ImportError as e:
    print(f"   ✗ 导入失败: {e}")
    sys.exit(1)

# 测试 2: TokenManager 结构
print("\n✅ 测试 2: TokenManager 类结构...")
try:
    assert hasattr(TokenManager, '__init__'), "缺少 __init__ 方法"
    assert hasattr(TokenManager, 'is_token_valid'), "缺少 is_token_valid 方法"
    assert hasattr(TokenManager, 'ensure_token'), "缺少 ensure_token 方法"
    assert hasattr(TokenManager, 'clear_token'), "缺少 clear_token 方法"
    assert hasattr(TokenManager, '_do_login'), "缺少 _do_login 方法"
    print("   ✓ TokenManager 类结构完整")
except AssertionError as e:
    print(f"   ✗ TokenManager 结构检查失败: {e}")
    sys.exit(1)

# 测试 3: 全局单例
print("\n✅ 测试 3: 全局 TokenManager 单例...")
try:
    assert isinstance(_token_manager, TokenManager), "_token_manager 不是 TokenManager 实例"
    assert hasattr(_token_manager, 'token'), "缺少 token 属性"
    assert hasattr(_token_manager, 'token_exp'), "缺少 token_exp 属性"
    assert hasattr(_token_manager, '_login_lock'), "缺少 _login_lock 属性"
    print("   ✓ 全局 TokenManager 单例正常")
except AssertionError as e:
    print(f"   ✗ 全局单例检查失败: {e}")
    sys.exit(1)

# 测试 4: asyncio.Lock
print("\n✅ 测试 4: asyncio.Lock 类型检查...")
try:
    import asyncio
    assert isinstance(_token_manager._login_lock, asyncio.Lock), "_login_lock 不是 asyncio.Lock 实例"
    print("   ✓ asyncio.Lock 正确初始化")
except AssertionError as e:
    print(f"   ✗ Lock 类型检查失败: {e}")
    sys.exit(1)

# 测试 5: pansou_search 函数
print("\n✅ 测试 5: pansou_search 函数...")
try:
    import inspect
    assert inspect.iscoroutinefunction(pansou_search), "pansou_search 不是协程函数"
    sig = inspect.signature(pansou_search)
    assert 'query' in sig.parameters, "缺少 query 参数"
    print("   ✓ pansou_search 函数签名正确")
except AssertionError as e:
    print(f"   ✗ pansou_search 检查失败: {e}")
    sys.exit(1)

# 测试 6: 初始状态
print("\n✅ 测试 6: TokenManager 初始状态...")
try:
    assert _token_manager.token is None, "初始 token 应该为 None"
    assert _token_manager.token_exp == 0.0, "初始 token_exp 应该为 0.0"
    assert not _token_manager.is_token_valid(), "初始状态 token 不应该有效"
    print("   ✓ TokenManager 初始状态正确")
except AssertionError as e:
    print(f"   ✗ 初始状态检查失败: {e}")
    sys.exit(1)

# 测试 7: clear_token 方法
print("\n✅ 测试 7: clear_token 方法...")
try:
    # 设置一些值
    _token_manager.token = "test_token"
    _token_manager.token_exp = 999999999.0
    
    # 清空
    _token_manager.clear_token()
    
    # 验证
    assert _token_manager.token is None, "clear_token 后 token 应该为 None"
    assert _token_manager.token_exp == 0.0, "clear_token 后 token_exp 应该为 0.0"
    print("   ✓ clear_token 方法正常工作")
except AssertionError as e:
    print(f"   ✗ clear_token 测试失败: {e}")
    sys.exit(1)

print("\n" + "="*60)
print("✅ 所有基础测试通过")
print("="*60)
print("\n提示：运行 scripts/test-concurrent-search.py 进行完整功能测试")

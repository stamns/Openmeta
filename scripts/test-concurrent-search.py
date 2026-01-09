#!/usr/bin/env python3
"""
并发搜索测试脚本

验证：
1. 多个并发请求只登录一次
2. Token 过期后自动刷新
3. 搜索超时正确处理
4. 错误处理友好
"""

import asyncio
import sys
import os
from pathlib import Path

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent.parent / "backend"
sys.path.insert(0, str(backend_dir))

# 加载环境变量
from dotenv import load_dotenv
env_file = backend_dir / ".env"
if env_file.exists():
    load_dotenv(env_file)
    print(f"✅ 已加载环境变量: {env_file}")
else:
    print(f"⚠️ 未找到 .env 文件: {env_file}")

from app.services.pansou import pansou_search, _token_manager


async def test_single_search():
    """测试单次搜索"""
    print("\n" + "="*60)
    print("测试 1: 单次搜索")
    print("="*60)
    
    result = await pansou_search("Python")
    
    print(f"\n结果:")
    print(f"  Provider: {result.get('provider')}")
    print(f"  Enabled: {result.get('enabled')}")
    print(f"  Results: {len(result.get('results', []))} 条")
    
    if "error" in result:
        print(f"  Error: {result['error']}")
    
    return result


async def test_concurrent_search():
    """测试并发搜索（应该只登录一次）"""
    print("\n" + "="*60)
    print("测试 2: 10 个并发搜索（应该只登录 1 次）")
    print("="*60)
    
    # 清空 token 强制重新登录
    _token_manager.clear_token()
    print("\n已清空 token，准备并发测试...")
    
    # 启动 10 个并发搜索
    tasks = [
        pansou_search(f"test{i}")
        for i in range(10)
    ]
    
    print("\n🚀 启动 10 个并发搜索请求...")
    results = await asyncio.gather(*tasks)
    
    print(f"\n结果:")
    print(f"  完成请求数: {len(results)}")
    print(f"  成功请求数: {sum(1 for r in results if r.get('results'))}")
    print(f"  失败请求数: {sum(1 for r in results if 'error' in r)}")
    
    return results


async def test_token_expiry():
    """测试 Token 过期处理"""
    print("\n" + "="*60)
    print("测试 3: Token 过期处理")
    print("="*60)
    
    # 先确保有 token
    await _token_manager.ensure_token()
    
    if _token_manager.token:
        print(f"\n当前 Token: {_token_manager.token[:20]}...")
        print(f"Token 过期时间: {_token_manager.token_exp}")
        print(f"Token 是否有效: {_token_manager.is_token_valid()}")
        
        # 模拟 token 过期
        print("\n模拟 Token 过期（设置过期时间为 0）...")
        _token_manager.token_exp = 0
        print(f"Token 是否有效: {_token_manager.is_token_valid()}")
        
        # 再次搜索，应该自动刷新 token
        print("\n执行搜索（应该自动刷新 Token）...")
        result = await pansou_search("test")
        
        print(f"\n结果:")
        print(f"  Token 是否有效: {_token_manager.is_token_valid()}")
        print(f"  搜索是否成功: {'error' not in result}")
    else:
        print("\n⚠️ 无法获取 token，跳过此测试")


async def test_error_handling():
    """测试错误处理"""
    print("\n" + "="*60)
    print("测试 4: 错误处理")
    print("="*60)
    
    # 保存原始配置
    from app.settings import settings
    original_host = settings.pansou_host
    
    # 测试无效的主机
    print("\n测试 4.1: 无效的主机地址")
    settings.pansou_host = "http://invalid-host-12345.com"
    _token_manager.clear_token()
    
    result = await pansou_search("test")
    print(f"  Provider: {result.get('provider')}")
    print(f"  Has Error: {'error' in result}")
    print(f"  Error Message: {result.get('error', 'N/A')}")
    
    # 恢复原始配置
    settings.pansou_host = original_host
    
    print("\n✅ 错误处理测试完成")


async def main():
    """运行所有测试"""
    print("="*60)
    print("PanSou 搜索服务测试")
    print("="*60)
    
    try:
        # 测试 1: 单次搜索
        await test_single_search()
        
        # 测试 2: 并发搜索
        await test_concurrent_search()
        
        # 测试 3: Token 过期
        await test_token_expiry()
        
        # 测试 4: 错误处理
        await test_error_handling()
        
        print("\n" + "="*60)
        print("✅ 所有测试完成")
        print("="*60)
        
    except KeyboardInterrupt:
        print("\n\n⚠️ 测试被用户中断")
    except Exception as e:
        print(f"\n\n❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())

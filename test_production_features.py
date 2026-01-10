#!/usr/bin/env python3
"""
OpenMeta 生产级功能测试脚本
测试日志系统、速率限制、健康检查和监控指标
"""

import asyncio
import json
import os
import sys
import time
from typing import Dict, Any

import httpx


class OpenMetaTester:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.client = httpx.AsyncClient(timeout=10.0)
        
    async def test_health_basic(self) -> Dict[str, Any]:
        """测试基础健康检查"""
        print("🧪 测试基础健康检查...")
        
        try:
            response = await self.client.get(f"{self.base_url}/health")
            data = response.json()
            
            print(f"✅ 状态码: {response.status_code}")
            print(f"✅ 响应: {json.dumps(data, indent=2, ensure_ascii=False)}")
            
            assert response.status_code == 200
            assert data["status"] == "ok"
            assert "service" in data
            assert "version" in data
            
            return {"success": True, "data": data}
            
        except Exception as e:
            print(f"❌ 基础健康检查失败: {e}")
            return {"success": False, "error": str(e)}
    
    async def test_health_detailed(self) -> Dict[str, Any]:
        """测试详细健康检查"""
        print("\n🧪 测试详细健康检查...")
        
        try:
            response = await self.client.get(f"{self.base_url}/health?detail=true")
            data = response.json()
            
            print(f"✅ 状态码: {response.status_code}")
            print(f"✅ 响应大小: {len(json.dumps(data))} 字符")
            
            assert response.status_code == 200
            assert "backend" in data
            assert "pansou" in data
            assert "system" in data
            assert "metrics" in data
            
            # 检查后端信息
            backend = data["backend"]
            assert "status" in backend
            assert "response_time_ms" in backend
            
            # 检查系统信息
            system = data["system"]
            assert "memory" in system
            assert "cpu" in system
            
            # 检查指标
            metrics = data["metrics"]
            assert "total_requests" in metrics
            assert "success_rate_percent" in metrics
            
            print(f"✅ 后端状态: {backend['status']}")
            print(f"✅ 后端响应时间: {backend['response_time_ms']}ms")
            print(f"✅ 总请求数: {metrics['total_requests']}")
            print(f"✅ 成功率: {metrics['success_rate_percent']}%")
            
            return {"success": True, "data": data}
            
        except Exception as e:
            print(f"❌ 详细健康检查失败: {e}")
            return {"success": False, "error": str(e)}
    
    async def test_rate_limiting(self) -> Dict[str, Any]:
        """测试速率限制"""
        print("\n🧪 测试速率限制...")
        
        try:
            # 快速发送多个请求
            tasks = []
            for i in range(65):  # 超过默认限制 60
                task = self.client.get(f"{self.base_url}/health")
                tasks.append(task)
            
            responses = await asyncio.gather(*tasks, return_exceptions=True)
            
            success_count = 0
            rate_limited_count = 0
            rate_limit_headers = []
            
            for i, response in enumerate(responses):
                if isinstance(response, Exception):
                    print(f"请求 {i+1} 异常: {response}")
                    continue
                
                if response.status_code == 200:
                    success_count += 1
                    # 检查限流头
                    if "X-RateLimit-Limit" in response.headers:
                        rate_limit_headers.append({
                            "limit": response.headers.get("X-RateLimit-Limit"),
                            "remaining": response.headers.get("X-RateLimit-Remaining"),
                            "reset": response.headers.get("X-RateLimit-Reset")
                        })
                elif response.status_code == 429:
                    rate_limited_count += 1
                    rate_limit_data = response.json()
                    print(f"✅ 请求 {i+1} 被限流: {rate_limit_data}")
            
            print(f"✅ 成功请求: {success_count}")
            print(f"✅ 被限流请求: {rate_limited_count}")
            
            if rate_limit_headers:
                print(f"✅ 限流头示例: {rate_limit_headers[0]}")
            
            # 验证限流头
            for header in rate_limit_headers:
                assert "limit" in header
                assert "remaining" in header
                assert "reset" in header
            
            return {
                "success": True,
                "success_count": success_count,
                "rate_limited_count": rate_limited_count,
                "rate_limit_headers": rate_limit_headers
            }
            
        except Exception as e:
            print(f"❌ 速率限制测试失败: {e}")
            return {"success": False, "error": str(e)}
    
    async def test_structured_logging(self) -> Dict[str, Any]:
        """测试结构化日志（通过多次请求观察日志输出）"""
        print("\n🧪 测试结构化日志...")
        
        try:
            # 发送几个请求以生成日志
            for i in range(3):
                response = await self.client.get(f"{self.base_url}/health")
                await asyncio.sleep(0.1)
            
            print("✅ 已发送请求用于日志测试")
            print("ℹ️  请检查控制台输出的 JSON 格式日志")
            
            return {"success": True, "message": "请检查控制台日志输出"}
            
        except Exception as e:
            print(f"❌ 结构化日志测试失败: {e}")
            return {"success": False, "error": str(e)}
    
    async def test_search_endpoint(self) -> Dict[str, Any]:
        """测试搜索端点"""
        print("\n🧪 测试搜索端点...")
        
        try:
            # 测试搜索（可能因为 PanSou 未配置而失败，但应该能返回结构化错误）
            response = await self.client.get(
                f"{self.base_url}/api/search",
                params={"q": "test", "page": 1}
            )
            
            data = response.json()
            
            print(f"✅ 状态码: {response.status_code}")
            print(f"✅ 响应: {json.dumps(data, indent=2, ensure_ascii=False)}")
            
            # 检查响应头中的限流信息
            if "X-RateLimit-Limit" in response.headers:
                print(f"✅ 限流头: {response.headers.get('X-RateLimit-Limit')}")
            
            # 验证基本结构
            assert "q" in data
            assert "page" in data
            assert "items" in data
            assert "provider" in data
            assert "enabled" in data
            
            return {"success": True, "data": data}
            
        except Exception as e:
            print(f"❌ 搜索端点测试失败: {e}")
            return {"success": False, "error": str(e)}
    
    async def test_error_handling(self) -> Dict[str, Any]:
        """测试错误处理"""
        print("\n🧪 测试错误处理...")
        
        try:
            # 测试 404
            response = await self.client.get(f"{self.base_url}/nonexistent")
            assert response.status_code == 404
            data = response.json()
            assert "error" in data
            assert "request_id" in data  # 应该包含请求 ID
            print(f"✅ 404 处理正常: {data}")
            
            return {"success": True}
            
        except Exception as e:
            print(f"❌ 错误处理测试失败: {e}")
            return {"success": False, "error": str(e)}
    
    async def run_all_tests(self) -> Dict[str, Any]:
        """运行所有测试"""
        print("🚀 开始 OpenMeta 生产级功能测试\n")
        
        results = {
            "health_basic": await self.test_health_basic(),
            "health_detailed": await self.test_health_detailed(),
            "rate_limiting": await self.test_rate_limiting(),
            "structured_logging": await self.test_structured_logging(),
            "search_endpoint": await self.test_search_endpoint(),
            "error_handling": await self.test_error_handling()
        }
        
        # 总结
        print("\n" + "="*50)
        print("📊 测试结果总结")
        print("="*50)
        
        success_count = 0
        total_count = len(results)
        
        for test_name, result in results.items():
            status = "✅ 通过" if result["success"] else "❌ 失败"
            print(f"{test_name}: {status}")
            if result["success"]:
                success_count += 1
        
        print(f"\n总计: {success_count}/{total_count} 测试通过")
        
        if success_count == total_count:
            print("🎉 所有测试通过！")
        else:
            print("⚠️  部分测试失败，请检查日志")
        
        return results
    
    async def close(self):
        """关闭客户端"""
        await self.client.aclose()


async def main():
    """主函数"""
    base_url = os.getenv("TEST_BASE_URL", "http://localhost:8000")
    
    print(f"🎯 测试目标: {base_url}")
    
    # 检查服务是否可用
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{base_url}/health", timeout=5.0)
            print(f"✅ 服务可用，状态码: {response.status_code}")
    except Exception as e:
        print(f"❌ 无法连接到 {base_url}")
        print("请确保 OpenMeta 服务正在运行：")
        print("cd backend && python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000")
        sys.exit(1)
    
    # 运行测试
    tester = OpenMetaTester(base_url)
    
    try:
        results = await tester.run_all_tests()
        return results
    finally:
        await tester.close()


if __name__ == "__main__":
    results = asyncio.run(main())
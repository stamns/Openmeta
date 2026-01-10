#!/usr/bin/env python3
"""
OpenMeta 监控功能测试脚本
测试新实现的日志系统、速率限制和健康检查功能
"""

import json
import time
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

def test_health_endpoint():
    """测试健康检查端点"""
    print("🔍 测试健康检查端点...")
    
    # 基础健康检查
    try:
        response = requests.get('http://localhost:8000/health', timeout=5)
        print(f"✅ 基础健康检查: {response.status_code}")
        print(f"   响应: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
    except Exception as e:
        print(f"❌ 基础健康检查失败: {e}")
    
    # 详细健康检查
    try:
        response = requests.get('http://localhost:8000/health?detail=true', timeout=10)
        print(f"✅ 详细健康检查: {response.status_code}")
        data = response.json()
        print(f"   PanSou 状态: {data.get('pansou', {}).get('status', 'unknown')}")
        print(f"   Redis 状态: {data.get('redis', {}).get('available', False)}")
        print(f"   错误率: {data.get('performance', {}).get('error_rate', 0)}%")
    except Exception as e:
        print(f"❌ 详细健康检查失败: {e}")

def test_metrics_endpoint():
    """测试监控指标端点"""
    print("\n📊 测试监控指标端点...")
    
    try:
        response = requests.get('http://localhost:8000/metrics', timeout=5)
        print(f"✅ 监控指标: {response.status_code}")
        data = response.json()
        print(f"   总请求数: {data.get('total_requests', 0)}")
        print(f"   平均响应时间: {data.get('avg_response_time_ms', 0)}ms")
        print(f"   成功率: {data.get('success_rate', 0)}%")
        print(f"   PanSou 请求数: {data.get('pansou', {}).get('total_requests', 0)}")
    except Exception as e:
        print(f"❌ 监控指标失败: {e}")

def test_rate_limiting():
    """测试速率限制功能"""
    print("\n🚦 测试速率限制功能...")
    
    # 设置一个很低的限制进行测试
    test_limit = 3
    
    def make_request():
        try:
            response = requests.get('http://localhost:8000/api/search?q=test', timeout=5)
            return response.status_code, response.headers.get('X-RateLimit-Remaining', 'N/A')
        except Exception as e:
            return None, str(e)
    
    # 发送请求直到达到限制
    print(f"   发送请求直到达到 {test_limit} 个请求的限制...")
    
    for i in range(test_limit + 2):
        status_code, remaining = make_request()
        if status_code == 429:
            print(f"✅ 第 {i+1} 个请求被限制 (429): 剩余 {remaining}")
            break
        elif status_code:
            print(f"   第 {i+1} 个请求成功: 状态 {status_code}, 剩余 {remaining}")
        else:
            print(f"❌ 第 {i+1} 个请求失败: {remaining}")
        
        time.sleep(0.1)  # 短暂延迟

def test_structured_logging():
    """测试结构化日志（通过多次请求触发日志）"""
    print("\n📝 测试结构化日志...")
    
    print("   发送多个搜索请求以生成日志...")
    
    # 发送几个搜索请求
    for i in range(3):
        try:
            response = requests.get(f'http://localhost:8000/api/search?q=test{i}', timeout=5)
            status_code = response.status_code
            request_id = response.headers.get('X-Request-ID', 'N/A')
            print(f"   请求 {i+1}: 状态 {status_code}, Request-ID: {request_id}")
        except Exception as e:
            print(f"❌ 请求 {i+1} 失败: {e}")
        
        time.sleep(0.2)

def test_concurrent_requests():
    """测试并发请求处理"""
    print("\n⚡ 测试并发请求...")
    
    def make_search_request(i):
        try:
            start_time = time.time()
            response = requests.get(f'http://localhost:8000/api/search?q=concurrent{i}', timeout=10)
            duration = time.time() - start_time
            return {
                'index': i,
                'status_code': response.status_code,
                'duration': duration,
                'request_id': response.headers.get('X-Request-ID', 'N/A')
            }
        except Exception as e:
            return {
                'index': i,
                'status_code': None,
                'duration': time.time(),
                'error': str(e)
            }
    
    # 并发发送 5 个请求
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(make_search_request, i) for i in range(5)]
        
        results = []
        for future in as_completed(futures):
            results.append(future.result())
    
    # 排序结果
    results.sort(key=lambda x: x['index'])
    
    print(f"   并发请求结果:")
    for result in results:
        if 'error' in result:
            print(f"   ❌ 请求 {result['index']}: 错误 {result['error']}")
        else:
            print(f"   ✅ 请求 {result['index']}: 状态 {result['status_code']}, 耗时 {result['duration']:.2f}s")

def test_error_handling():
    """测试错误处理"""
    print("\n🚨 测试错误处理...")
    
    # 测试 404 错误
    try:
        response = requests.get('http://localhost:8000/nonexistent', timeout=5)
        print(f"   404 测试: 状态 {response.status_code}, Request-ID: {response.headers.get('X-Request-ID', 'N/A')}")
    except Exception as e:
        print(f"❌ 404 测试失败: {e}")
    
    # 测试无效搜索参数
    try:
        response = requests.get('http://localhost:8000/api/search', timeout=5)  # 缺少 q 参数
        print(f"   无效参数测试: 状态 {response.status_code}")
    except Exception as e:
        print(f"✅ 无效参数测试: 预期错误 {e}")

def main():
    """主测试函数"""
    print("🧪 OpenMeta 监控功能测试开始...")
    print("=" * 50)
    
    # 等待服务启动
    print("⏳ 等待服务启动...")
    time.sleep(2)
    
    # 运行所有测试
    test_health_endpoint()
    test_metrics_endpoint()
    test_structured_logging()
    test_rate_limiting()
    test_concurrent_requests()
    test_error_handling()
    
    print("\n" + "=" * 50)
    print("🎉 测试完成！")
    print("\n💡 提示:")
    print("   - 检查控制台日志的 JSON 格式输出")
    print("   - 查看 /health?detail=true 获取完整监控信息")
    print("   - 访问 /metrics 查看详细指标")
    print("   - 检查 X-Request-ID 和 X-RateLimit-* 响应头")

if __name__ == "__main__":
    main()
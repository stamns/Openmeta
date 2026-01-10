#!/usr/bin/env python3
"""
OpenMeta 功能验证脚本
"""

import json
import time
import requests


def test_basic_features():
    """测试基本功能"""
    print("🧪 测试 OpenMeta 生产级功能\n")
    
    base_url = "http://localhost:8000"
    
    # 等待速率限制重置
    print("⏳ 等待速率限制重置...")
    time.sleep(65)
    
    # 1. 测试基础健康检查
    print("1️⃣ 测试基础健康检查")
    response = requests.get(f"{base_url}/health")
    data = response.json()
    print(f"   状态码: {response.status_code}")
    print(f"   响应: {json.dumps(data, indent=4)}")
    assert response.status_code == 200
    assert data["status"] == "ok"
    print("   ✅ 基础健康检查通过\n")
    
    # 2. 测试详细健康检查
    print("2️⃣ 测试详细健康检查")
    response = requests.get(f"{base_url}/health?detail=true")
    data = response.json()
    print(f"   状态码: {response.status_code}")
    print(f"   响应大小: {len(json.dumps(data))} 字符")
    assert response.status_code == 200
    assert "backend" in data
    assert "pansou" in data
    assert "system" in data
    assert "metrics" in data
    print("   ✅ 详细健康检查通过\n")
    
    # 3. 测试搜索端点
    print("3️⃣ 测试搜索端点")
    response = requests.get(f"{base_url}/api/search", params={"q": "test", "page": 1})
    data = response.json()
    print(f"   状态码: {response.status_code}")
    print(f"   响应: {json.dumps(data, indent=4)}")
    assert response.status_code == 200
    assert "q" in data
    assert "items" in data
    assert "provider" in data
    print("   ✅ 搜索端点通过\n")
    
    # 4. 测试 404 处理
    print("4️⃣ 测试 404 错误处理")
    response = requests.get(f"{base_url}/nonexistent")
    data = response.json()
    print(f"   状态码: {response.status_code}")
    print(f"   响应: {json.dumps(data, indent=4)}")
    assert response.status_code == 404
    assert "error" in data
    assert "request_id" in data
    print("   ✅ 404 处理通过\n")
    
    print("🎉 所有基本功能测试通过！")


if __name__ == "__main__":
    test_basic_features()
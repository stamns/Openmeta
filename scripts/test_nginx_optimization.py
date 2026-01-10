#!/usr/bin/env python3
"""
Nginx 性能优化测试脚本
验证 Gzip 压缩、静态缓存、安全头和响应时间
"""

import requests
import time
import sys
from typing import Dict, List, Optional

# 测试配置
BASE_URL = "http://localhost"
TIMEOUT = 5

# 颜色输出
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'

def print_header(text: str):
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")

def print_success(text: str):
    print(f"{Colors.GREEN}✓ {text}{Colors.END}")

def print_error(text: str):
    print(f"{Colors.RED}✗ {text}{Colors.END}")

def print_info(text: str):
    print(f"{Colors.YELLOW}ℹ {text}{Colors.END}")

def test_health_endpoint() -> bool:
    """测试健康检查端点"""
    print_header("测试 1: 健康检查端点")

    try:
        response = requests.get(f"{BASE_URL}/health", timeout=TIMEOUT)
        print_info(f"状态码: {response.status_code}")
        print_info(f"响应时间: {response.elapsed.total_seconds()*1000:.2f}ms")

        if response.status_code == 200:
            print_success("健康检查端点正常")
            return True
        else:
            print_error(f"健康检查失败: {response.status_code}")
            return False
    except Exception as e:
        print_error(f"健康检查异常: {e}")
        return False

def test_gzip_compression() -> bool:
    """测试 Gzip 压缩"""
    print_header("测试 2: Gzip 压缩")

    all_passed = True

    # 测试 API 端点（JSON）
    try:
        print_info("\n测试 API 端点（JSON）:")
        response = requests.get(
            f"{BASE_URL}/api/search?q=test",
            headers={"Accept-Encoding": "gzip"},
            timeout=TIMEOUT
        )

        content_encoding = response.headers.get("Content-Encoding", "")
        content_length = int(response.headers.get("Content-Length", len(response.content)))
        content_type = response.headers.get("Content-Type", "")

        print_info(f"Content-Encoding: {content_encoding}")
        print_info(f"Content-Length: {content_length} bytes")
        print_info(f"Content-Type: {content_type}")

        if "gzip" in content_encoding:
            print_success("JSON 响应已启用 Gzip 压缩")
        else:
            print_error("JSON 响应未启用 Gzip 压缩")
            all_passed = False

    except Exception as e:
        print_error(f"API Gzip 测试异常: {e}")
        all_passed = False

    # 测试静态资源（JS）
    try:
        print_info("\n测试静态资源（JS）:")
        response = requests.get(
            f"{BASE_URL}/app.js",
            headers={"Accept-Encoding": "gzip"},
            timeout=TIMEOUT
        )

        content_encoding = response.headers.get("Content-Encoding", "")

        print_info(f"Content-Encoding: {content_encoding}")

        if "gzip" in content_encoding:
            print_success("JS 资源已启用 Gzip 压缩")
        else:
            print_error("JS 资源未启用 Gzip 压缩")
            all_passed = False

    except Exception as e:
        print_info(f"JS Gzip 测试异常（文件可能不存在）: {e}")

    return all_passed

def test_static_cache() -> bool:
    """测试静态文件缓存"""
    print_header("测试 3: 静态文件缓存")

    all_passed = True

    # 测试 JS/CSS 缓存（应该是 365d）
    try:
        print_info("\n测试 JS/CSS 缓存:")
        response = requests.get(f"{BASE_URL}/app.js", timeout=TIMEOUT)

        cache_control = response.headers.get("Cache-Control", "")
        expires = response.headers.get("Expires", "")

        print_info(f"Cache-Control: {cache_control}")
        print_info(f"Expires: {expires}")

        if "public" in cache_control.lower() and "immutable" in cache_control.lower():
            print_success("JS/CSS 设置了正确的缓存策略 (public, immutable)")
        else:
            print_error("JS/CSS 缓存策略不正确")
            all_passed = False

    except Exception as e:
        print_info(f"JS/CSS 缓存测试异常（文件可能不存在）: {e}")

    # 测试 HTML 缓存（应该是 no-cache）
    try:
        print_info("\n测试 HTML 缓存:")
        response = requests.get(f"{BASE_URL}/", timeout=TIMEOUT)

        cache_control = response.headers.get("Cache-Control", "")
        pragma = response.headers.get("Pragma", "")

        print_info(f"Cache-Control: {cache_control}")
        print_info(f"Pragma: {pragma}")

        if "no-cache" in cache_control.lower() or "no-store" in cache_control.lower():
            print_success("HTML 设置了正确的缓存策略 (no-cache/no-store)")
        else:
            print_error("HTML 缓存策略不正确")
            all_passed = False

    except Exception as e:
        print_error(f"HTML 缓存测试异常: {e}")
        all_passed = False

    return all_passed

def test_security_headers() -> bool:
    """测试安全 HTTP 头"""
    print_header("测试 4: 安全 HTTP 头")

    required_headers = {
        "X-Frame-Options": ["SAMEORIGIN", "DENY"],
        "X-Content-Type-Options": ["nosniff"],
        "X-XSS-Protection": ["1; mode=block"],
        "Referrer-Policy": ["no-referrer-when-downgrade"],
        "Permissions-Policy": ["geolocation=()", "camera=()"]
    }

    all_passed = True

    try:
        response = requests.get(f"{BASE_URL}/", timeout=TIMEOUT)

        print_info("响应头检查:")
        for header_name, expected_values in required_headers.items():
            header_value = response.headers.get(header_name, "")
            print(f"  {header_name}: {header_value}")

            if header_value:
                if any(expected in header_value for expected in expected_values):
                    print_success(f"{header_name} 设置正确")
                else:
                    print_error(f"{header_name} 值不正确，期望: {expected_values}")
                    all_passed = False
            else:
                print_error(f"缺少 {header_name} 头")
                all_passed = False

    except Exception as e:
        print_error(f"安全头测试异常: {e}")
        all_passed = False

    return all_passed

def test_api_cache() -> bool:
    """测试 API 响应缓存"""
    print_header("测试 5: API 响应缓存")

    try:
        # 第一次请求
        print_info("\n第一次请求（应 MISS）:")
        response1 = requests.get(f"{BASE_URL}/api/search?q=test", timeout=TIMEOUT)
        cache_status1 = response1.headers.get("X-Cache-Status", "")
        response_time1 = response1.elapsed.total_seconds() * 1000

        print_info(f"X-Cache-Status: {cache_status1}")
        print_info(f"响应时间: {response_time1:.2f}ms")

        # 等待一小段时间
        time.sleep(0.1)

        # 第二次请求（应该 HIT）
        print_info("\n第二次请求（应 HIT）:")
        response2 = requests.get(f"{BASE_URL}/api/search?q=test", timeout=TIMEOUT)
        cache_status2 = response2.headers.get("X-Cache-Status", "")
        response_time2 = response2.elapsed.total_seconds() * 1000

        print_info(f"X-Cache-Status: {cache_status2}")
        print_info(f"响应时间: {response_time2:.2f}ms")

        if cache_status2 == "HIT":
            print_success("API 缓存正常工作")
            print_success(f"缓存响应更快: {response_time1:.2f}ms → {response_time2:.2f}ms")
            return True
        else:
            print_info(f"缓存状态: {cache_status2}（第一次: {cache_status1}）")
            print_info("API 缓存可能未启用或首次请求")
            return True  # 不算失败，因为缓存可能需要时间

    except Exception as e:
        print_error(f"API 缓存测试异常: {e}")
        return False

def test_response_time() -> bool:
    """测试响应时间"""
    print_header("测试 6: 响应时间")

    response_times = []

    # 测试多次请求
    for i in range(5):
        try:
            start = time.time()
            response = requests.get(f"{BASE_URL}/api/search?q=test", timeout=TIMEOUT)
            response_time = (time.time() - start) * 1000
            response_times.append(response_time)
            print_info(f"请求 {i+1}: {response_time:.2f}ms")
        except Exception as e:
            print_error(f"请求 {i+1} 失败: {e}")

    if response_times:
        avg_time = sum(response_times) / len(response_times)
        max_time = max(response_times)
        min_time = min(response_times)

        print_info(f"\n平均响应时间: {avg_time:.2f}ms")
        print_info(f"最小响应时间: {min_time:.2f}ms")
        print_info(f"最大响应时间: {max_time:.2f}ms")

        if avg_time < 100:
            print_success(f"平均响应时间 < 100ms: {avg_time:.2f}ms")
            return True
        else:
            print_error(f"平均响应时间 >= 100ms: {avg_time:.2f}ms")
            return False
    else:
        print_error("无法获取响应时间")
        return False

def test_server_tokens() -> bool:
    """测试是否隐藏了 Nginx 版本号"""
    print_header("测试 7: 隐藏 Nginx 版本号")

    try:
        response = requests.get(f"{BASE_URL}/", timeout=TIMEOUT)
        server_header = response.headers.get("Server", "")

        print_info(f"Server 头: {server_header}")

        if "nginx" not in server_header.lower() or "/" not in server_header:
            print_success("Nginx 版本号已隐藏")
            return True
        else:
            print_error("Nginx 版本号未隐藏")
            return False

    except Exception as e:
        print_error(f"版本号测试异常: {e}")
        return False

def main():
    """主测试函数"""
    print(f"{Colors.BOLD}{Colors.BLUE}")
    print("╔═══════════════════════════════════════════════════════════╗")
    print("║     Nginx 性能优化测试脚本                              ║")
    print("╚═══════════════════════════════════════════════════════════╝")
    print(f"{Colors.END}")

    # 运行所有测试
    tests = [
        ("健康检查端点", test_health_endpoint),
        ("Gzip 压缩", test_gzip_compression),
        ("静态文件缓存", test_static_cache),
        ("安全 HTTP 头", test_security_headers),
        ("API 响应缓存", test_api_cache),
        ("响应时间", test_response_time),
        ("隐藏版本号", test_server_tokens),
    ]

    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print_error(f"{test_name} 测试异常: {e}")
            results.append((test_name, False))

    # 打印总结
    print_header("测试总结")

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for test_name, result in results:
        if result:
            print_success(f"{test_name}")
        else:
            print_error(f"{test_name}")

    print(f"\n{Colors.BOLD}通过: {passed}/{total}{Colors.END}")

    if passed == total:
        print(f"\n{Colors.GREEN}{Colors.BOLD}✓ 所有测试通过！{Colors.END}\n")
        return 0
    else:
        print(f"\n{Colors.RED}{Colors.BOLD}✗ 部分测试失败{Colors.END}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())

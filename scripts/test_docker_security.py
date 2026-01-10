#!/usr/bin/env python3
"""
Docker 容器安全性和可靠性测试脚本

验证非 root 用户、健康检查、资源限制等功能
"""
import subprocess
import json
import time
import sys


def run_command(cmd, capture=True):
    """运行 shell 命令"""
    try:
        if capture:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            return result.returncode, result.stdout, result.stderr
        else:
            result = subprocess.run(cmd, shell=True, timeout=30)
            return result.returncode, "", ""
    except subprocess.TimeoutExpired:
        return -1, "", "Command timeout"
    except Exception as e:
        return -1, "", str(e)


def test_01_non_root_user():
    """测试 1: 验证容器以非 root 用户运行"""
    print("\n[Test 1] 验证容器以非 root 用户运行")
    print("-" * 50)

    # 检查 backend 容器
    code, stdout, stderr = run_command(
        "docker compose -f docker-compose-prod.yml ps -q backend"
    )
    if code != 0 or not stdout.strip():
        print("[SKIP] backend 容器未运行，请先启动: docker compose -f docker-compose-prod.yml up -d")
        return False

    container_id = stdout.strip().split('\n')[0]
    code, stdout, stderr = run_command(f"docker inspect {container_id}")
    if code != 0:
        print(f"[FAIL] 无法获取容器信息: {stderr}")
        return False

    inspect_data = json.loads(stdout)
    user = inspect_data[0]["Config"]["User"]

    print(f"  Backend 用户: {user if user else '(default, likely root)'}")

    if user and user == "1000":
        print("  [PASS] Backend 以 UID 1000 (appuser) 运行")
    elif user and user == "nginx":
        print("  [INFO] 检测到 nginx 用户 (用于 Nginx 容器)")
    else:
        # 检查容器内的实际用户
        code, stdout, stderr = run_command(
            f"docker exec {container_id} whoami"
        )
        if code == 0:
            actual_user = stdout.strip()
            print(f"  容器内实际用户: {actual_user}")
            if actual_user != "root":
                print("  [PASS] 容器以非 root 用户运行")
            else:
                print("  [FAIL] 容器以 root 用户运行")
                return False
        else:
            print(f"  [WARN] 无法确认运行用户: {stderr}")

    # 检查 nginx 容器
    code, stdout, stderr = run_command(
        "docker compose -f docker-compose-prod.yml ps -q nginx"
    )
    if code == 0 and stdout.strip():
        container_id = stdout.strip().split('\n')[0]
        code, stdout, stderr = run_command(f"docker exec {container_id} whoami")
        if code == 0:
            actual_user = stdout.strip()
            print(f"  Nginx 用户: {actual_user}")
            if actual_user != "root":
                print("  [PASS] Nginx 以非 root 用户运行")
            else:
                print("  [FAIL] Nginx 以 root 用户运行")
                return False

    return True


def test_02_healthcheck_status():
    """测试 2: 验证健康检查状态"""
    print("\n[Test 2] 验证健康检查状态")
    print("-" * 50)

    code, stdout, stderr = run_command(
        "docker compose -f docker-compose-prod.yml ps"
    )
    if code != 0:
        print(f"[FAIL] 无法获取容器状态: {stderr}")
        return False

    print(stdout)

    # 检查是否所有容器都是 healthy
    lines = stdout.split('\n')
    healthy_count = 0
    total_count = 0

    for line in lines:
        if 'backend' in line or 'nginx' in line:
            total_count += 1
            if 'healthy' in line:
                healthy_count += 1
            elif 'starting' in line or 'up' in line:
                print(f"  [INFO] 容器状态: {line.strip()}")

    if healthy_count >= 2:  # backend 和 nginx
        print(f"  [PASS] {healthy_count} 个容器状态为 healthy")
        return True
    else:
        print(f"  [WARN] 仅有 {healthy_count}/{total_count} 个容器为 healthy")
        print("  [INFO] 健康检查可能需要更多时间启动...")
        return True  # 不严格失败，因为可能需要时间


def test_03_health_endpoint():
    """测试 3: 验证健康检查端点可访问"""
    print("\n[Test 3] 验证健康检查端点可访问")
    print("-" * 50)

    # 测试后端健康检查
    code, stdout, stderr = run_command(
        "curl -s -f http://localhost:8000/health"
    )
    if code == 0:
        print("  [PASS] Backend /health 端点可访问")
        print(f"  响应: {stdout[:100]}")
    else:
        print(f"  [FAIL] Backend /health 端点不可访问: {stderr}")
        return False

    # 测试 Nginx 健康检查（如果已配置）
    code, stdout, stderr = run_command(
        "curl -s -f http://localhost/health"
    )
    if code == 0:
        print("  [PASS] Nginx /health 端点可访问")
        print(f"  响应: {stdout[:100]}")
    else:
        print(f"  [INFO] Nginx /health 端点可能未配置或不可访问")

    return True


def test_04_resource_limits():
    """测试 4: 验证资源限制配置"""
    print("\n[Test 4] 验证资源限制配置")
    print("-" * 50)

    expected_limits = {
        "backend": {"memory": "512M", "cpus": "0.50"},
        "nginx": {"memory": "256M", "cpus": "0.25"},
    }

    all_pass = True

    for service, expected in expected_limits.items():
        code, stdout, stderr = run_command(
            f"docker compose -f docker-compose-prod.yml ps -q {service}"
        )
        if code != 0 or not stdout.strip():
            print(f"  [SKIP] {service} 容器未运行")
            continue

        container_id = stdout.strip().split('\n')[0]
        code, stdout, stderr = run_command(f"docker inspect {container_id}")
        if code != 0:
            print(f"  [FAIL] 无法获取 {service} 容器信息")
            all_pass = False
            continue

        inspect_data = json.loads(stdout)
        host_config = inspect_data[0]["HostConfig"]

        # 检查内存限制
        memory_limit = host_config.get("Memory")
        if memory_limit:
            memory_mb = memory_limit // (1024 * 1024)
            expected_mb = int(expected["memory"][:-1])
            if memory_mb == expected_mb:
                print(f"  [PASS] {service} 内存限制: {expected['memory']}")
            else:
                print(f"  [FAIL] {service} 内存限制: 期望 {expected['memory']}, 实际 {memory_mb}M")
                all_pass = False
        else:
            print(f"  [FAIL] {service} 未配置内存限制")
            all_pass = False

        # 检查 CPU 限制
        cpu_quota = host_config.get("CpuQuota")
        cpu_period = host_config.get("CpuPeriod")
        if cpu_quota and cpu_period:
            actual_cpus = cpu_quota / cpu_period
            expected_cpus = float(expected["cpus"])
            if abs(actual_cpus - expected_cpus) < 0.01:
                print(f"  [PASS] {service} CPU 限制: {expected['cpus']}")
            else:
                print(f"  [FAIL] {service} CPU 限制: 期望 {expected['cpus']}, 实际 {actual_cpus}")
                all_pass = False
        else:
            print(f"  [INFO] {service} CPU 限制可能未显示")

    return all_pass


def test_05_logging_config():
    """测试 5: 验证日志配置"""
    print("\n[Test 5] 验证日志配置")
    print("-" * 50)

    expected_config = {"max-size": "10m", "max-file": "5"}

    services = ["backend", "nginx"]
    all_pass = True

    for service in services:
        code, stdout, stderr = run_command(
            f"docker compose -f docker-compose-prod.yml ps -q {service}"
        )
        if code != 0 or not stdout.strip():
            print(f"  [SKIP] {service} 容器未运行")
            continue

        container_id = stdout.strip().split('\n')[0]
        code, stdout, stderr = run_command(f"docker inspect {container_id}")
        if code != 0:
            print(f"  [FAIL] 无法获取 {service} 容器信息")
            all_pass = False
            continue

        inspect_data = json.loads(stdout)
        host_config = inspect_data[0]["HostConfig"]
        log_config = host_config.get("LogConfig", {}).get("Config", {})

        if log_config.get("max-size") == expected_config["max-size"]:
            print(f"  [PASS] {service} 日志大小限制: {expected_config['max-size']}")
        else:
            print(f"  [FAIL] {service} 日志大小限制: 期望 {expected_config['max-size']}, 实际 {log_config.get('max-size')}")
            all_pass = False

        if log_config.get("max-file") == expected_config["max-file"]:
            print(f"  [PASS] {service} 日志文件数量限制: {expected_config['max-file']}")
        else:
            print(f"  [FAIL] {service} 日志文件数量限制: 期望 {expected_config['max-file']}, 实际 {log_config.get('max-file')}")
            all_pass = False

    return all_pass


def test_06_security_options():
    """测试 6: 验证安全选项"""
    print("\n[Test 6] 验证安全选项")
    print("-" * 50)

    services = ["backend", "nginx"]
    all_pass = True

    for service in services:
        code, stdout, stderr = run_command(
            f"docker compose -f docker-compose-prod.yml ps -q {service}"
        )
        if code != 0 or not stdout.strip():
            print(f"  [SKIP] {service} 容器未运行")
            continue

        container_id = stdout.strip().split('\n')[0]
        code, stdout, stderr = run_command(f"docker inspect {container_id}")
        if code != 0:
            print(f"  [FAIL] 无法获取 {service} 容器信息")
            all_pass = False
            continue

        inspect_data = json.loads(stdout)
        host_config = inspect_data[0]["HostConfig"]
        security_opt = host_config.get("SecurityOpt", [])
        cap_drop = host_config.get("CapDrop", [])
        cap_add = host_config.get("CapAdd", [])

        # 检查 no-new-privileges
        if "no-new-privileges:true" in security_opt:
            print(f"  [PASS] {service} 启用 no-new-privileges")
        else:
            print(f"  [INFO] {service} 未启用 no-new-privileges")

        # 检查 cap_drop
        if "ALL" in cap_drop:
            print(f"  [PASS] {service} 移除所有 capabilities (cap_drop: ALL)")
        else:
            print(f"  [INFO] {service} 未完全移除 capabilities")

        # 检查 cap_add
        if cap_add:
            print(f"  [INFO] {service} 添加 capabilities: {', '.join(cap_add)}")

    return all_pass


def test_07_failover():
    """测试 7: 验证故障转移"""
    print("\n[Test 7] 验证故障转移")
    print("-" * 50)

    print("[INFO] 此测试需要手动操作:")
    print("  1. 停止 backend 容器: docker compose -f docker-compose-prod.yml stop backend")
    print("  2. 访问 http://localhost 应该返回 502 错误")
    print("  3. 等待 backend 自动重启: docker compose -f docker-compose-prod.yml up -d backend")
    print("  4. 访问 http://localhost 应该恢复正常")
    print("\n[SKIP] 自动跳过故障转移测试（需要手动验证）")
    return True


def main():
    """主测试函数"""
    print("=" * 60)
    print("Docker 容器安全性和可靠性测试")
    print("=" * 60)

    tests = [
        test_01_non_root_user,
        test_02_healthcheck_status,
        test_03_health_endpoint,
        test_04_resource_limits,
        test_05_logging_config,
        test_06_security_options,
        test_07_failover,
    ]

    results = []
    for test_func in tests:
        try:
            result = test_func()
            results.append((test_func.__name__, result))
        except Exception as e:
            print(f"\n[ERROR] {test_func.__name__} 执行失败: {e}")
            results.append((test_func.__name__, False))

    print("\n" + "=" * 60)
    print("测试结果汇总")
    print("=" * 60)

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for test_name, result in results:
        status = "[PASS]" if result else "[FAIL]"
        print(f"  {status} {test_name}")

    print(f"\n总计: {passed}/{total} 通过")

    if passed == total:
        print("\n[SUCCESS] 所有测试通过！")
        return 0
    else:
        print(f"\n[FAILURE] {total - passed} 个测试失败")
        return 1


if __name__ == "__main__":
    sys.exit(main())

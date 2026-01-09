#!/bin/bash

# 验证 v1.1.0 Token 认证改进
# 检查所有关键文件和功能

set -e

echo "============================================================"
echo "OpenMeta v1.1.0 验证脚本"
echo "============================================================"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查函数
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
        exit 1
    fi
}

# 进入项目根目录
cd "$(dirname "$0")/.."

echo ""
echo "1️⃣  检查文件存在性..."
echo "-----------------------------------------------------------"

# 检查核心文件
[ -f "backend/app/services/pansou.py" ] && check "backend/app/services/pansou.py 存在"
[ -f "backend/app/settings.py" ] && check "backend/app/settings.py 存在"
[ -f "backend/app/main.py" ] && check "backend/app/main.py 存在"

# 检查测试脚本
[ -f "scripts/test-pansou-basic.py" ] && check "scripts/test-pansou-basic.py 存在"
[ -f "scripts/test-concurrent-search.py" ] && check "scripts/test-concurrent-search.py 存在"

# 检查文档
[ -f "docs/PANSOU-TOKEN-IMPROVEMENTS.md" ] && check "docs/PANSOU-TOKEN-IMPROVEMENTS.md 存在"
[ -f "docs/TESTING-GUIDE.md" ] && check "docs/TESTING-GUIDE.md 存在"
[ -f "docs/RELEASE-NOTES-v1.1.0.md" ] && check "docs/RELEASE-NOTES-v1.1.0.md 存在"

# 检查 CHANGELOG
[ -f "CHANGELOG.md" ] && check "CHANGELOG.md 存在"

echo ""
echo "2️⃣  检查 Python 语法..."
echo "-----------------------------------------------------------"

# 检查 Python 文件语法
python3 -m py_compile backend/app/services/pansou.py
check "backend/app/services/pansou.py 语法正确"

python3 -m py_compile backend/app/settings.py
check "backend/app/settings.py 语法正确"

python3 -m py_compile backend/app/main.py
check "backend/app/main.py 语法正确"

python3 -m py_compile scripts/test-pansou-basic.py
check "scripts/test-pansou-basic.py 语法正确"

python3 -m py_compile scripts/test-concurrent-search.py
check "scripts/test-concurrent-search.py 语法正确"

echo ""
echo "3️⃣  检查关键代码内容..."
echo "-----------------------------------------------------------"

# 检查 TokenManager 类
grep -q "class TokenManager" backend/app/services/pansou.py
check "TokenManager 类存在"

# 检查 asyncio.Lock
grep -q "_login_lock = asyncio.Lock()" backend/app/services/pansou.py
check "asyncio.Lock 存在"

# 检查 Double-check locking
grep -q "第一次检查" backend/app/services/pansou.py
check "Double-check locking 注释存在"

# 检查 expires_in 动态读取
grep -q "expires_in = data.get" backend/app/services/pansou.py
check "expires_in 动态读取"

# 检查提前 60 秒刷新
grep -q "token_exp - 60" backend/app/services/pansou.py
check "提前 60 秒刷新机制"

# 检查 SEARCH_TIMEOUT 环境变量
grep -q "settings.search_timeout" backend/app/services/pansou.py
check "SEARCH_TIMEOUT 环境变量使用"

# 检查友好错误处理
grep -q "无法连接到 PanSou 服务" backend/app/services/pansou.py
check "友好错误消息"

echo ""
echo "4️⃣  运行基础测试..."
echo "-----------------------------------------------------------"

# 运行基础测试
python3 scripts/test-pansou-basic.py > /tmp/test-output.log 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} 基础测试通过"
    echo ""
    tail -10 /tmp/test-output.log
else
    echo -e "${RED}✗${NC} 基础测试失败"
    cat /tmp/test-output.log
    exit 1
fi

echo ""
echo "5️⃣  检查文档完整性..."
echo "-----------------------------------------------------------"

# 检查文档关键内容
grep -q "Token 过期管理" docs/PANSOU-TOKEN-IMPROVEMENTS.md
check "Token 改进文档包含过期管理"

grep -q "并发安全" docs/PANSOU-TOKEN-IMPROVEMENTS.md
check "Token 改进文档包含并发安全"

grep -q "Double-check locking" docs/PANSOU-TOKEN-IMPROVEMENTS.md
check "Token 改进文档包含 Double-check locking"

grep -q "v1.1.0" CHANGELOG.md
check "CHANGELOG 包含 v1.1.0"

grep -q "智能认证" README.md
check "README 更新特性列表"

echo ""
echo "6️⃣  检查 CHANGELOG 格式..."
echo "-----------------------------------------------------------"

# 检查 CHANGELOG 格式
head -20 CHANGELOG.md | grep -q "v1.1.0"
check "CHANGELOG 顶部包含 v1.1.0"

grep -q "Token Management" CHANGELOG.md
check "CHANGELOG 包含 Token Management"

grep -q "Concurrency Control" CHANGELOG.md
check "CHANGELOG 包含 Concurrency Control"

echo ""
echo "7️⃣  检查可执行权限..."
echo "-----------------------------------------------------------"

# 检查脚本可执行权限
[ -x "scripts/test-pansou-basic.py" ] && check "test-pansou-basic.py 可执行"
[ -x "scripts/test-concurrent-search.py" ] && check "test-concurrent-search.py 可执行"

echo ""
echo "============================================================"
echo -e "${GREEN}✅ 所有验证通过！v1.1.0 准备就绪${NC}"
echo "============================================================"
echo ""
echo "📚 文档位置："
echo "   - Token 改进: docs/PANSOU-TOKEN-IMPROVEMENTS.md"
echo "   - 测试指南: docs/TESTING-GUIDE.md"
echo "   - 发布说明: docs/RELEASE-NOTES-v1.1.0.md"
echo ""
echo "🧪 运行测试："
echo "   - 基础测试: python3 scripts/test-pansou-basic.py"
echo "   - 完整测试: python3 scripts/test-concurrent-search.py"
echo ""
echo "🚀 下一步："
echo "   1. 提交代码: git add . && git commit -m 'v1.1.0: PanSou Token 认证改进'"
echo "   2. 推送代码: git push origin main"
echo "   3. 创建标签: git tag v1.1.0 && git push origin v1.1.0"
echo ""

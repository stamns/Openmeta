#!/bin/bash

# OpenMeta Vercel 部署验证脚本
# 用于测试和验证 Vercel 无服务器部署配置

set -e

echo "🔍 OpenMeta Vercel 部署验证"
echo "================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查函数
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        return 1
    fi
}

echo -e "${BLUE}1. 检查项目结构...${NC}"
# 检查必要文件
required_files=(
    "backend/vercel.json"
    "backend/api/index.py"
    "backend/main.py"
    "backend/requirements.txt"
    "backend/index.html"
    "backend/assets/app.js"
    "backend/assets/style.css"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} 缺失: $file"
    fi
done

echo -e "\n${BLUE}2. 检查 Python 依赖...${NC}"
cd backend

# 检查 requirements.txt
if [ -f "requirements.txt" ]; then
    echo "  依赖列表:"
    while IFS= read -r line; do
        if [[ ! $line =~ ^#.* ]] && [[ -n $line ]]; then
            echo "    - $line"
        fi
    done < requirements.txt
fi

# 测试 Python 导入
echo -e "\n${BLUE}3. 测试 Python 导入...${NC}"
python3 -c "
import sys
sys.path.insert(0, '.')

try:
    from main import app
    print('  ✅ FastAPI 应用导入成功')
except Exception as e:
    print(f'  ❌ FastAPI 应用导入失败: {e}')
    sys.exit(1)

try:
    from app.services.pansou import pansou_search
    print('  ✅ PanSou 服务导入成功')
except Exception as e:
    print(f'  ❌ PanSou 服务导入失败: {e}')
    sys.exit(1)

try:
    from app.settings import settings
    print('  ✅ 设置模块导入成功')
except Exception as e:
    print(f'  ❌ 设置模块导入失败: {e}')
    sys.exit(1)
"

check_result "Python 依赖检查"

echo -e "\n${BLUE}4. 检查 Vercel 配置...${NC}"
# 验证 vercel.json 语法
if command -v jq >/dev/null 2>&1; then
    if jq empty vercel.json 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} vercel.json 语法正确"
    else
        echo -e "  ${RED}❌${NC} vercel.json 语法错误"
    fi
    
    # 检查配置项
    echo "  配置检查:"
    
    if jq -e '.builds' vercel.json >/dev/null 2>&1; then
        echo "    ✅ builds 配置存在"
    else
        echo "    ❌ builds 配置缺失"
    fi
    
    if jq -e '.routes' vercel.json >/dev/null 2>&1; then
        echo "    ✅ routes 配置存在"
    else
        echo "    ❌ routes 配置缺失"
    fi
    
    if jq -e '.env' vercel.json >/dev/null 2>&1; then
        echo "    ✅ env 配置存在"
        echo "    📋 环境变量:"
        jq -r '.env | to_entries | .[] | "      - \(.key): \(.value)"' vercel.json
    else
        echo "    ❌ env 配置缺失"
    fi
else
    echo -e "  ${YELLOW}⚠️${NC} jq 未安装，跳过 JSON 验证"
fi

echo -e "\n${BLUE}5. 检查环境变量模板...${NC}"
if [ -f ".env.local.example" ]; then
    echo -e "  ${GREEN}✅${NC} 环境变量模板存在"
    echo "  📋 需要的变量:"
    grep -E "^[A-Z_]+=" .env.local.example | grep -v "^#" | sed 's/^/    - /'
else
    echo -e "  ${RED}❌${NC} 环境变量模板缺失"
fi

echo -e "\n${BLUE}6. 检查前端资源...${NC}"
if [ -f "index.html" ]; then
    echo -e "  ${GREEN}✅${NC} 前端页面存在"
fi

if [ -d "assets" ]; then
    asset_files=$(find assets -type f | wc -l)
    echo -e "  ${GREEN}✅${NC} 资源文件目录存在 ($asset_files 个文件)"
else
    echo -e "  ${RED}❌${NC} 资源文件目录缺失"
fi

echo -e "\n${BLUE}7. 网络连接测试...${NC}"
echo "  测试 PanSou 服务连接..."

# 提取 PanSou 主机地址
PANSOU_HOST=${PANSOU_HOST:-"http://112.124.53.114:8888"}

echo "  目标地址: $PANSOU_HOST"

if command -v curl >/dev/null 2>&1; then
    if curl -s --connect-timeout 5 --max-time 10 "$PANSOU_HOST" >/dev/null 2>&1; then
        echo -e "    ${GREEN}✅${NC} PanSou 服务可访问"
    else
        echo -e "    ${YELLOW}⚠️${NC} PanSou 服务不可访问 (这在开发环境中是正常的)"
    fi
else
    echo -e "    ${YELLOW}⚠️${NC} curl 未安装，跳过网络测试"
fi

echo -e "\n${BLUE}8. 本地服务测试...${NC}"
echo "  启动本地测试服务..."

# 启动后台服务
python3 -m uvicorn main:app --host 127.0.0.1 --port 8001 > /tmp/openmeta-test.log 2>&1 &
SERVER_PID=$!

# 等待服务启动
sleep 3

# 测试服务
if command -v curl >/dev/null 2>&1; then
    echo "  测试健康检查端点..."
    if curl -s http://127.0.0.1:8001/health >/dev/null 2>&1; then
        echo -e "    ${GREEN}✅${NC} 健康检查通过"
    else
        echo -e "    ${RED}❌${NC} 健康检查失败"
    fi
    
    echo "  测试搜索端点..."
    if curl -s "http://127.0.0.1:8001/api/search?q=test" >/dev/null 2>&1; then
        echo -e "    ${GREEN}✅${NC} 搜索端点可访问"
    else
        echo -e "    ${YELLOW}⚠️${NC} 搜索端点无响应 (PanSou 服务可能未配置)"
    fi
else
    echo -e "    ${YELLOW}⚠️${NC} curl 未安装，跳过服务测试"
fi

# 清理
kill $SERVER_PID 2>/dev/null || true
rm -f /tmp/openmeta-test.log

echo -e "\n${BLUE}9. Vercel CLI 检查...${NC}"
if command -v vercel >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅${NC} Vercel CLI 已安装"
    vercel --version
else
    echo -e "  ${YELLOW}⚠️${NC} Vercel CLI 未安装"
    echo "    安装命令: npm install -g vercel"
fi

echo -e "\n${BLUE}10. Docker 环境检查...${NC}"
if command -v docker >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅${NC} Docker 已安装"
    docker --version
else
    echo -e "  ${YELLOW}⚠️${NC} Docker 未安装 (可选)"
fi

if command -v docker-compose >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅${NC} Docker Compose 已安装"
else
    echo -e "  ${YELLOW}⚠️${NC} Docker Compose 未安装 (可选)"
fi

echo -e "\n${GREEN}🎉 验证完成！${NC}"
echo -e "\n${BLUE}接下来的步骤:${NC}"
echo "1. 确保 PanSou 服务地址正确配置"
echo "2. 设置 Vercel 环境变量"
echo "3. 运行 'vercel' 开始部署"
echo "4. 访问生成的 URL 进行测试"

echo -e "\n${BLUE}常用命令:${NC}"
echo "  本地开发:  uvicorn main:app --reload"
echo "  Docker:    docker-compose up --build"
echo "  Vercel:    vercel"
echo "  测试:      ./scripts/verify-deployment.sh"
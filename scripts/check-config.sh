#!/bin/bash

# OpenMeta Vercel 部署配置文件验证脚本
# 验证配置文件和项目结构（无需安装依赖）

set -e

echo "🔍 OpenMeta Vercel 部署配置验证"
echo "================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    "backend/.env.local.example"
    "docs/vercel-deployment.md"
    "docs/troubleshooting.md"
    "scripts/verify-deployment.sh"
)

all_files_exist=true
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} 缺失: $file"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = true ]; then
    echo -e "  ${GREEN}✅${NC} 所有必要文件存在"
else
    echo -e "  ${RED}❌${NC} 存在缺失文件"
fi

echo -e "\n${BLUE}2. 检查 Vercel 配置文件...${NC}"

# 检查根目录 vercel.json
if [ -f "vercel.json" ]; then
    echo -e "  ${GREEN}✓${NC} 根目录 vercel.json 存在"
    
    # 验证 JSON 语法
    if command -v jq >/dev/null 2>&1; then
        if jq empty vercel.json 2>/dev/null; then
            echo -e "    ${GREEN}✅${NC} JSON 语法正确"
        else
            echo -e "    ${RED}❌${NC} JSON 语法错误"
        fi
    fi
else
    echo -e "  ${YELLOW}⚠️${NC} 根目录 vercel.json 不存在 (可选)"
fi

# 检查 backend vercel.json
if [ -f "backend/vercel.json" ]; then
    echo -e "  ${GREEN}✓${NC} backend/vercel.json 存在"
    
    if command -v jq >/dev/null 2>&1; then
        if jq empty backend/vercel.json 2>/dev/null; then
            echo -e "    ${GREEN}✅${NC} JSON 语法正确"
            
            # 检查配置项
            echo "    📋 配置项检查:"
            
            if jq -e '.builds' backend/vercel.json >/dev/null 2>&1; then
                echo -e "      ${GREEN}✅${NC} builds 配置"
            else
                echo -e "      ${RED}❌${NC} builds 配置缺失"
            fi
            
            if jq -e '.routes' backend/vercel.json >/dev/null 2>&1; then
                echo -e "      ${GREEN}✅${NC} routes 配置"
            else
                echo -e "      ${RED}❌${NC} routes 配置缺失"
            fi
            
            if jq -e '.env' backend/vercel.json >/dev/null 2>&1; then
                echo -e "      ${GREEN}✅${NC} env 配置"
                echo "      📋 环境变量:"
                jq -r '.env | to_entries | .[] | "        - \(.key): \(.value)"' backend/vercel.json
            else
                echo -e "      ${RED}❌${NC} env 配置缺失"
            fi
            
            if jq -e '.functions' backend/vercel.json >/dev/null 2>&1; then
                echo -e "      ${GREEN}✅${NC} functions 配置"
                max_duration=$(jq -r '.functions."api/index.py".maxDuration // "未设置"' backend/vercel.json)
                echo "        最大执行时间: ${max_duration}s"
            else
                echo -e "      ${YELLOW}⚠️${NC} functions 配置缺失"
            fi
        else
            echo -e "    ${RED}❌${NC} JSON 语法错误"
        fi
    else
        echo -e "    ${YELLOW}⚠️${NC} jq 未安装，跳过 JSON 验证"
    fi
else
    echo -e "  ${RED}❌${NC} backend/vercel.json 不存在"
fi

echo -e "\n${BLUE}3. 检查 Python 依赖配置...${NC}"

if [ -f "backend/requirements.txt" ]; then
    echo -e "  ${GREEN}✓${NC} requirements.txt 存在"
    echo "  📋 依赖列表:"
    while IFS= read -r line; do
        if [[ ! $line =~ ^#.* ]] && [[ -n $line ]]; then
            echo "    - $line"
        fi
    done < backend/requirements.txt
    
    # 检查依赖数量
    dep_count=$(grep -v '^#' backend/requirements.txt | grep -v '^$' | wc -l)
    echo "  📊 依赖总数: $dep_count"
    
    if [ "$dep_count" -lt 10 ]; then
        echo -e "    ${GREEN}✅${NC} 依赖数量适中，有利于冷启动"
    else
        echo -e "    ${YELLOW}⚠️${NC} 依赖较多，可能影响冷启动时间"
    fi
else
    echo -e "  ${RED}❌${NC} requirements.txt 不存在"
fi

echo -e "\n${BLUE}4. 检查 API 入口点...${NC}"

if [ -f "backend/api/index.py" ]; then
    echo -e "  ${GREEN}✓${NC} Vercel API 入口点存在"
    
    # 检查关键特性
    if grep -q "VERCEL" backend/api/index.py; then
        echo -e "    ${GREEN}✅${NC} 包含 Vercel 环境检测"
    else
        echo -e "    ${YELLOW}⚠️${NC} 缺少 Vercel 环境检测"
    fi
    
    if grep -q "delay\|lazy" backend/api/index.py; then
        echo -e "    ${GREEN}✅${NC} 包含延迟导入优化"
    else
        echo -e "    ${YELLOW}⚠️${NC} 缺少延迟导入优化"
    fi
    
    if grep -q "error.*handler\|Error" backend/api/index.py; then
        echo -e "    ${GREEN}✅${NC} 包含错误处理"
    else
        echo -e "    ${YELLOW}⚠️${NC} 缺少错误处理"
    fi
else
    echo -e "  ${RED}❌${NC} API 入口点不存在"
fi

echo -e "\n${BLUE}5. 检查前端资源...${NC}"

if [ -f "backend/index.html" ]; then
    echo -e "  ${GREEN}✓${NC} 前端页面存在"
    
    # 检查是否引用了正确的资源路径
    if grep -q "/assets/" backend/index.html; then
        echo -e "    ${GREEN}✅${NC} 资源路径配置正确"
    else
        echo -e "    ${YELLOW}⚠️${NC} 资源路径可能有问题"
    fi
else
    echo -e "  ${RED}❌${NC} 前端页面不存在"
fi

if [ -d "backend/assets" ]; then
    asset_files=$(find backend/assets -type f | wc -l)
    echo -e "  ${GREEN}✓${NC} 资源文件目录存在 ($asset_files 个文件)"
    
    # 检查关键文件
    for asset in "app.js" "style.css"; do
        if [ -f "backend/assets/$asset" ]; then
            echo -e "    ${GREEN}✓${NC} $asset"
        else
            echo -e "    ${RED}✗${NC} $asset 缺失"
        fi
    done
else
    echo -e "  ${RED}❌${NC} 资源文件目录不存在"
fi

echo -e "\n${BLUE}6. 检查环境配置模板...${NC}"

if [ -f "backend/.env.local.example" ]; then
    echo -e "  ${GREEN}✓${NC} 环境变量模板存在"
    echo "  📋 需要的变量:"
    
    # 提取必需的环境变量
    grep -E "PANSOU_HOST|PANSOU_USER|PANSOU_PWD" backend/.env.local.example | \
    while IFS= read -r line; do
        echo "    - $line"
    done
else
    echo -e "  ${RED}❌${NC} 环境变量模板不存在"
fi

echo -e "\n${BLUE}7. 检查文档完整性...${NC}"

docs=("docs/vercel-deployment.md" "docs/troubleshooting.md")
for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        size=$(wc -l < "$doc")
        echo -e "  ${GREEN}✓${NC} $doc (${size} 行)"
        
        # 检查文档内容质量
        if [ "$doc" = "docs/vercel-deployment.md" ]; then
            if grep -q "Vercel\|vercel\|部署" "$doc"; then
                echo -e "    ${GREEN}✅${NC} 包含部署相关内容"
            fi
        elif [ "$doc" = "docs/troubleshooting.md" ]; then
            if grep -q "错误\|error\|故障" "$doc"; then
                echo -e "    ${GREEN}✅${NC} 包含故障排查内容"
            fi
        fi
    else
        echo -e "  ${RED}✗${NC} $doc 不存在"
    fi
done

echo -e "\n${BLUE}8. 检查脚本工具...${NC}"

if [ -f "scripts/verify-deployment.sh" ]; then
    echo -e "  ${GREEN}✓${NC} 验证脚本存在"
    if [ -x "scripts/verify-deployment.sh" ]; then
        echo -e "    ${GREEN}✅${NC} 脚本可执行"
    else
        echo -e "    ${YELLOW}⚠️${NC} 脚本不可执行"
    fi
else
    echo -e "  ${RED}❌${NC} 验证脚本不存在"
fi

echo -e "\n${BLUE}9. 检查 .gitignore 配置...${NC}"

if [ -f ".gitignore" ]; then
    echo -e "  ${GREEN}✓${NC} .gitignore 存在"
    
    # 检查是否包含必要的忽略项
    gitignore_patterns=(".env" ".vercel" "__pycache__" "node_modules")
    for pattern in "${gitignore_patterns[@]}"; do
        if grep -q "$pattern" .gitignore; then
            echo -e "    ${GREEN}✓${NC} 包含 $pattern"
        else
            echo -e "    ${YELLOW}⚠️${NC} 可能缺少 $pattern"
        fi
    done
else
    echo -e "  ${RED}❌${NC} .gitignore 不存在"
fi

echo -e "\n${BLUE}10. 部署就绪度评估...${NC}"

# 计算部署就绪度得分
score=0
total_checks=10

# 检查各项配置
[ -f "backend/vercel.json" ] && ((score++))
[ -f "backend/api/index.py" ] && ((score++))
[ -f "backend/requirements.txt" ] && ((score++))
[ -f "backend/index.html" ] && ((score++))
[ -d "backend/assets" ] && ((score++))
[ -f "backend/.env.local.example" ] && ((score++))
[ -f "docs/vercel-deployment.md" ] && ((score++))
[ -f "docs/troubleshooting.md" ] && ((score++))
[ -f "scripts/verify-deployment.sh" ] && ((score++))
[ -f ".gitignore" ] && ((score++))

percentage=$((score * 100 / total_checks))

echo "📊 配置完成度: $score/$total_checks ($percentage%)"

if [ "$percentage" -ge 90 ]; then
    echo -e "  ${GREEN}🎉 部署配置完成度优秀！可以开始部署了${NC}"
elif [ "$percentage" -ge 70 ]; then
    echo -e "  ${YELLOW}⚠️  部署配置基本完成，建议完善剩余项目${NC}"
else
    echo -e "  ${RED}❌ 部署配置不完整，需要修复问题${NC}"
fi

echo -e "\n${GREEN}🎉 配置验证完成！${NC}"
echo -e "\n${BLUE}接下来的步骤:${NC}"
echo "1. 确保 PanSou 服务地址正确配置"
echo "2. 设置 Vercel 环境变量 (PANSOU_HOST, PANSOU_USER, PANSOU_PWD)"
echo "3. 运行 'cd backend && vercel' 开始部署"
echo "4. 访问生成的 URL 进行测试"

echo -e "\n${BLUE}快速部署命令:${NC}"
echo "  cd backend"
echo "  vercel"
echo ""
echo "  或使用根目录配置:"
echo "  vercel"
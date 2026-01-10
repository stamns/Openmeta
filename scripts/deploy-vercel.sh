#!/bin/bash

# OpenMeta Vercel 部署辅助脚本
set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 开始 OpenMeta Vercel 部署验证...${NC}"

# 1. 检查必要文件
echo -e "${YELLOW}检查配置文件...${NC}"
if [ ! -f "vercel.json" ]; then
    echo -e "${RED}错误: 找不到 vercel.json${NC}"
    exit 1
fi

if [ ! -f "backend/api/index.py" ]; then
    echo -e "${RED}错误: 找不到 backend/api/index.py${NC}"
    exit 1
fi

# 2. 验证 vercel.json 格式
echo -e "${YELLOW}验证 vercel.json 格式...${NC}"
if command -v jq >/dev/null 2>&1; then
    jq . vercel.json > /dev/null
    echo -e "${GREEN}✅ vercel.json 格式正确${NC}"
else
    echo -e "${YELLOW}跳过 jq 验证 (未安装 jq)${NC}"
fi

# 3. 前端预构建验证
echo -e "${YELLOW}验证前端构建配置...${NC}"
if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
    echo -e "${GREEN}✅ 前端配置已就绪${NC}"
else
    echo -e "${RED}错误: 前端目录或 package.json 缺失${NC}"
    exit 1
fi

# 4. 提示部署步骤
echo -e "\n${GREEN}验证通过！${NC}"
echo -e "请按照以下步骤完成部署："
echo -e "1. 确保所有更改已提交并推送到 GitHub:"
echo -e "   ${YELLOW}git add . && git commit -m \"feat: optimize vercel deployment\" && git push${NC}"
echo -e "2. 在 Vercel Dashboard 中配置以下环境变量:"
echo -e "   - ${YELLOW}PANSOU_HOST${NC}"
echo -e "   - ${YELLOW}PANSOU_USER${NC}"
echo -e "   - ${YELLOW}PANSOU_PWD${NC}"
echo -e "3. Vercel 将自动开始构建和部署。"
echo -e "4. 部署完成后，访问生成的 Vercel URL 进行测试。"

echo -e "\n${GREEN}祝部署顺利！${NC}"

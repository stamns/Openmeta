# OpenMeta 快速开始

## 本地部署

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

测试：`curl 'http://localhost:8000/api/search?q=test'`

## Docker 部署

```bash
cd backend
docker build -t openmeta .
docker run -p 8000:8000 openmeta
```

测试：`curl 'http://localhost:8000/api/search?q=test'`

## Vercel 部署

### 通过 GitHub

1. 访问 https://vercel.com/new
2. 导入 GitHub 仓库
3. Root Directory = `backend`
4. 配置环境变量（可选）：
   - PANSOU_HOST
   - PANSOU_USER
   - PANSOU_PWD
5. Deploy

### 通过 CLI

```bash
npm i -g vercel
vercel login
vercel --prod
```

## 验证部署

```bash
# API
curl 'https://your-domain/api/search?q=test'

# 健康检查
curl 'https://your-domain/health'
```

## 常见问题

**Q: 看到 "source": "mock"？**
A: PANSOU_HOST 未配置，这是正常的演示模式。

**Q: Docker 容器无法访问？**
A: 检查端口映射和防火墙设置。

**Q: Vercel 部署后 502？**
A: 查看 Vercel Dashboard → Functions → Logs 获取详细错误。

详见：[故障排查指南](./troubleshooting.md)

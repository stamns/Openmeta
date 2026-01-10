FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 创建非 root 用户
RUN groupadd -r appuser && useradd -r -g appuser -u 1000 appuser

# 安装依赖
COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# 复制应用代码
COPY backend /app/backend

# 设置目录权限
RUN chown -R appuser:appuser /app

# 切换到非 root 用户
USER appuser

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "backend.app.main:app", "--host", "0.0.0.0", "--port", "8000"]

FROM python:3.11-slim

# 安全和性能环境变量
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# 创建非 root 用户
RUN groupadd -r appuser && useradd -r -g appuser -u 1000 appuser

# 安装依赖
RUN groupadd -g 1000 appuser && \
    useradd -u 1000 -g appuser -s /bin/sh -m appuser

# 安装依赖（使用 root 权限）
COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# 复制应用代码
COPY backend /app/backend

# 设置目录权限
RUN chown -R appuser:appuser /app

# 切换到非 root 用户
USER appuser

EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')" || exit 1

CMD ["python", "-m", "uvicorn", "backend.app.main:app", "--host", "0.0.0.0", "--port", "8000"]

FROM node:20-alpine AS frontend-build

WORKDIR /work/frontend

COPY frontend/ ./

RUN if [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable && pnpm i --frozen-lockfile; \
  elif [ -f yarn.lock ]; then corepack enable && yarn install --frozen-lockfile; \
  else npm install; fi

RUN npm run build

FROM nginx:1.25-alpine

# 复制自定义 nginx 配置
COPY deploy/nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx_conf/default.conf /etc/nginx/conf.d/default.conf

# 复制前端构建产物
COPY --from=frontend-build /work/frontend/dist /usr/share/nginx/html

# 创建缓存目录
RUN mkdir -p /var/cache/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
RUN mkdir -p /var/cache/nginx/api_cache && chown -R nginx:nginx /var/cache/nginx

FROM node:20-alpine AS frontend-build

WORKDIR /work/frontend

COPY frontend/ ./

RUN if [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable && pnpm i --frozen-lockfile; \
  elif [ -f yarn.lock ]; then corepack enable && yarn install --frozen-lockfile; \
  else npm install; fi

RUN npm run build

FROM nginx:1.25-alpine

COPY nginx_conf/default.conf /etc/nginx/conf.d/default.conf
COPY --from=frontend-build /work/frontend/dist /usr/share/nginx/html

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEPLOY=0
for arg in "$@"; do
  case "$arg" in
    --deploy) DEPLOY=1 ;;
  esac
done

if [ ! -f "$ROOT_DIR/vercel.json" ]; then
  echo "[ERR] 缺少 vercel.json" >&2
  exit 1
fi

grep -q '"api/index.py"' "$ROOT_DIR/vercel.json" || {
  echo "[ERR] vercel.json 未包含 api/index.py 构建配置" >&2
  exit 1
}

grep -q 'frontend/package.json' "$ROOT_DIR/vercel.json" || {
  echo "[ERR] vercel.json 未包含前端静态构建配置（frontend/package.json）" >&2
  exit 1
}

get_env() {
  local key="$1"
  if [ -n "${!key:-}" ]; then
    echo "${!key}"
    return 0
  fi
  if [ -f "$ROOT_DIR/.env" ]; then
    awk -F= -v k="$key" 'BEGIN{v=""} $0 ~ "^"k"=" {sub("^"k"=","",$0); print $0; exit 0}' "$ROOT_DIR/.env" || true
    return 0
  fi
  echo ""
}

required=(PANSOU_HOST PANSOU_USER PANSOU_PWD)
missing=()
for k in "${required[@]}"; do
  v="$(get_env "$k")"
  if [ -z "$v" ]; then
    missing+=("$k")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "[WARN] 未检测到以下环境变量（Vercel 部署时必须在 Dashboard 中配置）：" >&2
  printf '  - %s\n' "${missing[@]}" >&2
fi

echo ""
echo "[INFO] Vercel 部署步骤（推荐）："
echo "  1) 将代码推送到 GitHub（Vercel 通过 Git 集成自动构建）"
echo "  2) 打开 https://vercel.com/new 导入仓库"
echo "  3) Environment Variables 中配置：PANSOU_HOST / PANSOU_USER / PANSOU_PWD（以及可选的 LOG_LEVEL 等）"
echo "  4) Deploy 后等待构建完成"
echo "  5) 绑定域名：Project -> Settings -> Domains"
echo ""
echo "[INFO] 成本说明："
echo "  - 个人/小流量场景可使用 Vercel Free"
echo "  - 需要自定义团队协作、带宽/并发更高、SLA 等可升级 Pro"

echo ""
if [ "$DEPLOY" -eq 1 ] || [ "${AUTO_DEPLOY:-0}" -eq 1 ]; then
  if ! command -v vercel >/dev/null 2>&1; then
    echo "[ERR] 未安装 Vercel CLI：npm i -g vercel" >&2
    exit 1
  fi
  echo "[INFO] 尝试通过 Vercel CLI 进行生产部署（需要提前 vercel login）"
  vercel deploy --prod --yes
else
  echo "[INFO] 可选：自动部署（需要 Vercel CLI 已登录）"
  echo "      执行：./scripts/deploy-vercel.sh --deploy"
fi

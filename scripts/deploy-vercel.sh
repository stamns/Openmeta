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

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "[ERR] 未安装 Python（用于校验 vercel.json）" >&2
  exit 1
fi

VERCEL_JSON="$ROOT_DIR/vercel.json"
if [ ! -f "$VERCEL_JSON" ]; then
  echo "[ERR] 缺少 vercel.json" >&2
  exit 1
fi

# 基础校验：JSON 可解析 + 包含关键构建项
"$PYTHON_BIN" - <<PY
import json
from pathlib import Path
p = Path(r"$VERCEL_JSON")
obj = json.loads(p.read_text(encoding="utf-8"))
builds = obj.get("builds", [])
srcs = {b.get("src") for b in builds if isinstance(b, dict)}
need = {"backend/api/index.py", "frontend/package.json"}
missing = sorted(need - srcs)
if missing:
    raise SystemExit("vercel.json 缺少 builds.src：" + ", ".join(missing))

# 检查 routes 配置
routes = obj.get("routes", [])
if not routes:
    raise SystemExit("vercel.json 缺少 routes 配置")

# 检查环境变量配置
if "env" not in obj:
    raise SystemExit("vercel.json 缺少 env 配置")

print("[OK] vercel.json 校验通过")
print(f"[INFO] 构建配置: {len(builds)} 个构建项")
print(f"[INFO] 路由配置: {len(routes)} 个路由规则")
PY

get_env() {
  local key="$1"
  if [ -n "${!key:-}" ]; then
    echo "${!key}"
    return 0
  fi
  if [ -f "$ROOT_DIR/.env" ]; then
    awk -F= -v k="$key" '$0 ~ "^"k"=" {sub("^"k"=","",$0); print $0; exit 0}' "$ROOT_DIR/.env" || true
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
  echo "[WARN] 未检测到以下环境变量：" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  echo "      不配置也可以部署，但 /api/search 将返回空结果（建议生产环境补齐 PanSou 配置）。" >&2
fi

echo ""
echo "[INFO] Vercel 部署（推荐：GitHub 自动部署）"
echo "  1) 将代码推送到 GitHub"
echo "  2) 打开 https://vercel.com/new 导入仓库"
echo "  3) 保持 Root Directory 为仓库根目录（本仓库提供根目录 vercel.json）"
echo "  4) Project -> Settings -> Environment Variables：配置 PANSOU_HOST / PANSOU_USER / PANSOU_PWD（以及可选 LOG_LEVEL 等）"
echo "  5) Deploy，等待构建完成"
echo "  6) 域名绑定：Project -> Settings -> Domains"

echo ""
echo "[INFO] 成本说明"
echo "  - Free：适合个人/小流量站点（可能有冷启动与配额限制）"
echo "  - Pro：适合更高并发/更高配额/团队协作"

echo ""
if [ "$DEPLOY" -eq 1 ] || [ "${AUTO_DEPLOY:-0}" -eq 1 ]; then
  if ! command -v vercel >/dev/null 2>&1; then
    echo "[ERR] 未安装 Vercel CLI：npm i -g vercel" >&2
    exit 1
  fi
  echo "[INFO] 尝试通过 Vercel CLI 进行生产部署（需要提前 vercel login）"
  vercel deploy --prod --yes
else
  echo "[INFO] 可选：使用 Vercel CLI 自动部署（需要已登录）"
  echo "      执行：./scripts/deploy-vercel.sh --deploy"
fi

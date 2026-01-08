# Deploy OpenMeta to Vercel (Serverless)

## 1) Connect GitHub repo to Vercel

1. Go to Vercel Dashboard → **Add New…** → **Project**
2. Import your GitHub repository
3. In **Project Settings → General → Root Directory**, set it to:

   ```
   backend
   ```

> Why: our Vercel Functions entrypoint is `backend/api/index.py` and static frontend files are under `backend/`.

## 2) Vercel configuration files

- `backend/vercel.json`: configuration used when the Vercel project root directory is set to `backend`.
- (Optional) `/vercel.json`: convenience config to run `vercel dev` from repository root.

Key behaviors:

- Static frontend is served from `backend/index.html` and `backend/assets/*`
- All API requests are routed to a single Python Function (`api/index.py`)
- FastAPI is mounted under `/api` so all backend routes become `/api/*`

## 3) Environment variables

### Required variables

- `PANSOU_HOST`
- `PANSOU_USER`
- `PANSOU_PWD`

### Recommended: set via Vercel Dashboard

Vercel Dashboard → Project → **Settings → Environment Variables**

Add the variables above for:

- **Preview** (PR/branch builds)
- **Production** (main branch)

If Preview and Production use different PanSou endpoints/credentials, set different values per environment.

### Alternative: use Vercel Secrets (matches `vercel.json` default)

This repo’s `vercel.json` maps runtime env vars to secrets:

- `PANSOU_HOST` → `@pansou_host`
- `PANSOU_USER` → `@pansou_user`
- `PANSOU_PWD` → `@pansou_pwd`

If you keep that mapping, create the secrets (CLI):

```bash
vercel secrets add pansou_host "https://..."
vercel secrets add pansou_user "..."
vercel secrets add pansou_pwd "..."
```

### Local development with `vercel dev`

`vercel dev` automatically loads `.env.local`.

Create `backend/.env.local`:

```bash
cp backend/.env.example backend/.env.local
```

Then edit values.

## 4) Build & start commands

Vercel serverless runtime does not run `uvicorn`. It executes Python Functions directly.

- Build: handled by `@vercel/python` (installs `requirements.txt`)
- Start: N/A (serverless execution)

Local/Docker still use Uvicorn:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

## 5) API routing under `/api/*`

Vercel entrypoint: `backend/api/index.py`

It mounts the real OpenMeta app under `/api`, so existing backend routes do **not** need to change.

Example:

- Local: `/api/search?q=test`
- Vercel: `/api/search?q=test`

## 6) Static frontend routing

Vercel routes:

- `/api/*` → Python Function
- All other paths → `/index.html` (SPA fallback)

This allows client-side routing (e.g. `/about`, `/settings`) to work without extra backend changes.

## 7) Serverless constraints (filesystem/logging/cache)

- Filesystem is **read-only** at runtime: do not write to disk.
- Logs should go to stdout/stderr (Python `logging` default) → visible in Vercel logs.
- Cache should be in-memory (best effort) or external storage (e.g., Redis). This repo uses best-effort in-memory caching via process reuse.

## 8) Dependency & size optimization

`backend/requirements.txt` is intentionally minimal:

- `fastapi`
- `httpx`
- `uvicorn` (for local/Docker only; small)

Keep dependencies small to stay under Vercel Function size limits (commonly ~250MB).

## 9) Cold start optimization notes

This repo applies a few low-risk optimizations:

- Lazy import of `httpx` (only when `/search` is called)
- Best-effort reuse of a single `httpx.AsyncClient` (connection pool) per warm instance

## 10) Test & verify

### Run locally in Vercel-like mode

From `backend/`:

```bash
npm i -g vercel
vercel dev
```

Then open:

- Frontend: http://localhost:3000
- API: http://localhost:3000/api/search?q=test

### Quick checks

- `/api/health` returns `{ "ok": true }`
- Frontend can fetch `/api/search`

## 11) Troubleshooting

### 404 for `/api/search`

- Confirm Vercel project **Root Directory** is `backend`
- Confirm the function file exists: `backend/api/index.py`
- Confirm `backend/vercel.json` is present

### Build fails with missing dependencies

- Ensure `backend/requirements.txt` exists
- If deploying from repository root (Root Directory not set), ensure root `requirements.txt` exists (this repo provides it).

### Environment variables not working

- Vercel Dashboard → Settings → Environment Variables
- Ensure variables are set for the correct environment (Preview vs Production)
- Redeploy after changing env vars

### How to view logs

- Vercel Dashboard → Project → **Deployments** → select a deployment → **Functions** / **Logs**

### Performance monitoring / cold starts

- Enable Vercel Analytics (optional)
- Check function invocation duration in Deployment logs
- Reduce imports and avoid global network calls during module import

## 12) Custom domain / Preview vs Production

- Preview deployments are created for every push/PR (if enabled)
- Production deployment typically tracks your default branch
- Bind a custom domain in Vercel Dashboard → Project → Settings → Domains


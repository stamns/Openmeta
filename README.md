# OpenMeta

This repository is structured to support **three deployment layers**:

- Local development (Uvicorn)
- Docker (containerized Uvicorn)
- Vercel (serverless Functions + static frontend)

Backend and static frontend live under `backend/`.

## Local development

```bash
cd backend
cp .env.example .env
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

- Frontend: http://localhost:8000
- API: http://localhost:8000/api/search?q=test

## Docker

```bash
cp backend/.env.example backend/.env
docker compose up --build
```

- Frontend: http://localhost:8000
- API: http://localhost:8000/api/search?q=test

## Vercel deployment

See **[docs/vercel.md](./docs/vercel.md)**.

- Frontend: `https://<your-project>.vercel.app/`
- API: `https://<your-project>.vercel.app/api/search?q=test`

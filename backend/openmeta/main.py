import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from openmeta.routers.search import router as search_router

logging.basicConfig(level=logging.INFO)

app = FastAPI(
    title="OpenMeta",
    description="本地/Docker/Vercel 三层部署支持",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(search_router, prefix="/api")
app.include_router(search_router)


@app.get("/")
async def root():
    return {
        "message": "OpenMeta API",
        "docs": "/docs",
        "search": "/api/search?q=...",
    }


@app.get("/health")
async def health():
    return {"status": "ok"}

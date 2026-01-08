from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    pansou_host: str = ""
    pansou_user: str = ""
    pansou_pwd: str = ""

    redis_host: str | None = None
    redis_port: int = 6379
    redis_password: str | None = None

    backend_host: str = "0.0.0.0"
    backend_port: int = 8000

    log_level: str = "INFO"
    rate_limit_per_minute: int = 10
    search_timeout: int = 15

    cors_allow_origins: str = "*"


settings = Settings()  # type: ignore[call-arg]

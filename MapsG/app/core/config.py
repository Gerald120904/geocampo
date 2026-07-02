from functools import lru_cache
from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_NAME: str = "GeoCampo Backend"
    APP_ENV: str = "development"
    APP_DEBUG: bool = True
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8001
    DATABASE_URL: str = "sqlite:///./geocampo.db"
    POSTGRES_DB: str = "geocampo"
    POSTGRES_USER: str = "geocampo"
    POSTGRES_PASSWORD: str = "geocampo"
    POSTGRES_HOST: str = "localhost"
    POSTGRES_PORT: int = 5432
    REDIS_URL: str = "redis://localhost:6379/0"
    STORAGE_PATH: str = "./storage"
    ORIGINAL_FILES_PATH: str = "./storage/originals"
    PROCESSED_FILES_PATH: str = "./storage/processed"
    PACKAGES_PATH: str = "./storage/packages"
    TEMP_PATH: str = "./storage/temp"
    OBSERVATION_PHOTOS_PATH: str = "./storage/photos"
    STORAGE_BACKEND: str = "local"
    R2_BUCKET: str = ""
    R2_ENDPOINT: str = ""
    R2_ACCESS_KEY_ID: str = ""
    R2_SECRET_ACCESS_KEY: str = ""
    R2_REGION: str = "auto"
    R2_PUBLIC_BASE_URL: str = ""
    JWT_SECRET_KEY: str = "development-only-change-this-secret-key"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    EMAIL_VERIFICATION_CODE_EXPIRE_MINUTES: int = 10
    PASSWORD_RESET_CODE_EXPIRE_MINUTES: int = 10
    APP_FRONTEND_URL: str = "http://localhost:3000"
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = "geocampo.app@gmail.com"
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = "geocampo.app@gmail.com"
    SMTP_FROM_NAME: str = "GeoCampo"
    SMTP_USE_TLS: bool = True
    MAX_UPLOAD_SIZE_MB: int = 500
    CORS_ORIGINS: str = ""
    DEFAULT_MAP_MIN_ZOOM: int = 8
    DEFAULT_MAP_MAX_ZOOM: int = 17
    DEFAULT_MAP_ZOOM: int = 16
    RASTER_TILE_FORMAT: str = "PNG"
    RASTER_RESAMPLING: str = "nearest"
    RASTER_MAX_ZOOM: int = 17
    RASTER_MIN_ZOOM: int = 8
    RASTER_OVERVIEWS: bool = False
    GEOPDF_FAST_MODE: bool = True
    GEOPDF_RENDER_ZOOM: float = 3.0
    GEOPDF_MIN_ZOOM: int = 8
    GEOPDF_MAX_ZOOM: int = 17
    GEOPDF_DEFAULT_ZOOM: int = 16
    GEOPDF_MAX_GENERATED_TILES: int = 2500
    GEOPDF_REQUIRE_GDAL: bool = False
    GEOPDF_CLEAN_RENDER: bool = False
    FAST_PREVIEW_WIDTH: int = 1200
    INCLUDE_ORIGINAL_IN_PACKAGE: bool = False
    CELERY_TASK_ALWAYS_EAGER: bool = False
    BOOTSTRAP_ADMIN_EMAIL: str = "admin@geocampo.local"
    BOOTSTRAP_ADMIN_PASSWORD: str = "change_me_now"
    BOOTSTRAP_ADMIN_NAME: str = "GeoCampo Admin"

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", case_sensitive=True, extra="ignore"
    )

    @field_validator("MAX_UPLOAD_SIZE_MB")
    @classmethod
    def upload_size_must_be_positive(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("MAX_UPLOAD_SIZE_MB must be positive")
        return value

    @property
    def cors_origins_list(self) -> list[str]:
        return [item.strip() for item in self.CORS_ORIGINS.split(",") if item.strip()]

    @property
    def cors_origin_regex(self) -> str | None:
        if self.APP_ENV == "development":
            return r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
        return None

    @property
    def storage_directories(self) -> list[Path]:
        return [
            Path(self.STORAGE_PATH),
            Path(self.ORIGINAL_FILES_PATH),
            Path(self.PROCESSED_FILES_PATH),
            Path(self.PACKAGES_PATH),
            Path(self.TEMP_PATH),
            Path(self.OBSERVATION_PHOTOS_PATH),
        ]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()

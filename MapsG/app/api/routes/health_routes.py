from pathlib import Path
from tempfile import NamedTemporaryFile

from fastapi import APIRouter
from redis import Redis
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from fastapi import Depends
from app.services.r2_storage_service import R2StorageService

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": settings.APP_NAME}


@router.get("/health/db")
def health_db(db: Session = Depends(get_db)) -> dict[str, str]:
    db.execute(text("SELECT 1"))
    return {"status": "ok", "database": "connected"}


@router.get("/health/storage")
def health_storage() -> dict[str, str]:
    missing = [str(path) for path in settings.storage_directories if not Path(path).is_dir()]
    if missing:
        return {"status": "error", "storage": "missing", "paths": ",".join(missing)}
    return {"status": "ok", "storage": "available"}


@router.get("/health/r2")
def health_r2() -> dict[str, str]:
    if settings.STORAGE_BACKEND != "r2":
        return {
            "status": "skipped",
            "storage_backend": settings.STORAGE_BACKEND,
        }

    r2 = R2StorageService()
    key = "health/render-r2-test.txt"

    with NamedTemporaryFile("w", delete=False) as temp_file:
        temp_file.write("GeoCampo R2 OK")
        temp_path = Path(temp_file.name)

    try:
        r2.upload_file(
            temp_path,
            key,
            content_type="text/plain",
        )
        url = r2.presigned_get_url(key, expires_seconds=300)

        return {
            "status": "ok",
            "bucket": settings.R2_BUCKET,
            "key": key,
            "download_url": url,
        }
    finally:
        temp_path.unlink(missing_ok=True)


@router.get("/health/redis")
def health_redis() -> dict[str, str]:
    client = Redis.from_url(settings.REDIS_URL, socket_connect_timeout=2, socket_timeout=2)
    try:
        client.ping()
    except Exception as exc:
        return {"status": "error", "redis": "unavailable", "message": str(exc)}
    return {"status": "ok", "redis": "connected"}

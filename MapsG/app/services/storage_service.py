import re
import shutil
import unicodedata
from functools import lru_cache
from pathlib import Path

from app.core.config import settings
from app.core.storage import safe_resolve
from app.services.r2_storage_service import R2StorageService

R2_URI_PREFIX = "r2://"


def slugify(value: str, fallback: str = "mapa") -> str:
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    result = re.sub(r"[^a-zA-Z0-9_-]+", "_", normalized).strip("_").lower()
    return result[:100] or fallback


def make_directory(root: str, *parts: str) -> Path:
    directory = safe_resolve(root, *parts)
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def remove_tree(path: str | Path) -> None:
    candidate = Path(path)
    if candidate.exists():
        shutil.rmtree(candidate)


def storage_backend() -> str:
    return settings.STORAGE_BACKEND.strip().lower()


def using_r2() -> bool:
    return storage_backend() == "r2"


def r2_uri(key: str) -> str:
    return f"{R2_URI_PREFIX}{normalize_key(key)}"


def is_r2_uri(value: str | None) -> bool:
    return bool(value and value.startswith(R2_URI_PREFIX))


def r2_key(value: str) -> str:
    return value.removeprefix(R2_URI_PREFIX)


def normalize_key(*parts: str) -> str:
    raw = "/".join(str(part).strip("/\\") for part in parts if str(part).strip("/\\"))
    return raw.replace("\\", "/")


def join_storage_uri(base: str, *parts: str) -> str:
    if is_r2_uri(base):
        return r2_uri(normalize_key(r2_key(base), *parts))
    return str(Path(base, *parts))


def permanent_key(category: str, company_id: str, project_id: str, map_id: str, filename: str) -> str:
    return normalize_key(category, company_id, project_id, map_id, filename)


def upload_permanent_file(local_path: Path, key: str, content_type: str | None = None) -> str:
    if not using_r2():
        return str(local_path)
    service = _r2()
    service.upload_file(local_path, normalize_key(key), content_type=content_type)
    return r2_uri(key)


def upload_directory(local_root: Path, key_prefix: str) -> dict[Path, str]:
    uploaded: dict[Path, str] = {}
    if not using_r2():
        return uploaded

    root = local_root.resolve()
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative = path.resolve().relative_to(root).as_posix()
        key = normalize_key(key_prefix, relative)
        uploaded[path.resolve()] = upload_permanent_file(path, key)
    return uploaded


def materialize_file(path_value: str | None) -> Path | None:
    if not path_value:
        return None
    if not is_r2_uri(path_value):
        return Path(path_value)

    key = r2_key(path_value)
    local_path = safe_resolve(settings.TEMP_PATH, "r2_cache", key)
    if local_path.is_file():
        return local_path
    return _r2().download_file(key, local_path)


def stored_file_available(path_value: str | None) -> bool:
    if not path_value:
        return False
    if is_r2_uri(path_value):
        return True
    return Path(path_value).is_file()


def stored_filename(path_value: str | None) -> str | None:
    if not path_value:
        return None
    if is_r2_uri(path_value):
        return Path(r2_key(path_value)).name
    return Path(path_value).name


def presigned_get_url(path_value: str | None, expires_seconds: int = 3600) -> str | None:
    if not is_r2_uri(path_value):
        return None
    return _r2().presigned_get_url(r2_key(path_value), expires_seconds=expires_seconds)


@lru_cache
def _r2() -> R2StorageService:
    return R2StorageService()

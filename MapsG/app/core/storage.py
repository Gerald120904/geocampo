from pathlib import Path

from app.core.config import settings


def ensure_storage_directories() -> None:
    for directory in settings.storage_directories:
        directory.mkdir(parents=True, exist_ok=True)


def safe_resolve(root: str | Path, *parts: str) -> Path:
    root_path = Path(root).resolve()
    candidate = root_path.joinpath(*parts).resolve()
    if candidate != root_path and root_path not in candidate.parents:
        raise ValueError("Unsafe storage path")
    return candidate


import json
import hashlib
import shutil
from collections.abc import Callable
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from app.core.config import settings
from app.core.exceptions import GeoCampoError
from app.services.storage_service import slugify

ProgressCallback = Callable[[int, int], None]


def write_json(path: Path, value: dict) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def copy_original(source: Path, package_root: Path) -> Path:
    info = {
        "original_name": source.name,
        "size_bytes": source.stat().st_size,
        "included_in_package": settings.INCLUDE_ORIGINAL_IN_PACKAGE,
    }
    write_json(package_root / "original_info.json", info)
    if not settings.INCLUDE_ORIGINAL_IN_PACKAGE:
        return package_root / "original_info.json"

    destination = package_root / "original" / source.name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    return destination


def build_package(
    package_root: Path,
    packages_dir: Path,
    map_name: str,
    on_progress: ProgressCallback | None = None,
) -> Path:
    package_root = package_root.resolve()
    metadata_path = package_root / "metadata.json"
    if not metadata_path.is_file():
        raise GeoCampoError("METADATA_NOT_FOUND", "No se pudo generar metadata.json.")
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    bounds = metadata.get("bounds")
    if not bounds:
        raise GeoCampoError("INVALID_METADATA", "metadata.json no contiene bounds.")
    _require_package_file(package_root, "original_info.json")
    _require_package_file(package_root, "metadata.json")
    if not any((package_root / name).is_file() for name in ("preview.png", "preview.jpg")):
        raise GeoCampoError("MISSING_PREVIEW", "No existe preview.png o preview.jpg.")
    if metadata.get("display_type") == "raster_mbtiles" or metadata.get("tile_file"):
        _require_package_file(package_root, metadata.get("tile_file") or "map.mbtiles")
    for layer in metadata.get("layers", []):
        if not _safe_package_path(package_root, layer["file"]).is_file():
            raise GeoCampoError("MISSING_LAYER", f"No existe la capa {layer['file']}.")
    for value in metadata.get("files", {}).values():
        if value and not _safe_package_path(package_root, value).is_file():
            raise GeoCampoError("MISSING_PACKAGE_FILE", f"No existe el archivo {value}.")

    packages_dir.mkdir(parents=True, exist_ok=True)
    destination = packages_dir / f"{slugify(map_name)}.geocampo.zip"
    package_files = [file_path for file_path in package_root.rglob("*") if file_path.is_file()]
    total_files = len(package_files)
    with ZipFile(destination, "w", compression=ZIP_DEFLATED, compresslevel=6) as archive:
        for index, file_path in enumerate(package_files, start=1):
            relative_path = file_path.resolve().relative_to(package_root).as_posix()
            archive.write(file_path, relative_path)
            if on_progress:
                on_progress(index, total_files)
    if not destination.is_file() or destination.stat().st_size == 0:
        raise GeoCampoError("PACKAGE_CREATION_FAILED", "No se pudo crear el paquete.")
    return destination


def _safe_package_path(package_root: Path, relative_path: str) -> Path:
    path = Path(relative_path)
    if path.is_absolute() or ".." in path.parts:
        raise GeoCampoError("INVALID_PACKAGE_PATH", f"Ruta insegura en paquete: {relative_path}.")
    resolved = (package_root / path).resolve()
    try:
        resolved.relative_to(package_root)
    except ValueError as exc:
        raise GeoCampoError("INVALID_PACKAGE_PATH", f"Ruta fuera del paquete: {relative_path}.") from exc
    return resolved


def _require_package_file(package_root: Path, relative_path: str) -> Path:
    path = _safe_package_path(package_root, relative_path)
    if not path.is_file():
        raise GeoCampoError("MISSING_PACKAGE_FILE", f"No existe el archivo {relative_path}.")
    return path

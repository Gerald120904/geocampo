from pathlib import Path

import aiofiles
from fastapi import UploadFile
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.exceptions import GeoCampoError
from app.core.ids import new_id
from app.gis.detector import detect_source_type
from app.models import MapFile, MapProject, Project, User
from app.services.storage_service import make_directory, permanent_key, slugify, upload_permanent_file, using_r2

ALLOWED_MIME_TYPES = {
    "application/pdf",
    "application/x-pdf",
    "application/geo+json",
    "application/json",
    "application/geopackage+sqlite3",
    "application/x-sqlite3",
    "application/zip",
    "application/x-zip-compressed",
    "image/tiff",
    "application/octet-stream",
}

ALLOWED_EXTENSIONS = {".pdf", ".tif", ".tiff", ".geojson", ".json", ".gpkg", ".mbtiles", ".zip"}


async def save_upload(
    db: Session,
    project: Project,
    user: User,
    name: str,
    description: str | None,
    upload: UploadFile,
) -> MapProject:
    original_name = Path(upload.filename or "").name
    if not original_name:
        raise GeoCampoError("INVALID_FILENAME", "El archivo debe tener un nombre válido.")
    suffix = Path(original_name).suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        raise GeoCampoError(
            "UNSUPPORTED_FORMAT",
            "Formato no soportado. Sube PDF georreferenciado, GeoTIFF, GeoJSON, GeoPackage, MBTiles o Shapefile ZIP.",
            422,
        )
    if upload.content_type and upload.content_type not in ALLOWED_MIME_TYPES:
        raise GeoCampoError("INVALID_MIME_TYPE", f"MIME type no permitido: {upload.content_type}.")

    map_id = new_id("map")
    directory = make_directory(
        settings.TEMP_PATH if using_r2() else settings.ORIGINAL_FILES_PATH,
        "uploads" if using_r2() else project.company_id,
        project.id if using_r2() else project.id,
        map_id,
    )
    stored_name = f"{slugify(Path(original_name).stem, 'source')}{Path(original_name).suffix.lower()}"
    destination = directory / stored_name
    max_bytes = settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024
    size = 0
    try:
        async with aiofiles.open(destination, "wb") as output:
            while chunk := await upload.read(8 * 1024 * 1024):
                size += len(chunk)
                if size > max_bytes:
                    raise GeoCampoError(
                        "FILE_TOO_LARGE",
                        f"El archivo supera el límite de {settings.MAX_UPLOAD_SIZE_MB} MB.",
                        413,
                    )
                await output.write(chunk)
        source_type = detect_source_type(destination)
    except Exception:
        destination.unlink(missing_ok=True)
        raise
    finally:
        await upload.close()

    stored_path = upload_permanent_file(
        destination,
        permanent_key("originals", project.company_id, project.id, map_id, stored_name),
        content_type=upload.content_type,
    )

    map_project = MapProject(
        id=map_id,
        project_id=project.id,
        name=name,
        description=description,
        status="uploaded",
        source_type=source_type,
        original_file_path=stored_path,
        file_checksum_sha256=None,
        file_size_bytes=size,
        created_by=user.id,
        min_zoom=settings.DEFAULT_MAP_MIN_ZOOM,
        max_zoom=settings.DEFAULT_MAP_MAX_ZOOM,
        default_zoom=settings.DEFAULT_MAP_ZOOM,
    )
    db.add(map_project)
    db.add(
        MapFile(
            map_project_id=map_id,
            file_type="original",
            original_name=original_name,
            stored_name=stored_name,
            file_path=stored_path,
            mime_type=upload.content_type,
            size_bytes=size,
        )
    )
    db.commit()
    db.refresh(map_project)
    if using_r2():
        destination.unlink(missing_ok=True)
    return map_project

import sqlite3
import threading
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, UploadFile
from fastapi.responses import FileResponse, RedirectResponse, Response
from kombu.exceptions import OperationalError
from sqlalchemy.orm import Session

from app.core.database import SessionLocal, get_db
from app.core.exceptions import GeoCampoError
from app.core.statuses import (
    MAP_STATUS_BUILDING_PACKAGE,
    MAP_STATUS_BUILDING_PREVIEW,
    MAP_STATUS_BUILDING_TILES,
    MAP_STATUS_DUPLICATE_REVIEW,
    MAP_STATUS_INSPECTING,
    MAP_STATUS_OPTIMIZING,
    MAP_STATUS_PROCESSING,
    MAP_STATUS_QUICK_BUILDING,
    MAP_STATUS_QUICK_READY,
    MAP_STATUS_RAW_READY,
    MAP_STATUS_QUEUED,
    MAP_STATUS_READY,
    MAP_STATUS_UPLOADED,
    MAP_STATUS_WARPING,
)
from app.gis.geopdf_raw_tile import get_or_create_raw_pdf_preview, get_or_create_raw_pdf_tile
from app.models import MapProject, ProcessingJob, User
from app.repositories.job_repository import latest_for_map
from app.repositories.map_repository import get_map
from app.schemas.common import Message
from app.schemas.map_schema import (
    Bounds,
    Center,
    DuplicateCandidatePublic,
    DuplicateResolveRequest,
    DuplicateReviewResponse,
    LayerPublic,
    MapDetail,
)
from app.schemas.package_schema import PackageInfo
from app.schemas.processing_schema import JobPublic, MapStatusResponse, ProcessResponse
from app.schemas.upload_schema import UploadResponse
from app.services.access_service import get_map_for_user, get_project_for_user
from app.services.auth_service import get_current_user, require_roles
from app.services.map_service import create_quick_geopdf_view, prepare_raw_geopdf_view, process_map
from app.services.map_duplicate_service import find_duplicates
from app.services.storage_service import (
    join_storage_uri,
    materialize_file,
    presigned_get_url,
    stored_file_available,
    stored_filename,
)
from app.services.upload_service import save_upload
from app.workers.celery_app import celery_app
from app.workers.tasks import process_map_task, process_quick_view_task

router = APIRouter(prefix="/maps", tags=["maps"])
TRANSPARENT_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc````"
    b"\x00\x00\x00\x05\x00\x01\xa5\xf6E@\x00\x00\x00\x00IEND\xaeB`\x82"
)

PROCESSING_MAP_STATUSES = {
    MAP_STATUS_QUEUED,
    MAP_STATUS_PROCESSING,
    MAP_STATUS_INSPECTING,
    MAP_STATUS_BUILDING_PREVIEW,
    MAP_STATUS_WARPING,
    MAP_STATUS_BUILDING_TILES,
    MAP_STATUS_BUILDING_PACKAGE,
    MAP_STATUS_QUICK_BUILDING,
    MAP_STATUS_OPTIMIZING,
}


def _enqueue_processing(
    db: Session,
    map_id: str,
    background_tasks: BackgroundTasks | None = None,
) -> ProcessingJob:
    map_project = get_map(db, map_id)
    if not map_project:
        raise GeoCampoError("MAP_NOT_FOUND", "Mapa no encontrado.", 404)
    job = ProcessingJob(map_project_id=map_id, status="pending", step="Archivo recibido", progress=0)
    map_project.status = MAP_STATUS_QUEUED
    db.add(job)
    db.commit()
    db.refresh(job)
    if celery_app.conf.task_always_eager:
        if background_tasks is not None:
            background_tasks.add_task(_run_processing_in_background, map_id, job.id)
            return job
        thread = threading.Thread(
            target=_run_processing_in_background,
            args=(map_id, job.id),
            daemon=True,
        )
        thread.start()
        return job

    try:
        process_map_task.delay(map_id, job.id)  # type: ignore[attr-defined]
    except OperationalError as exc:
        map_project.status = MAP_STATUS_UPLOADED
        job.status = "failed"
        job.step = "Error"
        job.error_message = "No se pudo conectar con la cola de procesamiento."
        db.commit()
        raise GeoCampoError(
            "QUEUE_UNAVAILABLE",
            "No se pudo iniciar el procesamiento. Intente nuevamente.",
            503,
        ) from exc
    except Exception:
        if celery_app.conf.task_always_eager:
            db.rollback()
            db.refresh(job)
            db.refresh(map_project)
            return job
        raise
    return job


def _enqueue_quick_view(
    db: Session,
    map_id: str,
    background_tasks: BackgroundTasks | None = None,
) -> ProcessingJob:
    map_project = get_map(db, map_id)
    if not map_project:
        raise GeoCampoError("MAP_NOT_FOUND", "Mapa no encontrado.", 404)
    job = ProcessingJob(
        map_project_id=map_id,
        status="pending",
        step="Preparando vista rapida",
        progress=0,
    )
    map_project.status = MAP_STATUS_QUEUED
    map_project.processing_message = "Preparando vista rapida"
    db.add(job)
    db.commit()
    db.refresh(job)

    if celery_app.conf.task_always_eager:
        if background_tasks is not None:
            background_tasks.add_task(_run_quick_view_in_background, map_id, job.id)
            return job
        thread = threading.Thread(
            target=_run_quick_view_in_background,
            args=(map_id, job.id),
            daemon=True,
        )
        thread.start()
        return job

    try:
        process_quick_view_task.delay(map_id, job.id)  # type: ignore[attr-defined]
    except OperationalError as exc:
        map_project.status = MAP_STATUS_UPLOADED
        job.status = "failed"
        job.step = "Error"
        job.error_message = "No se pudo conectar con la cola de procesamiento."
        db.commit()
        raise GeoCampoError(
            "QUEUE_UNAVAILABLE",
            "No se pudo iniciar la vista rapida. Intente nuevamente.",
            503,
        ) from exc
    return job


def _run_processing_in_background(map_id: str, job_id: str) -> None:
    with SessionLocal() as background_db:
        process_map(background_db, map_id, job_id)


def _run_quick_view_in_background(map_id: str, job_id: str) -> None:
    with SessionLocal() as background_db:
        create_quick_geopdf_view(background_db, map_id, job_id)


@router.post("/upload", response_model=UploadResponse, status_code=201)
async def upload_map(
    background_tasks: BackgroundTasks,
    project_id: str = Form(...),
    name: str = Form(..., min_length=2, max_length=200),
    description: str | None = Form(default=None),
    auto_process: bool = Form(default=True),
    processing_mode: str = Form(default="raw"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin")),
) -> UploadResponse:
    project = get_project_for_user(db, project_id, user)
    map_project = await save_upload(db, project, user, name, description, file)
    if auto_process:
        if processing_mode == "raw" and map_project.source_type == "geopdf":
            map_project = prepare_raw_geopdf_view(db, map_project.id)
        elif processing_mode == "quick" and map_project.source_type == "geopdf":
            _enqueue_quick_view(db, map_project.id, background_tasks)
            db.refresh(map_project)
        else:
            _enqueue_processing(db, map_project.id, background_tasks)
            db.refresh(map_project)
    return UploadResponse(
        map_id=map_project.id,
        status=map_project.status,
        message="Archivo recibido correctamente",
    )


@router.post("/{map_id}/process", response_model=ProcessResponse, status_code=202)
def start_processing(
    map_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin")),
) -> ProcessResponse:
    map_project = get_map_for_user(db, map_id, user)
    if map_project.status in PROCESSING_MAP_STATUSES:
        raise GeoCampoError("MAP_ALREADY_PROCESSING", "El mapa ya está en procesamiento.", 409)
    job = _enqueue_processing(db, map_id, background_tasks)
    return ProcessResponse(job_id=job.id, map_id=map_id, status=MAP_STATUS_QUEUED)


@router.post("/{map_id}/retry", response_model=ProcessResponse, status_code=202)
def retry_processing(
    map_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin")),
) -> ProcessResponse:
    map_project = get_map_for_user(db, map_id, user)
    if map_project.status in PROCESSING_MAP_STATUSES:
        raise GeoCampoError("MAP_ALREADY_PROCESSING", "El mapa ya esta en procesamiento.", 409)
    job = _enqueue_processing(db, map_id, background_tasks)
    return ProcessResponse(job_id=job.id, map_id=map_id, status=MAP_STATUS_QUEUED)


@router.post("/{map_id}/optimize", response_model=ProcessResponse, status_code=202)
def optimize_map(
    map_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin")),
) -> ProcessResponse:
    map_project = get_map_for_user(db, map_id, user)
    if map_project.status in PROCESSING_MAP_STATUSES:
        raise GeoCampoError("MAP_ALREADY_PROCESSING", "El mapa ya esta en procesamiento.", 409)
    if map_project.source_type != "geopdf":
        raise GeoCampoError(
            "OPTIMIZE_ONLY_GEOPDF",
            "La optimizacion especial aplica para GeoPDF.",
            422,
        )
    job = _enqueue_processing(db, map_id, background_tasks)
    return ProcessResponse(job_id=job.id, map_id=map_id, status=MAP_STATUS_QUEUED)


@router.get("/{map_id}/status", response_model=MapStatusResponse)
def processing_status(
    map_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> MapStatusResponse:
    map_project = get_map_for_user(db, map_id, user)
    job = latest_for_map(db, map_id)
    return MapStatusResponse(
        map_id=map_id,
        status=map_project.status,
        job=JobPublic.model_validate(job, from_attributes=True) if job else None,
    )


@router.get("/{map_id}", response_model=MapDetail)
def map_detail(
    map_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> MapDetail:
    get_map_for_user(db, map_id, user)
    map_project = get_map(db, map_id)
    if not map_project:
        raise GeoCampoError("MAP_NOT_FOUND", "Mapa no encontrado.", 404)
    raw_bounds = map_project.raw_bounds_geometry or map_project.bounds_geometry
    bounds = Bounds(**raw_bounds) if raw_bounds else None
    center = (
        Center(
            lat=map_project.raw_center_lat if map_project.raw_center_lat is not None else map_project.center_lat,
            lng=map_project.raw_center_lng if map_project.raw_center_lng is not None else map_project.center_lng,
        )
        if (
            (map_project.raw_center_lat is not None and map_project.raw_center_lng is not None)
            or (map_project.center_lat is not None and map_project.center_lng is not None)
        )
        else None
    )
    job = latest_for_map(db, map_id)
    raw_available = bool(map_project.raw_view_ready_at)
    quick_available = bool(map_project.quick_mbtiles_file_path)
    optimized_available = bool(map_project.package_file_path)
    is_processing = map_project.status in PROCESSING_MAP_STATUSES
    view_mode = (
        "optimized"
        if optimized_available and map_project.status == "ready"
        else "quick"
        if quick_available
        else "raw"
        if raw_available
        else "none"
    )
    return MapDetail(
        id=map_project.id,
        project_id=map_project.project_id,
        name=map_project.name,
        description=map_project.description,
        status=map_project.status,
        source_type=map_project.source_type,
        min_zoom=map_project.quick_min_zoom or map_project.min_zoom
        if view_mode == "quick"
        else map_project.min_zoom,
        max_zoom=map_project.quick_max_zoom or map_project.max_zoom
        if view_mode == "quick"
        else map_project.max_zoom,
        default_zoom=map_project.quick_default_zoom or map_project.default_zoom
        if view_mode == "quick"
        else map_project.default_zoom,
        bounds=bounds,
        center=center,
        layers=[LayerPublic.model_validate(layer) for layer in map_project.layers],
        package_available=optimized_available,
        tile_version=map_project.package_checksum_sha256
        or (map_project.processed_at.isoformat() if map_project.processed_at else None),
        raw_available=raw_available,
        quick_available=quick_available,
        optimized_available=optimized_available,
        can_open=raw_available or quick_available or optimized_available,
        can_optimize=(
            map_project.source_type == "geopdf"
            and (raw_available or quick_available)
            and not optimized_available
            and not is_processing
        ),
        view_mode=view_mode,
        overlay_url=None,
        raw_pdf_url=f"/api/maps/{map_project.id}/raw-pdf" if raw_available else None,
        processing_progress=job.progress if job and job.status in {"pending", "running"} else None,
        processing_message=map_project.processing_message,
    )


@router.get("/{map_id}/duplicates", response_model=DuplicateReviewResponse)
def duplicate_review(
    map_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DuplicateReviewResponse:
    map_project = get_map_for_user(db, map_id, user)
    candidates = find_duplicates(db, map_project)
    return DuplicateReviewResponse(
        map_id=map_project.id,
        message="Ya existe un mapa en este proyecto con una ubicacion similar.",
        candidates=[
            DuplicateCandidatePublic(
                map_id=item.map_id,
                name=item.name,
                duplicate_type=item.duplicate_type,
                score=item.score,
                reason=item.reason,
            )
            for item in candidates
        ],
    )


@router.post("/{map_id}/duplicates/resolve", response_model=Message)
def resolve_duplicate(
    map_id: str,
    payload: DuplicateResolveRequest,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin")),
) -> Message:
    map_project = get_map_for_user(db, map_id, user)
    existing = db.get(MapProject, payload.existing_map_id) if payload.existing_map_id else None
    if existing and existing.project_id != map_project.project_id:
        raise GeoCampoError("MAP_NOT_FOUND", "Mapa existente no encontrado.", 404)

    if payload.action == "open_existing":
        return Message(message="Abrir mapa existente")
    if payload.action == "cancel":
        map_project.status = "deleted"
        map_project.deleted_at = datetime.utcnow()
        db.commit()
        return Message(message="Subida cancelada")
    if payload.action == "replace_existing":
        if not existing:
            raise GeoCampoError("EXISTING_MAP_REQUIRED", "Seleccione el mapa a reemplazar.", 400)
        existing.status = "replaced"
        existing.replaced_by_map_id = map_project.id
        existing.archived_at = datetime.utcnow()
        map_project.duplicate_of_map_id = existing.id
        map_project.duplicate_reason = "replace_existing"
    elif payload.action == "save_new_version":
        if existing:
            map_project.duplicate_of_map_id = existing.id
        map_project.name = f"{map_project.name} - version 2"
        map_project.duplicate_reason = "save_new_version"
    elif payload.action == "upload_anyway":
        map_project.duplicate_reason = "upload_anyway"
    else:
        raise GeoCampoError("INVALID_DUPLICATE_ACTION", "Accion de duplicado no valida.", 400)

    map_project.status = MAP_STATUS_UPLOADED if map_project.status == MAP_STATUS_DUPLICATE_REVIEW else map_project.status
    db.commit()
    _enqueue_processing(db, map_project.id)
    return Message(message="Decision aplicada correctamente")


def _download(path_value: str | None, media_type: str, filename: str | None = None) -> FileResponse | RedirectResponse:
    signed_url = presigned_get_url(path_value)
    if signed_url:
        return RedirectResponse(signed_url, status_code=302)

    path = materialize_file(path_value)
    if not path or not path.is_file():
        raise GeoCampoError("FILE_NOT_FOUND", "El archivo solicitado no esta disponible.", 404)
    return FileResponse(path, media_type=media_type, filename=filename or path.name)


@router.get("/{map_id}/package/info", response_model=PackageInfo)
def package_info(
    map_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> PackageInfo:
    map_project = get_map_for_user(db, map_id, user)
    return PackageInfo(
        map_id=map_project.id,
        available=bool(stored_file_available(map_project.package_file_path) and map_project.status == "ready"),
        filename=stored_filename(map_project.package_file_path),
        size_bytes=map_project.package_size_bytes,
        checksum_sha256=map_project.package_checksum_sha256,
        package_version=map_project.package_version,
        created_at=map_project.package_created_at,
    )


@router.get("/{map_id}/package")
def download_package(
    map_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> FileResponse | RedirectResponse:
    map_project = get_map_for_user(db, map_id, user)
    if map_project.status != "ready":
        raise GeoCampoError("PACKAGE_NOT_READY", "El paquete todavía no está listo.", 409)
    return _download(map_project.package_file_path, "application/zip")


@router.get("/{map_id}/package/download-url", response_model=dict[str, str])
def package_download_url(
    map_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict[str, str]:
    map_project = get_map_for_user(db, map_id, user)
    if map_project.status != "ready":
        raise GeoCampoError("PACKAGE_NOT_READY", "El paquete todavÃ­a no estÃ¡ listo.", 409)

    signed_url = presigned_get_url(map_project.package_file_path)
    if signed_url:
        return {"download_url": signed_url}

    return {"download_url": f"/api/maps/{map_project.id}/package"}


@router.get("/{map_id}/preview")
def download_preview(
    map_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> FileResponse | RedirectResponse:
    map_project = get_map_for_user(db, map_id, user)
    if map_project.preview_file_path:
        return _download(map_project.preview_file_path, "image/png")
    if map_project.source_type == "geopdf" and map_project.raw_view_ready_at:
        return FileResponse(
            get_or_create_raw_pdf_preview(map_project),
            media_type="image/png",
            headers={"Cache-Control": "private, max-age=86400"},
        )
    return _download(map_project.preview_file_path, "image/png")


@router.get("/{map_id}/raw-pdf")
def raw_pdf(
    map_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> FileResponse | RedirectResponse:
    map_project = get_map_for_user(db, map_id, user)
    if map_project.source_type != "geopdf":
        raise GeoCampoError("RAW_PDF_ONLY_GEOPDF", "Este archivo no es un GeoPDF.", 422)
    signed_url = presigned_get_url(map_project.original_file_path)
    if signed_url:
        return RedirectResponse(signed_url, status_code=302)

    path = materialize_file(map_project.original_file_path)
    if not path or not path.is_file():
        raise GeoCampoError("RAW_PDF_NOT_FOUND", "No se encontro el PDF original.", 404)
    return FileResponse(
        path=path,
        media_type="application/pdf",
        filename=path.name,
        content_disposition_type="inline",
        headers={"Cache-Control": "private, max-age=3600"},
    )


@router.get("/{map_id}/raw-tiles/{z}/{x}/{y}.png")
def raw_pdf_tile(
    map_id: str,
    z: int,
    x: int,
    y: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> FileResponse:
    map_project = get_map_for_user(db, map_id, user)
    if map_project.source_type != "geopdf":
        raise GeoCampoError(
            "RAW_TILE_ONLY_GEOPDF",
            "Los tiles crudos solo aplican para GeoPDF.",
            422,
        )
    if map_project.status not in {
        MAP_STATUS_RAW_READY,
        MAP_STATUS_PROCESSING,
        MAP_STATUS_OPTIMIZING,
        MAP_STATUS_QUICK_READY,
        MAP_STATUS_READY,
    }:
        raise GeoCampoError(
            "RAW_VIEW_NOT_READY",
            "La vista cruda del PDF todavia no esta lista.",
            409,
        )

    tile_path = get_or_create_raw_pdf_tile(
        map_project=map_project,
        z=z,
        x=x,
        y=y,
    )
    return FileResponse(
        tile_path,
        media_type="image/png",
        headers={"Cache-Control": "private, max-age=86400"},
    )


@router.get("/{map_id}/tiles/{z}/{x}/{y}.png")
def raster_tile(
    map_id: str,
    z: int,
    x: int,
    y: int,
    view: str = "auto",
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Response:
    map_project = get_map_for_user(db, map_id, user)
    mbtiles_path = _selected_mbtiles_path(map_project, view)
    if not mbtiles_path:
        raise GeoCampoError("MBTILES_NOT_FOUND", "El mapa no tiene tiles disponibles.", 404)

    try:
        with sqlite3.connect(f"file:{mbtiles_path.resolve()}?mode=ro", uri=True) as connection:
            metadata = dict(connection.execute("SELECT name, value FROM metadata").fetchall())
            tile_rows = _candidate_tile_rows(z, y, metadata.get("scheme"))
            row = None
            for tile_row in tile_rows:
                row = connection.execute(
                    """
                    SELECT tile_data
                    FROM tiles
                    WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?
                    """,
                    (z, x, tile_row),
                ).fetchone()
                if row:
                    break
    except sqlite3.Error as exc:
        raise GeoCampoError("MBTILES_INVALID", "No se pudo leer el MBTiles del mapa.", 500) from exc

    cache_headers = {"Cache-Control": "public, max-age=31536000, immutable"}
    if not row:
        return Response(content=TRANSPARENT_PNG, media_type="image/png", headers=cache_headers)

    tile_format = metadata.get("format", "png").lower()
    media_type = "image/jpeg" if tile_format in {"jpg", "jpeg"} else "image/png"
    return Response(content=row[0], media_type=media_type, headers=cache_headers)


def _selected_mbtiles_path(map_project: MapProject, view: str) -> Path | None:
    normalized_view = view.lower()
    optimized_path = _mbtiles_path(map_project.processed_folder_path)
    quick_path = materialize_file(map_project.quick_mbtiles_file_path)
    if quick_path and not quick_path.is_file():
        quick_path = None

    if normalized_view == "quick":
        return quick_path
    if normalized_view == "optimized":
        return optimized_path
    return optimized_path or quick_path


def _mbtiles_path(processed_folder_path: str | None) -> Path | None:
    if not processed_folder_path:
        return None
    path = materialize_file(join_storage_uri(processed_folder_path, "map.mbtiles"))
    return path if path and path.is_file() else None


def _candidate_tile_rows(z: int, y: int, scheme: str | None) -> list[int]:
    tms_y = (1 << z) - 1 - y
    if scheme and scheme.lower() == "xyz":
        return [y, tms_y]
    return [tms_y, y]


@router.delete("/{map_id}", response_model=Message)
def delete_map(
    map_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin")),
) -> Message:
    map_project = get_map_for_user(db, map_id, user)
    map_project.status = "deleted"
    map_project.deleted_at = datetime.utcnow()
    db.commit()
    return Message(message="Mapa eliminado correctamente")


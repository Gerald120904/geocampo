from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import GeoCampoError
from app.core.statuses import MAP_STATUS_READY
from app.gis.bounds import center, union_bounds
from app.models import Company, MapProject, ProcessingJob, Project, User
from app.repositories.job_repository import latest_for_map
from app.repositories.map_repository import list_for_project
from app.schemas.map_schema import Bounds, Center, MapListItem, ViewerMap
from app.schemas.project_schema import (
    ProjectCreate,
    ProjectDetail,
    ProjectPublic,
    ProjectUpdate,
    ProjectViewer,
    ProjectViewerProject,
)
from app.services.access_service import assert_company_access, get_project_for_user
from app.services.auth_service import get_current_user, require_roles

router = APIRouter(prefix="/projects", tags=["projects"])
ACTIVE_STATUSES = {"uploaded", "queued", "processing", "inspecting", "building_preview", "warping", "building_tiles", "building_package", "quick_building", "quick_ready", "optimizing", "raw_ready", "ready", "duplicate_review", "failed"}
PROCESSING_STATUSES = ACTIVE_STATUSES - {"quick_ready", "raw_ready", "ready", "failed", "duplicate_review"}


@router.post("", response_model=ProjectPublic, status_code=201)
def create_project(
    payload: ProjectCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin")),
) -> ProjectPublic:
    assert_company_access(user, payload.company_id)
    if not db.get(Company, payload.company_id):
        raise GeoCampoError("COMPANY_NOT_FOUND", "Empresa no encontrada.", 404)
    project = Project(**payload.model_dump())
    db.add(project)
    db.commit()
    db.refresh(project)
    return _project_public(project, [])


@router.get("", response_model=list[ProjectPublic])
def list_projects(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[ProjectPublic]:
    statement = select(Project).order_by(Project.name)
    if user.role != "super_admin":
        statement = statement.where(Project.company_id == user.company_id)
    projects = list(db.scalars(statement))
    return [_project_public(project, list_for_project(db, project.id)) for project in projects]


@router.get("/{project_id}", response_model=ProjectDetail)
def project_detail(
    project_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ProjectDetail:
    project = get_project_for_user(db, project_id, user)
    maps = list_for_project(db, project_id)
    public = _project_public(project, maps)
    return ProjectDetail(
        **public.model_dump(),
        bounds=_bounds_model(_combined_bounds(maps)),
        center=_center_model(_combined_bounds(maps)),
        maps=[_map_list_item(item, latest_for_map(db, item.id)) for item in maps],
    )


@router.patch("/{project_id}", response_model=ProjectPublic)
def update_project(
    project_id: str,
    payload: ProjectUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin")),
) -> ProjectPublic:
    project = get_project_for_user(db, project_id, user)
    if payload.name is not None:
        project.name = payload.name
    if "description" in payload.model_fields_set:
        project.description = payload.description
    db.commit()
    db.refresh(project)
    return _project_public(project, list_for_project(db, project.id))


@router.delete("/{project_id}", response_model=dict[str, str])
def delete_project(
    project_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin")),
) -> dict[str, str]:
    project = get_project_for_user(db, project_id, user)
    now = datetime.utcnow()
    for map_project in list_for_project(db, project.id):
        map_project.status = "deleted"
        map_project.deleted_at = now
    db.delete(project)
    db.commit()
    return {"message": "Proyecto eliminado correctamente"}


@router.get("/{project_id}/maps", response_model=list[MapListItem])
def project_maps(
    project_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[MapListItem]:
    get_project_for_user(db, project_id, user)
    maps = list_for_project(db, project_id)
    return [_map_list_item(item, latest_for_map(db, item.id)) for item in maps]


@router.get("/{project_id}/viewer", response_model=ProjectViewer)
def project_viewer(
    project_id: str,
    map_ids: str | None = Query(default=None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ProjectViewer:
    project = get_project_for_user(db, project_id, user)
    selected_ids = {item.strip() for item in map_ids.split(",")} if map_ids else set()
    maps = [
        item
        for item in list_for_project(db, project_id)
        if item.status == MAP_STATUS_READY
        and item.package_file_path
        and item.bounds_geometry
        and (not selected_ids or item.id in selected_ids)
    ]
    combined_bounds = _combined_bounds(maps)
    return ProjectViewer(
        project=ProjectViewerProject(id=project.id, name=project.name),
        bounds=_bounds_model(combined_bounds),
        center=_center_model(combined_bounds),
        maps=[
            ViewerMap(
                id=item.id,
                name=item.name,
                status=item.status,
                tile_url=f"/api/maps/{item.id}/tiles/{{z}}/{{x}}/{{y}}.png",
                bounds=_bounds_model(item.bounds_geometry),
                opacity=1.0 if index == 0 else 0.85,
                visible=True,
                min_zoom=item.min_zoom,
                max_zoom=item.max_zoom,
            )
            for index, item in enumerate(maps)
        ],
    )


def _project_public(project: Project, maps: list[MapProject]) -> ProjectPublic:
    active_maps = [item for item in maps if item.status not in {"deleted", "archived", "replaced"}]
    return ProjectPublic(
        id=project.id,
        company_id=project.company_id,
        name=project.name,
        description=project.description,
        created_at=project.created_at,
        updated_at=project.updated_at,
        maps_count=len(active_maps),
        ready_maps_count=sum(1 for item in active_maps if item.status == "ready"),
        processing_maps_count=sum(1 for item in active_maps if item.status in PROCESSING_STATUSES),
        failed_maps_count=sum(1 for item in active_maps if item.status == "failed"),
    )


def _map_list_item(item: MapProject, job: ProcessingJob | None = None) -> MapListItem:
    quick_available = bool(item.quick_mbtiles_file_path)
    raw_available = bool(item.raw_view_ready_at)
    optimized_available = bool(item.package_file_path)
    is_processing = item.status in PROCESSING_STATUSES
    progress = job.progress if job and job.status in {"pending", "running"} else None
    view_mode = (
        "optimized"
        if optimized_available and item.status == "ready"
        else "quick"
        if quick_available
        else "raw"
        if raw_available
        else "none"
    )
    return MapListItem(
        id=item.id,
        name=item.name,
        status=item.status,
        source_type=item.source_type,
        has_package=optimized_available,
        preview_url=f"/api/maps/{item.id}/preview"
        if item.preview_file_path or raw_available
        else None,
        created_at=item.created_at,
        raw_available=raw_available,
        quick_available=quick_available,
        optimized_available=optimized_available,
        can_open=raw_available or quick_available or optimized_available,
        can_optimize=(
            item.source_type == "geopdf"
            and (raw_available or quick_available)
            and not optimized_available
            and not is_processing
        ),
        view_mode=view_mode,
        processing_progress=progress,
        processing_message=item.processing_message,
    )


def _combined_bounds(maps: list[MapProject]) -> dict[str, float] | None:
    return union_bounds([item.bounds_geometry for item in maps if item.bounds_geometry])


def _bounds_model(bounds: dict | None) -> Bounds | None:
    return Bounds(**bounds) if bounds else None


def _center_model(bounds: dict | None) -> Center | None:
    return Center(**center(bounds)) if bounds else None

import random
import secrets
import string
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.exceptions import GeoCampoError
from app.models import (
    MapFile,
    MapLayer,
    MapProject,
    Project,
    ProjectShare,
    ProjectShareRedemption,
    User,
)
from app.models.base import utcnow

INACTIVE_MAP_STATUSES = {"deleted", "archived", "replaced"}


def create_project_share(
    db: Session,
    project: Project,
    user: User,
    expires_in_days: int = 7,
    max_uses: int = 10,
    include_observations: bool = False,
    include_only_ready_maps: bool = True,
) -> ProjectShare:
    if not user.company_id and user.role != "super_admin":
        raise GeoCampoError(
            "USER_WITHOUT_COMPANY",
            "El usuario no tiene empresa asignada.",
            400,
        )

    share = ProjectShare(
        project_id=project.id,
        owner_user_id=user.id,
        owner_company_id=project.company_id,
        token=_new_token(),
        code=_new_code(db),
        mode="copy",
        expires_at=utcnow() + timedelta(days=expires_in_days),
        max_uses=max_uses,
        used_count=0,
        include_observations=include_observations,
        include_only_ready_maps=include_only_ready_maps,
    )
    db.add(share)
    db.commit()
    db.refresh(share)
    return share


def get_share_preview(db: Session, token_or_code: str) -> tuple[ProjectShare, Project, User | None, list[MapProject]]:
    share = _get_active_share(db, token_or_code)
    project = db.get(Project, share.project_id)
    if not project:
        raise GeoCampoError("PROJECT_NOT_FOUND", "Proyecto no encontrado.", 404)

    owner = db.get(User, share.owner_user_id)
    statement = (
        select(MapProject)
        .where(MapProject.project_id == project.id)
        .where(MapProject.status.notin_(INACTIVE_MAP_STATUSES))
        .options(selectinload(MapProject.files), selectinload(MapProject.layers))
        .order_by(MapProject.created_at)
    )
    if share.include_only_ready_maps:
        statement = statement.where(
            MapProject.status == "ready",
            MapProject.package_file_path.is_not(None),
        )

    return share, project, owner, list(db.scalars(statement))


def accept_project_share(db: Session, token_or_code: str, user: User) -> tuple[Project, int]:
    if not user.company_id:
        raise GeoCampoError(
            "USER_WITHOUT_COMPANY",
            "Tu cuenta no tiene empresa asignada.",
            400,
        )

    share, source_project, _owner, source_maps = get_share_preview(db, token_or_code)
    existing_redemption = db.scalar(
        select(ProjectShareRedemption).where(
            ProjectShareRedemption.share_id == share.id,
            ProjectShareRedemption.accepted_by_user_id == user.id,
        )
    )
    if existing_redemption:
        existing_project = db.get(Project, existing_redemption.created_project_id)
        if existing_project:
            return existing_project, len(source_maps)

    new_project = Project(
        company_id=user.company_id,
        name=f"{source_project.name} - copia",
        description=source_project.description,
    )
    db.add(new_project)
    db.flush()

    imported_count = 0
    for source_map in source_maps:
        cloned_map = _clone_map(source_map, new_project.id, user.id)
        db.add(cloned_map)
        db.flush()

        for file in source_map.files:
            db.add(_clone_file(file, cloned_map.id))
        for layer in source_map.layers:
            db.add(_clone_layer(layer, cloned_map.id))
        imported_count += 1

    share.used_count += 1
    db.add(
        ProjectShareRedemption(
            share_id=share.id,
            accepted_by_user_id=user.id,
            accepted_by_company_id=user.company_id,
            created_project_id=new_project.id,
            created_at=utcnow(),
        )
    )
    db.commit()
    db.refresh(new_project)
    return new_project, imported_count


def revoke_project_share(db: Session, share_id: str, user: User) -> None:
    share = db.get(ProjectShare, share_id)
    if not share:
        raise GeoCampoError("SHARE_NOT_FOUND", "Enlace no encontrado.", 404)
    if user.role != "super_admin" and share.owner_user_id != user.id:
        raise GeoCampoError("FORBIDDEN", "No puedes revocar este enlace.", 403)

    share.revoked_at = utcnow()
    db.commit()


def _get_active_share(db: Session, token_or_code: str) -> ProjectShare:
    value = token_or_code.strip()
    share = db.scalar(
        select(ProjectShare).where(
            (ProjectShare.token == value) | (ProjectShare.code == value.upper())
        )
    )
    if not share:
        raise GeoCampoError("SHARE_NOT_FOUND", "Enlace o codigo invalido.", 404)

    now = _now_for(share.expires_at)
    if share.revoked_at is not None:
        raise GeoCampoError("SHARE_REVOKED", "Este enlace fue revocado.", 410)
    if share.expires_at is not None and share.expires_at < now:
        raise GeoCampoError("SHARE_EXPIRED", "Este enlace ya vencio.", 410)
    if share.used_count >= share.max_uses:
        raise GeoCampoError("SHARE_LIMIT_REACHED", "Este enlace ya alcanzo su limite de usos.", 410)
    return share


def _clone_map(source: MapProject, new_project_id: str, user_id: str) -> MapProject:
    excluded = {
        "id",
        "project_id",
        "created_by",
        "created_at",
        "updated_at",
        "deleted_at",
        "archived_at",
        "duplicate_of_map_id",
        "replaced_by_map_id",
        "bounds_geom",
        "footprint_geom",
    }
    data = {
        column.name: getattr(source, column.name)
        for column in MapProject.__table__.columns
        if column.name not in excluded
    }
    return MapProject(
        **data,
        project_id=new_project_id,
        created_by=user_id,
        deleted_at=None,
        archived_at=None,
        duplicate_of_map_id=None,
        replaced_by_map_id=None,
    )


def _clone_file(source: MapFile, new_map_id: str) -> MapFile:
    return MapFile(
        map_project_id=new_map_id,
        file_type=source.file_type,
        original_name=source.original_name,
        stored_name=source.stored_name,
        file_path=source.file_path,
        mime_type=source.mime_type,
        size_bytes=source.size_bytes,
    )


def _clone_layer(source: MapLayer, new_map_id: str) -> MapLayer:
    return MapLayer(
        map_project_id=new_map_id,
        name=source.name,
        layer_key=source.layer_key,
        layer_type=source.layer_type,
        geometry_type=source.geometry_type,
        file_path=source.file_path,
        visible_default=source.visible_default,
        opacity_default=source.opacity_default,
        properties_schema=source.properties_schema,
        feature_count=source.feature_count,
    )


def _new_token() -> str:
    return secrets.token_urlsafe(48)


def _new_code(db: Session) -> str:
    alphabet = string.ascii_uppercase + string.digits
    for _ in range(20):
        code = f"GC-{''.join(random.choices(alphabet, k=4))}-{''.join(random.choices(alphabet, k=4))}"
        if not db.scalar(select(ProjectShare).where(ProjectShare.code == code)):
            return code
    raise GeoCampoError("CODE_GENERATION_FAILED", "No se pudo generar codigo unico.", 500)


def _now_for(value) -> object:
    now = utcnow()
    if value is not None and getattr(value, "tzinfo", None) is None:
        return now.replace(tzinfo=None)
    return now

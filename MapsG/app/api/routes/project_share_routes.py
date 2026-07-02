from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import User
from app.schemas.project_share_schema import (
    AcceptProjectShareResponse,
    ProjectShareCreate,
    ProjectShareCreated,
    SharedProjectPreview,
)
from app.services.access_service import get_project_for_user
from app.services.auth_service import get_current_user, require_roles
from app.services.project_share_service import (
    accept_project_share,
    create_project_share,
    get_share_preview,
    revoke_project_share,
)

router = APIRouter(tags=["project-shares"])


@router.post(
    "/projects/{project_id}/shares",
    response_model=ProjectShareCreated,
    status_code=201,
)
def create_share(
    project_id: str,
    payload: ProjectShareCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin")),
) -> ProjectShareCreated:
    project = get_project_for_user(db, project_id, user)
    return create_project_share(
        db,
        project,
        user,
        expires_in_days=payload.expires_in_days,
        max_uses=payload.max_uses,
        include_observations=payload.include_observations,
        include_only_ready_maps=payload.include_only_ready_maps,
    )


@router.get(
    "/project-shares/{token_or_code}",
    response_model=SharedProjectPreview,
)
def preview_share(
    token_or_code: str,
    db: Session = Depends(get_db),
) -> SharedProjectPreview:
    share, project, owner, maps = get_share_preview(db, token_or_code)
    ready_count = sum(1 for item in maps if item.status == "ready")
    return SharedProjectPreview(
        token=share.token,
        code=share.code,
        project_name=project.name,
        project_description=project.description,
        owner_name=owner.name if owner else "GeoCampo",
        maps_count=len(maps),
        ready_maps_count=ready_count,
        expires_at=share.expires_at,
        mode=share.mode,
    )


@router.post(
    "/project-shares/{token_or_code}/accept",
    response_model=AcceptProjectShareResponse,
)
def accept_share(
    token_or_code: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AcceptProjectShareResponse:
    project, imported_count = accept_project_share(db, token_or_code, user)
    return AcceptProjectShareResponse(
        project_id=project.id,
        project_name=project.name,
        imported_maps_count=imported_count,
        message="Proyecto importado correctamente.",
    )


@router.delete("/project-shares/{share_id}", response_model=dict[str, str])
def revoke_share(
    share_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin")),
) -> dict[str, str]:
    revoke_project_share(db, share_id, user)
    return {"message": "Enlace revocado correctamente."}

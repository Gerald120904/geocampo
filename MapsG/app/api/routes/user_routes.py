from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import GeoCampoError
from app.core.security import hash_password, validate_password_strength
from app.models import Company, User
from app.schemas.user_schema import UserCreate, UserListResponse, UserPublic, UserUpdateMe
from app.services.access_service import assert_company_access
from app.services.auth_service import get_current_user, require_roles

router = APIRouter(prefix="/users", tags=["users"])


@router.patch("/me", response_model=UserPublic)
def update_me(
    payload: UserUpdateMe,
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
) -> User:
    new_name = payload.name.strip()

    if len(new_name) < 2:
        raise GeoCampoError("INVALID_NAME", "El nombre debe tener al menos 2 caracteres.", 422)

    current.name = new_name
    db.commit()
    db.refresh(current)
    return current


@router.get("", response_model=UserListResponse)
def list_users(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    q: str | None = Query(default=None, min_length=1, max_length=200),
    role: str | None = Query(default=None, pattern="^(super_admin|company_admin|technician|viewer)$"),
    db: Session = Depends(get_db),
    current: User = Depends(require_roles("super_admin", "company_admin")),
) -> UserListResponse:
    filters = []
    if current.role != "super_admin":
        filters.append(User.company_id == current.company_id)
    if q:
        search_term = q.strip()
        if search_term:
            search = f"%{search_term}%"
            filters.append(User.name.ilike(search) | User.email.ilike(search))
    if role:
        filters.append(User.role == role)

    total_statement = select(func.count()).select_from(User).where(*filters)
    total = db.scalar(total_statement) or 0

    statement = select(User).where(*filters).order_by(User.name).limit(limit).offset(offset)
    items = list(db.scalars(statement))
    return UserListResponse(
        items=items,
        total=total,
        limit=limit,
        offset=offset,
        has_more=offset + len(items) < total,
    )


@router.post("", response_model=UserPublic, status_code=201)
def create_user(
    payload: UserCreate,
    db: Session = Depends(get_db),
    current: User = Depends(require_roles("super_admin", "company_admin")),
) -> User:
    assert_company_access(current, payload.company_id)
    if not db.get(Company, payload.company_id):
        raise GeoCampoError("COMPANY_NOT_FOUND", "Empresa no encontrada.", 404)
    if db.scalar(select(User).where(User.email == payload.email.lower())):
        raise GeoCampoError("USER_EXISTS", "Ya existe un usuario con ese correo.", 409)
    if current.role == "company_admin" and payload.role == "company_admin":
        raise GeoCampoError("FORBIDDEN", "Solo super_admin puede crear otro company_admin.", 403)
    try:
        validate_password_strength(payload.password)
    except ValueError as exc:
        raise GeoCampoError("WEAK_PASSWORD", str(exc), 422) from exc
    user = User(
        name=payload.name,
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        role=payload.role,
        company_id=payload.company_id,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

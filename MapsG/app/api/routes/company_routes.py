from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import GeoCampoError
from app.models import Company, User
from app.schemas.company_schema import CompanyCreate, CompanyPublic
from app.services.auth_service import get_current_user, require_roles

router = APIRouter(prefix="/companies", tags=["companies"])


@router.post("", response_model=CompanyPublic, status_code=201)
def create_company(
    payload: CompanyCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_roles("super_admin")),
) -> Company:
    if db.scalar(select(Company).where(Company.identifier == payload.identifier)):
        raise GeoCampoError("COMPANY_EXISTS", "Ya existe una empresa con ese identificador.", 409)
    company = Company(**payload.model_dump())
    db.add(company)
    db.commit()
    db.refresh(company)
    return company


@router.get("", response_model=list[CompanyPublic])
def list_companies(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[Company]:
    statement = select(Company).order_by(Company.name)
    if user.role != "super_admin":
        statement = statement.where(Company.id == user.company_id)
    return list(db.scalars(statement))


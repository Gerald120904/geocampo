from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Project


def list_for_company(db: Session, company_id: str | None = None) -> list[Project]:
    statement = select(Project).order_by(Project.name)
    if company_id:
        statement = statement.where(Project.company_id == company_id)
    return list(db.scalars(statement))


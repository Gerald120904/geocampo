from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Company


def list_companies(db: Session) -> list[Company]:
    return list(db.scalars(select(Company).order_by(Company.name)))


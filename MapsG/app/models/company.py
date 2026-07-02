from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.ids import new_id
from app.models.base import TimestampMixin


class Company(TimestampMixin, Base):
    __tablename__ = "companies"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=lambda: new_id("company"))
    name: Mapped[str] = mapped_column(String(200), index=True)
    legal_name: Mapped[str | None] = mapped_column(String(250))
    identifier: Mapped[str] = mapped_column(String(100), unique=True, index=True)

    users = relationship("User", back_populates="company")
    projects = relationship("Project", back_populates="company", cascade="all, delete-orphan")


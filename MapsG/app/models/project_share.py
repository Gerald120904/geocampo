from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.ids import new_id
from app.models.base import TimestampMixin


class ProjectShare(TimestampMixin, Base):
    __tablename__ = "project_shares"

    id: Mapped[str] = mapped_column(
        String(64),
        primary_key=True,
        default=lambda: new_id("share"),
    )
    project_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("projects.id", ondelete="CASCADE"),
        index=True,
    )
    owner_user_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("users.id"),
        index=True,
    )
    owner_company_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("companies.id"),
        index=True,
    )
    token: Mapped[str] = mapped_column(String(160), unique=True, index=True)
    code: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    mode: Mapped[str] = mapped_column(String(30), default="copy")
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    max_uses: Mapped[int] = mapped_column(Integer, default=10)
    used_count: Mapped[int] = mapped_column(Integer, default=0)
    include_observations: Mapped[bool] = mapped_column(Boolean, default=False)
    include_only_ready_maps: Mapped[bool] = mapped_column(Boolean, default=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    project = relationship("Project")
    owner = relationship("User", foreign_keys=[owner_user_id])


class ProjectShareRedemption(Base):
    __tablename__ = "project_share_redemptions"

    id: Mapped[str] = mapped_column(
        String(64),
        primary_key=True,
        default=lambda: new_id("redemption"),
    )
    share_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("project_shares.id", ondelete="CASCADE"),
        index=True,
    )
    accepted_by_user_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("users.id"),
        index=True,
    )
    accepted_by_company_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("companies.id"),
        index=True,
    )
    created_project_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("projects.id"),
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    share = relationship("ProjectShare")

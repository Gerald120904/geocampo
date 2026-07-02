from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship, validates

from app.core.statuses import assert_job_status
from app.core.database import Base
from app.core.ids import new_id
from app.models.base import TimestampMixin


class ProcessingJob(TimestampMixin, Base):
    __tablename__ = "processing_jobs"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=lambda: new_id("job"))
    map_project_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("map_projects.id", ondelete="CASCADE"), index=True
    )
    status: Mapped[str] = mapped_column(String(30), default="pending", index=True)
    step: Mapped[str] = mapped_column(String(100), default="Archivo recibido")
    progress: Mapped[int] = mapped_column(Integer, default=0)
    error_message: Mapped[str | None] = mapped_column(Text)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    map_project = relationship("MapProject", back_populates="jobs")

    @validates("status")
    def validate_status(self, _: str, status: str) -> str:
        return assert_job_status(status)

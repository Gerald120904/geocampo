from datetime import UTC, datetime

from sqlalchemy import DateTime, Float, ForeignKey, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.ids import new_id


class FieldObservation(Base):
    __tablename__ = "field_observations"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=lambda: new_id("observation"))
    map_project_id: Mapped[str] = mapped_column(String(64), ForeignKey("map_projects.id"), index=True)
    user_id: Mapped[str] = mapped_column(String(64), ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str | None] = mapped_column(Text)
    observation_type: Mapped[str | None] = mapped_column(String(100))
    lat: Mapped[float] = mapped_column(Float)
    lng: Mapped[float] = mapped_column(Float)
    accuracy: Mapped[float | None] = mapped_column(Float)
    photo_path: Mapped[str | None] = mapped_column(Text)
    properties: Mapped[dict | None] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


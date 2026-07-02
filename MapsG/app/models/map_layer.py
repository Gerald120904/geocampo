from datetime import UTC, datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.ids import new_id


class MapLayer(Base):
    __tablename__ = "map_layers"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=lambda: new_id("layer"))
    map_project_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("map_projects.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(200))
    layer_key: Mapped[str] = mapped_column(String(150))
    layer_type: Mapped[str] = mapped_column(String(30))
    geometry_type: Mapped[str | None] = mapped_column(String(50))
    file_path: Mapped[str] = mapped_column(Text)
    visible_default: Mapped[bool] = mapped_column(Boolean, default=True)
    opacity_default: Mapped[float] = mapped_column(Float, default=1.0)
    properties_schema: Mapped[dict | None] = mapped_column(JSON)
    feature_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))

    map_project = relationship("MapProject", back_populates="layers")


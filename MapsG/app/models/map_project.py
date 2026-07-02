from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Float, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship, validates
from geoalchemy2 import Geometry

from app.core.config import settings
from app.core.statuses import assert_map_status
from app.core.database import Base
from app.core.ids import new_id
from app.models.base import TimestampMixin


def _geometry_column() -> object:
    if settings.DATABASE_URL.startswith("sqlite"):
        return Text
    return Geometry(geometry_type="POLYGON", srid=4326)


class MapProject(TimestampMixin, Base):
    __tablename__ = "map_projects"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=lambda: new_id("map"))
    project_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("projects.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(200))
    description: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(30), default="uploaded", index=True)
    source_type: Mapped[str] = mapped_column(String(30))
    original_file_path: Mapped[str] = mapped_column(Text)
    processed_folder_path: Mapped[str | None] = mapped_column(Text)
    package_file_path: Mapped[str | None] = mapped_column(Text)
    preview_file_path: Mapped[str | None] = mapped_column(Text)
    quick_view_file_path: Mapped[str | None] = mapped_column(Text)
    quick_view_created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    quick_mbtiles_file_path: Mapped[str | None] = mapped_column(Text)
    quick_min_zoom: Mapped[int | None] = mapped_column(Integer)
    quick_max_zoom: Mapped[int | None] = mapped_column(Integer)
    quick_default_zoom: Mapped[int | None] = mapped_column(Integer)
    quick_created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    raw_view_ready_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    raw_bounds_geometry: Mapped[dict | None] = mapped_column(JSON)
    raw_center_lat: Mapped[float | None] = mapped_column(Float)
    raw_center_lng: Mapped[float | None] = mapped_column(Float)
    raw_pdf_page: Mapped[int | None] = mapped_column(Integer)
    active_view_mode: Mapped[str] = mapped_column(String(30), default="auto")
    bounds_geometry: Mapped[dict | None] = mapped_column(JSON)
    bounds_geom: Mapped[object | None] = mapped_column(_geometry_column())
    footprint_geometry: Mapped[dict | None] = mapped_column(JSON)
    footprint_geom: Mapped[object | None] = mapped_column(_geometry_column())
    georef_metadata: Mapped[dict | None] = mapped_column(JSON)
    raster_width: Mapped[int | None] = mapped_column(Integer)
    raster_height: Mapped[int | None] = mapped_column(Integer)
    georef_method: Mapped[str | None] = mapped_column(String(50))
    pdf_page_count: Mapped[int | None] = mapped_column(Integer)
    pdf_selected_page: Mapped[int | None] = mapped_column(Integer)
    processing_message: Mapped[str | None] = mapped_column(Text)
    center_lat: Mapped[float | None] = mapped_column(Float)
    center_lng: Mapped[float | None] = mapped_column(Float)
    min_zoom: Mapped[int] = mapped_column(default=12)
    max_zoom: Mapped[int] = mapped_column(default=22)
    default_zoom: Mapped[int] = mapped_column(default=16)
    crs_original: Mapped[str | None] = mapped_column(String(100))
    crs_app: Mapped[str] = mapped_column(String(30), default="EPSG:4326")
    file_size_bytes: Mapped[int] = mapped_column(BigInteger)
    package_version: Mapped[str | None] = mapped_column(String(30))
    package_size_bytes: Mapped[int | None] = mapped_column(BigInteger)
    package_checksum_sha256: Mapped[str | None] = mapped_column(String(64))
    package_created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    spatial_fingerprint: Mapped[str | None] = mapped_column(String(120), index=True)
    file_checksum_sha256: Mapped[str | None] = mapped_column(String(64), index=True)
    duplicate_of_map_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("map_projects.id"))
    duplicate_score: Mapped[float | None] = mapped_column(Float)
    duplicate_reason: Mapped[str | None] = mapped_column(String(120))
    replaced_by_map_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("map_projects.id"))
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_by: Mapped[str] = mapped_column(String(64), ForeignKey("users.id"), index=True)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    project = relationship("Project", back_populates="maps")
    creator = relationship("User", back_populates="maps_created")
    files = relationship("MapFile", back_populates="map_project", cascade="all, delete-orphan")
    layers = relationship("MapLayer", back_populates="map_project", cascade="all, delete-orphan")
    jobs = relationship("ProcessingJob", back_populates="map_project", cascade="all, delete-orphan")

    @validates("status")
    def validate_status(self, _: str, status: str) -> str:
        return assert_map_status(status)

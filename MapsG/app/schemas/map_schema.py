from datetime import datetime

from pydantic import BaseModel, ConfigDict


class Bounds(BaseModel):
    min_lat: float
    min_lng: float
    max_lat: float
    max_lng: float


class Center(BaseModel):
    lat: float
    lng: float


class LayerPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    layer_key: str
    layer_type: str
    geometry_type: str | None
    file_path: str
    visible_default: bool
    opacity_default: float
    properties_schema: dict | None
    feature_count: int
    style: dict | None = None
    identify: bool = True


class MapListItem(BaseModel):
    id: str
    name: str
    status: str
    source_type: str
    has_package: bool
    preview_url: str | None
    created_at: datetime
    raw_available: bool = False
    quick_available: bool = False
    optimized_available: bool = False
    can_open: bool = False
    can_optimize: bool = False
    view_mode: str = "none"
    processing_progress: int | None = None
    processing_message: str | None = None


class ViewerMap(BaseModel):
    id: str
    name: str
    status: str
    tile_url: str
    bounds: Bounds | None
    opacity: float = 1.0
    visible: bool = True
    min_zoom: int = 10
    max_zoom: int = 18


class DuplicateCandidatePublic(BaseModel):
    map_id: str
    name: str
    duplicate_type: str
    score: float
    reason: str


class DuplicateReviewResponse(BaseModel):
    map_id: str
    status: str = "duplicate_review"
    message: str
    candidates: list[DuplicateCandidatePublic]


class DuplicateResolveRequest(BaseModel):
    action: str
    existing_map_id: str | None = None


class MapDetail(BaseModel):
    id: str
    project_id: str
    name: str
    description: str | None
    status: str
    source_type: str
    min_zoom: int
    max_zoom: int
    default_zoom: int
    bounds: Bounds | None
    center: Center | None
    layers: list[LayerPublic]
    package_available: bool
    tile_version: str | None = None
    raw_available: bool = False
    quick_available: bool = False
    optimized_available: bool = False
    can_open: bool = False
    can_optimize: bool = False
    view_mode: str = "none"
    overlay_url: str | None = None
    raw_pdf_url: str | None = None
    processing_progress: int | None = None
    processing_message: str | None = None

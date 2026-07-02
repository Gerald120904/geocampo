from pydantic import BaseModel, Field

from app.schemas.common import TimestampedModel
from app.schemas.map_schema import Bounds, Center, MapListItem, ViewerMap


class ProjectCreate(BaseModel):
    company_id: str
    name: str = Field(min_length=2, max_length=200)
    description: str | None = None


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=200)
    description: str | None = None


class ProjectPublic(TimestampedModel):
    id: str
    company_id: str
    name: str
    description: str | None
    maps_count: int = 0
    ready_maps_count: int = 0
    processing_maps_count: int = 0
    failed_maps_count: int = 0


class ProjectDetail(ProjectPublic):
    bounds: Bounds | None = None
    center: Center | None = None
    maps: list[MapListItem] = []


class ProjectViewerProject(BaseModel):
    id: str
    name: str


class ProjectViewer(BaseModel):
    project: ProjectViewerProject
    bounds: Bounds | None = None
    center: Center | None = None
    maps: list[ViewerMap]

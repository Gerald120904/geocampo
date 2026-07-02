from datetime import datetime

from pydantic import BaseModel, Field


class ProjectShareCreate(BaseModel):
    expires_in_days: int = Field(default=7, ge=1, le=90)
    max_uses: int = Field(default=10, ge=1, le=500)
    include_observations: bool = False
    include_only_ready_maps: bool = True


class ProjectShareCreated(BaseModel):
    id: str
    token: str
    code: str
    expires_at: datetime | None
    max_uses: int
    used_count: int


class SharedProjectPreview(BaseModel):
    token: str
    code: str
    project_name: str
    project_description: str | None
    owner_name: str
    maps_count: int
    ready_maps_count: int
    expires_at: datetime | None
    mode: str


class AcceptProjectShareResponse(BaseModel):
    project_id: str
    project_name: str
    imported_maps_count: int
    message: str

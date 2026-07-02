from datetime import datetime

from pydantic import BaseModel, Field


class ObservationCreate(BaseModel):
    map_project_id: str
    title: str = Field(min_length=2, max_length=200)
    description: str | None = None
    observation_type: str | None = None
    lat: float
    lng: float
    accuracy: float | None = None
    properties: dict | None = None


class ObservationUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=200)
    description: str | None = None
    observation_type: str | None = None
    properties: dict | None = None


class ObservationPublic(BaseModel):
    id: str
    map_project_id: str
    user_id: str
    title: str
    description: str | None
    observation_type: str | None
    lat: float
    lng: float
    accuracy: float | None
    photo_path: str | None
    properties: dict | None
    created_at: datetime
    synced_at: datetime | None

    model_config = {"from_attributes": True}

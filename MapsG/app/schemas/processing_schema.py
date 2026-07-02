from pydantic import BaseModel


class ProcessResponse(BaseModel):
    job_id: str
    map_id: str
    status: str


class JobPublic(BaseModel):
    status: str
    step: str
    progress: int
    error_message: str | None


class MapStatusResponse(BaseModel):
    map_id: str
    status: str
    job: JobPublic | None


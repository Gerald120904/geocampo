from pydantic import BaseModel

from app.schemas.map_schema import DuplicateCandidatePublic


class UploadResponse(BaseModel):
    map_id: str
    status: str
    message: str
    candidates: list[DuplicateCandidatePublic] = []

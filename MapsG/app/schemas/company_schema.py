from pydantic import BaseModel, Field

from app.schemas.common import TimestampedModel


class CompanyCreate(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    legal_name: str | None = Field(default=None, max_length=250)
    identifier: str = Field(min_length=2, max_length=100)


class CompanyPublic(TimestampedModel):
    id: str
    name: str
    legal_name: str | None
    identifier: str


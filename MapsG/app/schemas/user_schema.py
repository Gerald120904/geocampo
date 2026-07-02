from pydantic import BaseModel, EmailStr, Field

from app.schemas.common import ORMModel


class UserPublic(ORMModel):
    id: str
    name: str
    email: str
    role: str
    company_id: str | None
    email_verified: bool = False


class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    role: str = Field(pattern="^(company_admin|technician|viewer)$")
    company_id: str


class UserUpdateMe(BaseModel):
    name: str = Field(min_length=2, max_length=200)


class UserListResponse(BaseModel):
    items: list[UserPublic]
    total: int
    limit: int
    offset: int
    has_more: bool

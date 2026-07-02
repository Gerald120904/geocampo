from datetime import datetime

from pydantic import BaseModel


class PackageInfo(BaseModel):
    map_id: str
    available: bool
    filename: str | None
    size_bytes: int | None
    checksum_sha256: str | None
    package_version: str | None
    created_at: datetime | None

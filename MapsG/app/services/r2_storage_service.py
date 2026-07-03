from pathlib import Path

import boto3
from botocore.client import Config

from app.core.config import settings


class R2StorageService:
    def __init__(self) -> None:
        if not settings.R2_BUCKET:
            raise RuntimeError("R2_BUCKET no esta configurado")

        self.bucket = settings.R2_BUCKET
        self.client = boto3.client(
            "s3",
            endpoint_url=settings.R2_ENDPOINT,
            aws_access_key_id=settings.R2_ACCESS_KEY_ID,
            aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
            region_name=settings.R2_REGION or "auto",
            config=Config(signature_version="s3v4"),
        )

    def upload_file(self, local_path: Path, key: str, content_type: str | None = None) -> str:
        extra_args = {}
        if content_type:
            extra_args["ContentType"] = content_type

        self.client.upload_file(
            str(local_path),
            self.bucket,
            key,
            ExtraArgs=extra_args or None,
        )
        return key

    def download_file(self, key: str, local_path: Path) -> Path:
        local_path.parent.mkdir(parents=True, exist_ok=True)
        self.client.download_file(self.bucket, key, str(local_path))
        return local_path

    def presigned_get_url(self, key: str, expires_seconds: int = 3600) -> str:
        return self.client.generate_presigned_url(
            "get_object",
            Params={"Bucket": self.bucket, "Key": key},
            ExpiresIn=expires_seconds,
        )

    def presigned_put_url(
        self,
        key: str,
        content_type: str,
        expires_seconds: int = 3600,
    ) -> str:
        return self.client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": self.bucket,
                "Key": key,
                "ContentType": content_type,
            },
            ExpiresIn=expires_seconds,
        )


def is_r2_enabled() -> bool:
    return settings.STORAGE_BACKEND.lower() == "r2"


def _with_prefix(prefix: str, value: str) -> str:
    clean_value = str(value).strip("/\\")
    expected_prefix = f"{prefix}_"
    if clean_value.startswith(expected_prefix):
        return clean_value
    return f"{expected_prefix}{clean_value}"


def _clean_key_part(value: str) -> str:
    return str(value).strip("/\\")


def r2_key_for_map_file(
    kind: str,
    company_id: str,
    project_id: str,
    map_id: str,
    filename: str,
) -> str:
    return (
        f"{_clean_key_part(kind)}/"
        f"{_with_prefix('company', company_id)}/"
        f"{_with_prefix('project', project_id)}/"
        f"{_with_prefix('map', map_id)}/"
        f"{_clean_key_part(filename)}"
    )

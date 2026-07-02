from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import ProcessingJob


def latest_for_map(db: Session, map_id: str) -> ProcessingJob | None:
    return db.scalar(
        select(ProcessingJob)
        .where(ProcessingJob.map_project_id == map_id)
        .order_by(ProcessingJob.created_at.desc())
        .limit(1)
    )


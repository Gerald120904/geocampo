from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models import MapProject


def get_map(db: Session, map_id: str) -> MapProject | None:
    return db.scalar(
        select(MapProject)
        .where(MapProject.id == map_id)
        .options(selectinload(MapProject.layers), selectinload(MapProject.jobs))
    )


def list_for_project(db: Session, project_id: str) -> list[MapProject]:
    return list(
        db.scalars(
            select(MapProject)
            .where(
                MapProject.project_id == project_id,
                MapProject.status.notin_(("deleted", "archived", "replaced")),
            )
            .order_by(MapProject.created_at.desc())
        )
    )

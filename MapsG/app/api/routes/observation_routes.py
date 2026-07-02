from datetime import UTC, datetime
from pathlib import Path
import shutil

from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.exceptions import GeoCampoError
from app.models import FieldObservation, User
from app.schemas.common import Message
from app.schemas.observation_schema import ObservationCreate, ObservationPublic, ObservationUpdate
from app.services.access_service import get_map_for_user
from app.services.auth_service import get_current_user, require_roles
from app.services.storage_service import make_directory, permanent_key, slugify, upload_permanent_file

router = APIRouter(prefix="/observations", tags=["observations"])


@router.post("", response_model=ObservationPublic, status_code=201)
def create_observation(
    payload: ObservationCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin", "technician")),
) -> FieldObservation:
    get_map_for_user(db, payload.map_project_id, user)
    observation = FieldObservation(
        map_project_id=payload.map_project_id,
        user_id=user.id,
        title=payload.title,
        description=payload.description,
        observation_type=payload.observation_type,
        lat=payload.lat,
        lng=payload.lng,
        accuracy=payload.accuracy,
        properties=payload.properties,
        synced_at=datetime.now(UTC),
    )
    db.add(observation)
    db.commit()
    db.refresh(observation)
    return observation


@router.get("/map/{map_id}", response_model=list[ObservationPublic])
def list_observations_for_map(
    map_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[FieldObservation]:
    get_map_for_user(db, map_id, user)
    return list(
        db.scalars(
            select(FieldObservation)
            .where(FieldObservation.map_project_id == map_id)
            .order_by(FieldObservation.created_at.desc())
        )
    )


@router.get("/{observation_id}", response_model=ObservationPublic)
def get_observation(
    observation_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> FieldObservation:
    observation = db.get(FieldObservation, observation_id)
    if not observation:
        raise GeoCampoError("OBSERVATION_NOT_FOUND", "Observación no encontrada.", 404)
    map_project = get_map_for_user(db, observation.map_project_id, user)
    return observation


@router.put("/{observation_id}", response_model=ObservationPublic)
def update_observation(
    observation_id: str,
    payload: ObservationUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin", "technician")),
) -> FieldObservation:
    observation = db.get(FieldObservation, observation_id)
    if not observation:
        raise GeoCampoError("OBSERVATION_NOT_FOUND", "Observación no encontrada.", 404)
    map_project = get_map_for_user(db, observation.map_project_id, user)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(observation, key, value)
    observation.synced_at = datetime.now(UTC)
    db.commit()
    db.refresh(observation)
    return observation


@router.delete("/{observation_id}", response_model=Message)
def delete_observation(
    observation_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin", "technician")),
) -> Message:
    observation = db.get(FieldObservation, observation_id)
    if not observation:
        raise GeoCampoError("OBSERVATION_NOT_FOUND", "Observación no encontrada.", 404)
    get_map_for_user(db, observation.map_project_id, user)
    db.delete(observation)
    db.commit()
    return Message(message="Observación eliminada correctamente")


@router.post("/{observation_id}/photo", response_model=ObservationPublic)
async def upload_observation_photo(
    observation_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("super_admin", "company_admin", "technician")),
) -> FieldObservation:
    observation = db.get(FieldObservation, observation_id)
    if not observation:
        raise GeoCampoError("OBSERVATION_NOT_FOUND", "Observación no encontrada.", 404)
    get_map_for_user(db, observation.map_project_id, user)
    extension = Path(file.filename or "").suffix.lower()
    if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise GeoCampoError("INVALID_PHOTO_TYPE", "La foto debe ser JPG, PNG o WEBP.", 400)
    directory = make_directory(settings.OBSERVATION_PHOTOS_PATH, observation.map_project_id, observation.id)
    destination = directory / f"{observation.id}_{slugify(Path(file.filename or 'photo').stem)}{extension}"
    with destination.open("wb") as output:
        shutil.copyfileobj(file.file, output)
    observation.photo_path = upload_permanent_file(
        destination,
        permanent_key(
            "photos",
            map_project.project.company_id,
            map_project.project_id,
            observation.id,
            destination.name,
        ),
        content_type=file.content_type,
    )
    observation.synced_at = datetime.now(UTC)
    db.commit()
    db.refresh(observation)
    return observation

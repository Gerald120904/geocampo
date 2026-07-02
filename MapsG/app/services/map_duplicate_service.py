from dataclasses import dataclass
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import MapProject
from app.services.package_service import file_sha256

IGNORED_DUPLICATE_STATUSES = {"deleted", "replaced"}


@dataclass(frozen=True)
class DuplicateCandidate:
    map_id: str
    name: str
    duplicate_type: str
    score: float
    reason: str


def checksum_for_path(path_value: str | None) -> str | None:
    if not path_value:
        return None
    path = Path(path_value)
    return file_sha256(path) if path.is_file() else None


def spatial_fingerprint(bounds: dict | None, crs: str | None = None) -> str | None:
    if not bounds:
        return None
    try:
        min_lat = round(float(bounds["min_lat"]), 5)
        min_lng = round(float(bounds["min_lng"]), 5)
        max_lat = round(float(bounds["max_lat"]), 5)
        max_lng = round(float(bounds["max_lng"]), 5)
    except (KeyError, TypeError, ValueError):
        return None
    return f"{crs or 'EPSG:4326'}:{min_lat}:{min_lng}:{max_lat}:{max_lng}"


def find_duplicates(db: Session, map_project: MapProject) -> list[DuplicateCandidate]:
    statement = (
        select(MapProject)
        .where(
            MapProject.project_id == map_project.project_id,
            MapProject.id != map_project.id,
            MapProject.status.notin_(IGNORED_DUPLICATE_STATUSES),
        )
        .order_by(MapProject.created_at.desc())
    )
    candidates: list[DuplicateCandidate] = []
    for existing in db.scalars(statement):
        exact = _exact_file_candidate(map_project, existing)
        if exact:
            candidates.append(exact)
            continue

        fingerprint = _fingerprint_candidate(map_project, existing)
        if fingerprint:
            candidates.append(fingerprint)
            continue

        overlap = _overlap_candidate(map_project, existing)
        if overlap:
            candidates.append(overlap)

    return sorted(candidates, key=lambda item: item.score, reverse=True)


def apply_duplicate_metadata(map_project: MapProject, candidate: DuplicateCandidate | None) -> None:
    if not candidate:
        map_project.duplicate_of_map_id = None
        map_project.duplicate_score = None
        map_project.duplicate_reason = None
        return
    map_project.duplicate_of_map_id = candidate.map_id
    map_project.duplicate_score = candidate.score
    map_project.duplicate_reason = candidate.duplicate_type


def _exact_file_candidate(new: MapProject, existing: MapProject) -> DuplicateCandidate | None:
    if not new.file_checksum_sha256 or new.file_checksum_sha256 != existing.file_checksum_sha256:
        return None
    return DuplicateCandidate(
        map_id=existing.id,
        name=existing.name,
        duplicate_type="exact_file",
        score=100,
        reason="mismo archivo",
    )


def _fingerprint_candidate(new: MapProject, existing: MapProject) -> DuplicateCandidate | None:
    if not new.spatial_fingerprint or new.spatial_fingerprint != existing.spatial_fingerprint:
        return None
    return DuplicateCandidate(
        map_id=existing.id,
        name=existing.name,
        duplicate_type="same_spatial_fingerprint",
        score=98,
        reason="misma ubicacion geografica",
    )


def _overlap_candidate(new: MapProject, existing: MapProject) -> DuplicateCandidate | None:
    overlap = _bounds_overlap_ratio(new.bounds_geometry, existing.bounds_geometry)
    if overlap < 0.30:
        return None
    score = round(overlap * 100, 2)
    duplicate_type = "high_overlap" if overlap >= 0.95 else "partial_overlap"
    reason = "alto traslape geografico" if overlap >= 0.95 else "traslape parcial"
    return DuplicateCandidate(
        map_id=existing.id,
        name=existing.name,
        duplicate_type=duplicate_type,
        score=score,
        reason=reason,
    )


def _bounds_overlap_ratio(a: dict | None, b: dict | None) -> float:
    if not a or not b:
        return 0
    try:
        left = max(float(a["min_lng"]), float(b["min_lng"]))
        right = min(float(a["max_lng"]), float(b["max_lng"]))
        bottom = max(float(a["min_lat"]), float(b["min_lat"]))
        top = min(float(a["max_lat"]), float(b["max_lat"]))
        if right <= left or top <= bottom:
            return 0
        intersection = (right - left) * (top - bottom)
        area_a = (float(a["max_lng"]) - float(a["min_lng"])) * (
            float(a["max_lat"]) - float(a["min_lat"])
        )
        area_b = (float(b["max_lng"]) - float(b["min_lng"])) * (
            float(b["max_lat"]) - float(b["min_lat"])
        )
        smaller = min(area_a, area_b)
        return intersection / smaller if smaller > 0 else 0
    except (KeyError, TypeError, ValueError):
        return 0

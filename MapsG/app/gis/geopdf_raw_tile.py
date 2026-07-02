from pathlib import Path
from threading import Lock

from PIL import Image

from app.core.config import settings
from app.core.exceptions import GeoCampoError
from app.core.storage import safe_resolve
from app.gis.geopdf_inspector import inspect_geopdf_measure
from app.gis.geopdf_mbtiles import (
    _control_points,
    _render_tile,
    _tile_corner,
)
from app.gis.pdf_renderer import render_pdf_page_to_png
from app.models import MapProject
from app.services.storage_service import is_r2_uri, materialize_file, r2_key

_render_locks: dict[str, Lock] = {}
_tile_locks: dict[str, Lock] = {}
_locks_guard = Lock()


def get_or_create_raw_pdf_tile(
    map_project: MapProject,
    z: int,
    x: int,
    y: int,
) -> Path:
    package_root = _package_root(map_project)
    tile_dir = package_root / "raw_tiles" / str(z) / str(x)
    tile_dir.mkdir(parents=True, exist_ok=True)
    tile_path = tile_dir / f"{y}.png"
    if tile_path.is_file():
        return tile_path

    with _lock_for(_tile_locks, str(tile_path)):
        if tile_path.is_file():
            return tile_path
        source = materialize_file(map_project.original_file_path)
        if not source:
            raise GeoCampoError("RAW_PDF_NOT_FOUND", "No se encontro el PDF original.", 404)
        render_raw_pdf_tile(
            source=source,
            output=tile_path,
            map_project=map_project,
            z=z,
            x=x,
            y=y,
        )
    return tile_path


def get_or_create_raw_pdf_preview(map_project: MapProject) -> Path:
    package_root = _package_root(map_project)
    preview_path = package_root / "raw_preview.png"
    if preview_path.is_file():
        return preview_path

    with _lock_for(_tile_locks, str(preview_path)):
        if preview_path.is_file():
            return preview_path
        source = materialize_file(map_project.original_file_path)
        if not source or not source.is_file():
            raise GeoCampoError("RAW_PDF_NOT_FOUND", "No se encontro el PDF original.", 404)
        rendered = _get_or_create_rendered_page(source, package_root, map_project)
        with Image.open(rendered) as opened:
            image = opened.convert("RGB")
            image.thumbnail((900, 520), Image.Resampling.LANCZOS)
            preview_path.parent.mkdir(parents=True, exist_ok=True)
            image.save(preview_path, format="PNG", compress_level=4)
    return preview_path


def render_raw_pdf_tile(
    *,
    source: Path,
    output: Path,
    map_project: MapProject,
    z: int,
    x: int,
    y: int,
) -> None:
    if z < 0 or x < 0 or y < 0 or x >= (1 << z) or y >= (1 << z):
        raise GeoCampoError("INVALID_TILE", "Coordenadas de tile invalidas.", 422)

    if not source.is_file():
        raise GeoCampoError("RAW_PDF_NOT_FOUND", "No se encontro el PDF original.", 404)

    package_root = _package_root(map_project)
    inspection = _inspection_for(map_project, source)
    if not _tile_intersects_bounds(inspection["bounds"], z, x, y):
        output.parent.mkdir(parents=True, exist_ok=True)
        _write_transparent_tile(output)
        return

    rendered = _get_or_create_rendered_page(source, package_root, map_project)

    with Image.open(rendered) as opened:
        image = opened.convert("RGBA")
        control = _control_points(inspection, image.width, image.height)
        payload = _render_tile(
            image,
            control,
            x,
            y,
            z,
            make_white_transparent=False,
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    if payload is None:
        _write_transparent_tile(output)
    else:
        output.write_bytes(payload)


def _package_root(map_project: MapProject) -> Path:
    if map_project.processed_folder_path:
        if is_r2_uri(map_project.processed_folder_path):
            root = safe_resolve(settings.TEMP_PATH, "r2_work", r2_key(map_project.processed_folder_path))
        else:
            root = Path(map_project.processed_folder_path)
    else:
        root = (
            Path(settings.PROCESSED_FILES_PATH)
            / map_project.project.company_id
            / map_project.project_id
            / map_project.id
        )
    root.mkdir(parents=True, exist_ok=True)
    return root


def _get_or_create_rendered_page(source: Path, package_root: Path, map_project: MapProject) -> Path:
    rendered = package_root / "raw_render.png"
    if rendered.is_file():
        return rendered
    with _lock_for(_render_locks, str(rendered)):
        if rendered.is_file():
            return rendered
        rendered.parent.mkdir(parents=True, exist_ok=True)
        page_index = max(0, int(map_project.raw_pdf_page or map_project.pdf_selected_page or 1) - 1)
        return render_pdf_page_to_png(
            source,
            rendered,
            page_index=page_index,
            zoom=max(float(settings.GEOPDF_RENDER_ZOOM), 3.0),
        )


def _inspection_for(map_project: MapProject, source: Path) -> dict:
    metadata = map_project.georef_metadata or {}
    bounds = map_project.raw_bounds_geometry or map_project.bounds_geometry
    if not metadata or not bounds or not metadata.get("control_points"):
        return inspect_geopdf_measure(source)

    return {
        "bounds": bounds,
        "center": {
            "lat": map_project.raw_center_lat or map_project.center_lat,
            "lng": map_project.raw_center_lng or map_project.center_lng,
        },
        "selected_page": map_project.raw_pdf_page or map_project.pdf_selected_page or 1,
        "page_count": map_project.pdf_page_count or 1,
        "page_width": metadata.get("page_width") or metadata.get("width"),
        "page_height": metadata.get("page_height") or metadata.get("height"),
        "viewport_bbox": metadata.get("viewport_bbox"),
        "control_points": metadata["control_points"],
        "georef_method": metadata.get("method") or map_project.georef_method or "unknown",
    }


def _write_transparent_tile(path: Path) -> None:
    tile = Image.new("RGBA", (256, 256), (255, 255, 255, 0))
    tile.save(path, format="PNG", compress_level=3)


def _tile_intersects_bounds(bounds: dict[str, float], z: int, x: int, y: int) -> bool:
    west, north = _tile_corner(x, y, z, 0, 0)
    east, south = _tile_corner(x, y, z, 1, 1)
    return not (
        east < bounds["min_lng"]
        or west > bounds["max_lng"]
        or north < bounds["min_lat"]
        or south > bounds["max_lat"]
    )


def _lock_for(registry: dict[str, Lock], key: str) -> Lock:
    with _locks_guard:
        lock = registry.get(key)
        if lock is None:
            lock = Lock()
            registry[key] = lock
        return lock

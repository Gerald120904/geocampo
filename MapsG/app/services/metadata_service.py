from datetime import UTC, datetime
from pathlib import Path

from app.models import MapProject


def build_metadata(
    map_project: MapProject,
    layers: list[dict],
    bounds: dict[str, float],
    files: dict[str, str],
) -> dict:
    center = {
        "lat": (bounds["min_lat"] + bounds["max_lat"]) / 2,
        "lng": (bounds["min_lng"] + bounds["max_lng"]) / 2,
    }
    georeference = map_project.georef_metadata or {}
    project = map_project.project
    return {
        "schema_version": "1.0.0",
        "version": "1.0.0",
        "package_id": f"pkg_{map_project.id}",
        "package_type": "geocampo_offline_map",
        "package_version": "1.0.0",
        "package_checksum_sha256": map_project.package_checksum_sha256,
        "package_size_bytes": map_project.package_size_bytes,
        "app_min_version": "1.0.0",
        "map_id": map_project.id,
        "project_id": map_project.project_id,
        "project_name": project.name if project else None,
        "name": map_project.name,
        "description": map_project.description,
        "source_type": map_project.source_type,
        "display_type": "raster_mbtiles" if "raster" in files else "vector_layers",
        "created_at": map_project.created_at.isoformat(),
        "processed_at": datetime.now(UTC).isoformat(),
        "offline": True,
        "generated_by": "GeoCampo Backend",
        "crs_original": map_project.crs_original,
        "crs_app": "EPSG:4326",
        "tile_crs": "EPSG:3857" if "raster" in files else None,
        "tile_file": files.get("raster"),
        "preview_file": files.get("preview"),
        "tile_format": "mbtiles" if "raster" in files else None,
        "has_raster": "raster" in files,
        "has_vector_layers": bool(layers),
        "identify_layers": [layer["id"] for layer in layers if layer.get("identify", True)],
        "bounds": bounds,
        "center": center,
        "zoom": {
            "min": map_project.min_zoom,
            "max": map_project.max_zoom,
            "default": map_project.default_zoom,
        },
        "footprint": map_project.footprint_geometry,
        "georeference": {
            "method": georeference.get("method"),
            "width": georeference.get("width"),
            "height": georeference.get("height"),
            "control_points": georeference.get("control_points", []),
        },
        "files": files,
        "layers": layers,
        "legend": files.get("legend"),
    }


def metadata_layer(layer, package_root: Path) -> dict:
    style = _default_style(layer.layer_type)
    return {
        "id": layer.key,
        "name": layer.name,
        "type": layer.layer_type,
        "geometry_type": layer.geometry_type,
        "file": layer.path.relative_to(package_root).as_posix(),
        "visible": True,
        "opacity": 1.0,
        "identify": True,
        "label_field": _guess_label_field(layer.properties_schema),
        "priority": 10,
        "style": style,
        "properties_schema": layer.properties_schema,
        "feature_count": layer.feature_count,
    }


def _guess_label_field(properties_schema: dict | None) -> str | None:
    if not properties_schema:
        return None
    candidates = ("nombre", "name", "lote", "id", "codigo", "code")
    keys = set(properties_schema.keys())
    for candidate in candidates:
        if candidate in keys:
            return candidate
    return next(iter(properties_schema.keys()), None)


def _default_style(layer_type: str) -> dict[str, object]:
    if layer_type == "polygon":
        return {"fill_color": "#43A047", "stroke_color": "#1B5E20", "stroke_width": 2}
    if layer_type == "line":
        return {"stroke_color": "#795548", "stroke_width": 2}
    if layer_type == "point":
        return {"marker_color": "#1976D2", "marker_size": 8}
    return {"color": "#1976D2"}

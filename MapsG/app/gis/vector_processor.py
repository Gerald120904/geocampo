from dataclasses import dataclass
from pathlib import Path

import geopandas as gpd

from app.gis.bounds import bounds_dict
from app.gis.validation import validate_geodataframe
from app.services.storage_service import slugify


@dataclass
class ProcessedLayer:
    name: str
    key: str
    layer_type: str
    geometry_type: str
    path: Path
    feature_count: int
    properties_schema: dict[str, str]
    bounds: dict[str, float]


def geometry_category(geometry_type: str) -> str:
    lowered = geometry_type.lower()
    if "polygon" in lowered:
        return "polygon"
    if "line" in lowered:
        return "line"
    if "point" in lowered:
        return "point"
    return "vector"


def export_frame(frame: gpd.GeoDataFrame, name: str, output_dir: Path) -> tuple[ProcessedLayer, str]:
    validate_geodataframe(frame, name)
    assert frame.crs is not None
    original_crs = frame.crs.to_string()
    frame = frame.to_crs(epsg=4326)
    key = slugify(name, "layer")
    destination = output_dir / f"{key}.geojson"
    frame.to_file(destination, driver="GeoJSON")
    geometry_types = sorted({str(value) for value in frame.geometry.geom_type.dropna().unique()})
    geometry_type = geometry_types[0] if len(geometry_types) == 1 else "GeometryCollection"
    schema = {column: str(dtype) for column, dtype in frame.drop(columns=frame.geometry.name).dtypes.items()}
    return (
        ProcessedLayer(
            name=name,
            key=key,
            layer_type=geometry_category(geometry_type),
            geometry_type=geometry_type,
            path=destination,
            feature_count=len(frame),
            properties_schema=schema,
            bounds=bounds_dict(frame.total_bounds),
        ),
        original_crs,
    )

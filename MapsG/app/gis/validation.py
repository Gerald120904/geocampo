from pathlib import Path

import geopandas as gpd

from app.core.exceptions import GeoCampoError


def validate_geodataframe(frame: gpd.GeoDataFrame, source_name: str) -> None:
    if frame.empty:
        raise GeoCampoError("EMPTY_LAYER", f"La capa {source_name} no contiene elementos.")
    if frame.geometry.isna().all():
        raise GeoCampoError("INVALID_GEOMETRY", f"La capa {source_name} no contiene geometrías.")
    if frame.crs is None:
        raise GeoCampoError("MAP_WITHOUT_GEOREFERENCE", f"La capa {source_name} no tiene CRS.")
    invalid = ~frame.geometry.is_valid
    if invalid.any():
        frame.loc[invalid, "geometry"] = frame.loc[invalid, "geometry"].make_valid()


def ensure_required_shapefile_parts(shp_path: Path) -> None:
    sibling_suffixes = {
        path.suffix.lower()
        for path in shp_path.parent.iterdir()
        if path.is_file() and path.stem.lower() == shp_path.stem.lower()
    }
    missing = [suffix for suffix in (".shp", ".shx", ".dbf", ".prj") if suffix not in sibling_suffixes]
    if missing:
        raise GeoCampoError(
            "INCOMPLETE_SHAPEFILE",
            f"Faltan archivos obligatorios del Shapefile: {', '.join(missing)}.",
        )

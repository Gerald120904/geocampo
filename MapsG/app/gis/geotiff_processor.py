from pathlib import Path

from app.gis.raster_processor import raster_bounds_wgs84, raster_to_mbtiles


def process_geotiff(
    source: Path,
    package_root: Path,
    temp_dir: Path,
    bounds: dict[str, float] | None = None,
    crs: str | None = None,
) -> tuple[Path, dict[str, float], str]:
    if bounds is None or crs is None:
        bounds, crs = raster_bounds_wgs84(source)
    mbtiles = raster_to_mbtiles(source, package_root, temp_dir)
    return mbtiles, bounds, crs

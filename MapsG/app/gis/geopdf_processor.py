from pathlib import Path

from app.core.config import settings
from app.gis.geopdf_fallback_processor import process_geopdf_fallback_to_mbtiles
from app.gis.geopdf_inspector import inspect_geopdf_measure
from app.gis.geopdf_mbtiles import ProgressCallback
from app.gis.raster_processor import raster_to_mbtiles


def process_geopdf(
    source: Path,
    package_root: Path,
    temp_dir: Path,
    inspection: dict | None = None,
    on_tiles_progress: ProgressCallback | None = None,
) -> tuple[Path, dict[str, float], str, dict]:
    inspection = inspection or inspect_geopdf_measure(source)
    if settings.GEOPDF_FAST_MODE:
        mbtiles = process_geopdf_fallback_to_mbtiles(
            source=source,
            package_root=package_root,
            temp_dir=temp_dir,
            inspection=inspection,
            on_progress=on_tiles_progress,
        )
        return mbtiles, inspection["bounds"], "EPSG:4326", inspection

    try:
        mbtiles = raster_to_mbtiles(source, package_root, temp_dir)
    except Exception:
        mbtiles = process_geopdf_fallback_to_mbtiles(
            source=source,
            package_root=package_root,
            temp_dir=temp_dir,
            inspection=inspection,
            on_progress=on_tiles_progress,
        )

    return mbtiles, inspection["bounds"], "EPSG:4326", inspection

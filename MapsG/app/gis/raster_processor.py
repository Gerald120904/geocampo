from pathlib import Path

import rasterio
from rasterio.warp import transform_bounds

from app.core.config import settings
from app.core.exceptions import GeoCampoError
from app.gis.gdal_cli import run_gdal


def raster_bounds_wgs84(source: Path) -> tuple[dict[str, float], str]:
    try:
        with rasterio.open(source) as dataset:
            if not dataset.crs:
                raise GeoCampoError("RASTER_WITHOUT_CRS", "El raster no tiene CRS/georreferencia.")
            raw_bounds = transform_bounds(dataset.crs, "EPSG:4326", *dataset.bounds, densify_pts=21)
            crs = dataset.crs.to_string()
    except GeoCampoError:
        raise
    except Exception as exc:
        raise GeoCampoError("INVALID_RASTER", "No fue posible leer la georreferencia del raster.") from exc

    min_lng, min_lat, max_lng, max_lat = raw_bounds
    if min_lng >= max_lng or min_lat >= max_lat:
        raise GeoCampoError("INVALID_RASTER_BOUNDS", "Los bounds del raster no son válidos.")
    return (
        {
            "min_lat": float(min_lat),
            "min_lng": float(min_lng),
            "max_lat": float(max_lat),
            "max_lng": float(max_lng),
        },
        crs,
    )


def raster_to_mbtiles(source: Path, package_root: Path, temp_dir: Path) -> Path:
    translated = temp_dir / f"{source.stem}_source.tif"
    warped = temp_dir / f"{source.stem}_epsg3857.tif"
    destination = package_root / "map.mbtiles"

    run_gdal(
        [
            "gdal_translate",
            "-of",
            "GTiff",
            "-co",
            "TILED=YES",
            "-co",
            "COMPRESS=DEFLATE",
            str(source),
            str(translated),
        ],
        "No fue posible preparar el raster temporal.",
    )
    run_gdal(
        [
            "gdalwarp",
            "-t_srs",
            "EPSG:3857",
            "-r",
            settings.RASTER_RESAMPLING,
            "-of",
            "GTiff",
            "-co",
            "TILED=YES",
            "-co",
            "COMPRESS=DEFLATE",
            "-co",
            "BIGTIFF=IF_SAFER",
            str(translated),
            str(warped),
        ],
        "No fue posible reproyectar el raster a EPSG:3857.",
    )
    run_gdal(
        [
            "gdal_translate",
            "-of",
            "MBTILES",
            "-co",
            f"TILE_FORMAT={settings.RASTER_TILE_FORMAT.upper()}",
            "-co",
            f"MINZOOM={settings.RASTER_MIN_ZOOM}",
            "-co",
            f"MAXZOOM={settings.RASTER_MAX_ZOOM}",
            str(warped),
            str(destination),
        ],
        "No fue posible generar map.mbtiles desde el raster.",
        error_code="TILE_GENERATION_FAILED",
    )
    if settings.RASTER_OVERVIEWS:
        run_gdal(
            ["gdaladdo", "-r", "nearest", str(destination), "2", "4", "8", "16"],
            "No fue posible generar overviews del MBTiles.",
            error_code="TILE_GENERATION_FAILED",
        )
    if not destination.is_file() or destination.stat().st_size == 0:
        raise GeoCampoError("MBTILES_NOT_CREATED", "GDAL no generó un MBTiles válido.")
    return destination

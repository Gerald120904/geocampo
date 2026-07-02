import sqlite3
from pathlib import Path

from PIL import Image

from app.core.config import settings
from app.core.exceptions import GeoCampoError
from app.gis.gdal_cli import run_gdal
from app.gis.geopdf_mbtiles import (
    ProgressCallback,
    clean_geopdf_render_file,
    process_geopdf_to_mbtiles_pure_python,
)
from app.gis.pdf_renderer import render_pdf_page_to_png


def process_geopdf_fallback_to_mbtiles(
    source: Path,
    package_root: Path,
    temp_dir: Path,
    inspection: dict,
    on_progress: ProgressCallback | None = None,
) -> Path:
    try:
        return _process_with_gdal(source, package_root, temp_dir, inspection)
    except GeoCampoError as exc:
        if exc.code not in {
            "GDAL_NOT_AVAILABLE",
            "GDAL_PROCESSING_FAILED",
            "TILE_GENERATION_FAILED",
            "MBTILES_NOT_CREATED",
        }:
            raise

    mbtiles, zoom = process_geopdf_to_mbtiles_pure_python(
        source=source,
        package_root=package_root,
        temp_dir=temp_dir,
        inspection=inspection,
        on_progress=on_progress,
    )
    inspection["tile_zoom"] = zoom
    return mbtiles


def _process_with_gdal(source: Path, package_root: Path, temp_dir: Path, inspection: dict) -> Path:
    rendered = render_pdf_page_to_png(
        source,
        temp_dir / "geopdf_rendered.png",
        page_index=inspection["selected_page"] - 1,
        zoom=settings.GEOPDF_RENDER_ZOOM,
    )
    if settings.GEOPDF_CLEAN_RENDER:
        clean_geopdf_render_file(rendered)
    raw_geotiff = temp_dir / "geopdf_georef_raw.tif"
    warped = temp_dir / "geopdf_warped_3857.tif"
    destination = package_root / "map.mbtiles"

    width, height = _image_size(rendered)
    translate_command = [
        "gdal_translate",
        "-of",
        "GTiff",
        "-a_srs",
        "EPSG:4326",
    ]
    page_width = float(inspection["page_width"])
    page_height = float(inspection["page_height"])
    viewport = inspection.get("viewport_bbox") or {
        "x0": 0.0,
        "y0": page_height,
        "x1": page_width,
        "y1": 0.0,
    }
    viewport_x0 = float(viewport.get("x0", viewport.get("min_x", 0.0)))
    viewport_y0 = float(viewport.get("y0", viewport.get("max_y", page_height)))
    viewport_x1 = float(viewport.get("x1", viewport.get("max_x", page_width)))
    viewport_y1 = float(viewport.get("y1", viewport.get("min_y", 0.0)))
    for point in inspection["control_points"][:4]:
        page_x = viewport_x0 + float(point["local_x"]) * (viewport_x1 - viewport_x0)
        pdf_y = viewport_y0 + float(point["local_y"]) * (viewport_y1 - viewport_y0)
        pixel_x = page_x / page_width * width
        pixel_y = (page_height - pdf_y) / page_height * height
        translate_command.extend(
            [
                "-gcp",
                str(pixel_x),
                str(pixel_y),
                str(point["lng"]),
                str(point["lat"]),
            ]
        )
    translate_command.extend([str(rendered), str(raw_geotiff)])

    run_gdal(translate_command, "No fue posible georreferenciar la imagen renderizada.")
    run_gdal(
        [
            "gdalwarp",
            "-multi",
            "-wo",
            "NUM_THREADS=ALL_CPUS",
            "-t_srs",
            "EPSG:3857",
            "-r",
            settings.RASTER_RESAMPLING,
            str(raw_geotiff),
            str(warped),
        ],
        "No fue posible reproyectar la imagen renderizada.",
    )
    run_gdal(
        [
            "gdal_translate",
            "-of",
            "MBTILES",
            "-co",
            f"TILE_FORMAT={settings.RASTER_TILE_FORMAT.upper()}",
            "-co",
            f"MINZOOM={settings.GEOPDF_MIN_ZOOM}",
            "-co",
            f"MAXZOOM={settings.GEOPDF_MAX_ZOOM}",
            str(warped),
            str(destination),
        ],
        "No fue posible generar MBTiles desde el GeoPDF renderizado.",
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

    _set_mbtiles_scheme(destination, "tms")
    inspection["tile_zoom"] = {
        "min": settings.GEOPDF_MIN_ZOOM,
        "max": settings.GEOPDF_MAX_ZOOM,
        "default": settings.GEOPDF_DEFAULT_ZOOM,
    }
    return destination


def _set_mbtiles_scheme(path: Path, scheme: str) -> None:
    with sqlite3.connect(path) as connection:
        connection.execute("DELETE FROM metadata WHERE name = 'scheme'")
        connection.execute(
            "INSERT INTO metadata (name, value) VALUES ('scheme', ?)",
            (scheme,),
        )
        connection.commit()


def _image_size(path: Path) -> tuple[int, int]:
    with Image.open(path) as image:
        return image.size

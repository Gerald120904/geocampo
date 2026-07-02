import shutil
from pathlib import Path, PurePosixPath
from zipfile import ZipFile

import geopandas as gpd

from app.core.exceptions import GeoCampoError
from app.gis.validation import ensure_required_shapefile_parts
from app.gis.vector_processor import ProcessedLayer, export_frame


def _safe_extract(archive: ZipFile, destination: Path) -> None:
    for member in archive.infolist():
        member_path = PurePosixPath(member.filename)
        if member_path.is_absolute() or ".." in member_path.parts:
            raise GeoCampoError("UNSAFE_ARCHIVE", "El ZIP contiene rutas no seguras.")
        target = destination.joinpath(*member_path.parts).resolve()
        if destination.resolve() not in target.parents and target != destination.resolve():
            raise GeoCampoError("UNSAFE_ARCHIVE", "El ZIP contiene rutas no seguras.")
        if member.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as source, target.open("wb") as output:
                shutil.copyfileobj(source, output)


def process_shapefile(source: Path, layers_dir: Path, temp_dir: Path) -> tuple[list[ProcessedLayer], str]:
    extraction = temp_dir / "shapefile"
    extraction.mkdir(parents=True, exist_ok=True)
    with ZipFile(source) as archive:
        _safe_extract(archive, extraction)
    shapefiles = [path for path in extraction.rglob("*") if path.is_file() and path.suffix.lower() == ".shp"]
    if not shapefiles:
        raise GeoCampoError("INCOMPLETE_SHAPEFILE", "No se encontró ningún archivo .shp.")
    results: list[ProcessedLayer] = []
    crs_values: list[str] = []
    for shp_path in shapefiles:
        ensure_required_shapefile_parts(shp_path)
        frame = gpd.read_file(shp_path)
        layer, crs = export_frame(frame, shp_path.stem, layers_dir)
        results.append(layer)
        crs_values.append(crs)
    return results, crs_values[0] if len(set(crs_values)) == 1 else "multiple"

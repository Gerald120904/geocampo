from pathlib import Path
from zipfile import BadZipFile, ZipFile

from app.core.exceptions import GeoCampoError

SUPPORTED_EXTENSIONS = {".geojson", ".json", ".gpkg", ".mbtiles", ".zip", ".tif", ".tiff", ".pdf"}
ADVANCED_EXTENSIONS = {".qgs", ".qgz", ".kml", ".kmz"}


def detect_source_type(path: str | Path) -> str:
    file_path = Path(path)
    suffix = file_path.suffix.lower()
    if suffix in {".geojson", ".json"}:
        return "geojson"
    if suffix == ".gpkg":
        return "geopackage"
    if suffix == ".mbtiles":
        return "mbtiles"
    if suffix in {".tif", ".tiff"}:
        return "geotiff"
    if suffix == ".pdf":
        return "geopdf"
    if suffix == ".zip":
        try:
            with ZipFile(file_path) as archive:
                names = [name.lower() for name in archive.namelist()]
            if any(name.endswith(".shp") for name in names):
                return "shapefile"
        except BadZipFile as exc:
            raise GeoCampoError("CORRUPT_FILE", "El ZIP está corrupto.") from exc
        raise GeoCampoError("UNSUPPORTED_FORMAT", "El ZIP no contiene un Shapefile.")
    if suffix in ADVANCED_EXTENSIONS:
        raise GeoCampoError(
            "FORMAT_NOT_AVAILABLE_IN_MVP",
            f"El formato {suffix} está previsto para una fase avanzada y aún no está habilitado.",
        )
    raise GeoCampoError("UNSUPPORTED_FORMAT", f"Formato no soportado: {suffix or 'sin extensión'}.")


def validate_upload_extension(filename: str) -> None:
    suffix = Path(filename).suffix.lower()
    if suffix not in SUPPORTED_EXTENSIONS | ADVANCED_EXTENSIONS:
        raise GeoCampoError("UNSUPPORTED_FORMAT", f"Formato no soportado: {suffix or 'sin extensión'}.")

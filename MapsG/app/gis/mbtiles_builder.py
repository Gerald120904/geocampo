import shutil
import sqlite3
from pathlib import Path

from app.core.exceptions import GeoCampoError
from app.gis.bounds import bounds_dict


def process_mbtiles(source: Path, output_dir: Path) -> tuple[Path, dict[str, float], str]:
    try:
        connection = sqlite3.connect(f"file:{source.resolve()}?mode=ro", uri=True)
        rows = dict(connection.execute("SELECT name, value FROM metadata").fetchall())
        tile_count = connection.execute("SELECT COUNT(*) FROM tiles").fetchone()[0]
        connection.close()
    except (sqlite3.Error, TypeError) as exc:
        raise GeoCampoError("CORRUPT_FILE", "El archivo MBTiles no es válido.") from exc
    if tile_count <= 0:
        raise GeoCampoError("EMPTY_MBTILES", "El archivo MBTiles no contiene tiles.")
    raw_bounds = rows.get("bounds")
    if not raw_bounds:
        raise GeoCampoError("MAP_WITHOUT_GEOREFERENCE", "MBTiles no contiene metadata de bounds.")
    try:
        values = [float(value) for value in raw_bounds.split(",")]
        if len(values) != 4:
            raise ValueError
        parsed_bounds = bounds_dict(values)
    except ValueError as exc:
        raise GeoCampoError("INVALID_BOUNDS", "Los bounds de MBTiles no son válidos.") from exc
    destination = output_dir / "map.mbtiles"
    shutil.copy2(source, destination)
    return destination, parsed_bounds, rows.get("format", "unknown")


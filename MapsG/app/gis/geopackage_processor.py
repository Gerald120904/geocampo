from pathlib import Path

import fiona
import geopandas as gpd

from app.core.exceptions import GeoCampoError
from app.gis.vector_processor import ProcessedLayer, export_frame


def process_geopackage(source: Path, layers_dir: Path) -> tuple[list[ProcessedLayer], str]:
    layer_names = list(fiona.listlayers(source))
    if not layer_names:
        raise GeoCampoError("EMPTY_GEOPACKAGE", "El GeoPackage no contiene capas vectoriales.")
    results: list[ProcessedLayer] = []
    crs_values: list[str] = []
    for name in layer_names:
        frame = gpd.read_file(source, layer=name)
        if frame.empty:
            continue
        layer, crs = export_frame(frame, name, layers_dir)
        results.append(layer)
        crs_values.append(crs)
    if not results:
        raise GeoCampoError("EMPTY_GEOPACKAGE", "El GeoPackage no contiene capas vectoriales utilizables.")
    return results, crs_values[0] if len(set(crs_values)) == 1 else "multiple"


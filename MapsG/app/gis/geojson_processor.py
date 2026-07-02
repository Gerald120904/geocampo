from pathlib import Path

import geopandas as gpd

from app.gis.vector_processor import ProcessedLayer, export_frame


def process_geojson(source: Path, layers_dir: Path) -> tuple[list[ProcessedLayer], str]:
    frame = gpd.read_file(source)
    layer, crs = export_frame(frame, source.stem, layers_dir)
    return [layer], crs


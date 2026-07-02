import sqlite3
from pathlib import Path
from zipfile import ZipFile

import pytest

from app.core.exceptions import GeoCampoError
from app.gis.detector import detect_source_type


def test_detects_supported_extensions(tmp_path: Path):
    geojson = tmp_path / "layer.geojson"
    geojson.write_text("{}", encoding="utf-8")
    gpkg = tmp_path / "map.gpkg"
    gpkg.touch()
    geotiff = tmp_path / "ortofoto.tif"
    geotiff.touch()
    geopdf = tmp_path / "plano.pdf"
    geopdf.touch()
    assert detect_source_type(geojson) == "geojson"
    assert detect_source_type(gpkg) == "geopackage"
    assert detect_source_type(geotiff) == "geotiff"
    assert detect_source_type(geopdf) == "geopdf"


def test_detects_shapefile_zip(tmp_path: Path):
    archive_path = tmp_path / "shape.zip"
    with ZipFile(archive_path, "w") as archive:
        archive.writestr("parcelas.shp", b"placeholder")
    assert detect_source_type(archive_path) == "shapefile"


def test_rejects_qgis_until_advanced_phase(tmp_path: Path):
    qgz = tmp_path / "project.qgz"
    qgz.touch()
    with pytest.raises(GeoCampoError) as error:
        detect_source_type(qgz)
    assert error.value.code == "FORMAT_NOT_AVAILABLE_IN_MVP"

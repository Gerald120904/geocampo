import json
from pathlib import Path
from zipfile import ZipFile

from app.services.package_service import build_package, file_sha256


def test_builds_geocampo_package(tmp_path: Path):
    root = tmp_path / "processed"
    layers = root / "layers"
    legend = root / "legend"
    layers.mkdir(parents=True)
    legend.mkdir()
    (layers / "lotes.geojson").write_text('{"type":"FeatureCollection","features":[]}', encoding="utf-8")
    (legend / "legend.json").write_text('{"items":[]}', encoding="utf-8")
    (root / "preview.png").write_bytes(b"png")
    (root / "original_info.json").write_text('{"included_in_package":false}', encoding="utf-8")
    metadata = {
        "package_type": "geocampo_offline_map",
        "bounds": {"min_lat": 10, "min_lng": -84, "max_lat": 11, "max_lng": -83},
        "layers": [{"file": "layers/lotes.geojson"}],
        "files": {
            "preview": "preview.png",
            "legend": "legend/legend.json",
            "original_info": "original_info.json",
        },
    }
    (root / "metadata.json").write_text(json.dumps(metadata), encoding="utf-8")
    result = build_package(root, tmp_path / "packages", "Finca Terranova")
    assert result.name == "finca_terranova.geocampo.zip"
    with ZipFile(result) as archive:
        assert "metadata.json" in archive.namelist()
        assert "layers/lotes.geojson" in archive.namelist()
        assert "original_info.json" in archive.namelist()


def test_file_sha256(tmp_path: Path):
    payload = tmp_path / "payload.bin"
    payload.write_bytes(b"geocampo")
    assert file_sha256(payload) == "74e3e51b86418c63df39292224b70a333392e3b85e64b4c6d7fea67fd377f06f"

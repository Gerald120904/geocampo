from datetime import UTC, datetime
from pathlib import Path

from geoalchemy2.elements import WKTElement
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.exceptions import GeoCampoError
from app.core.statuses import (
    MAP_STATUS_BUILDING_PACKAGE,
    MAP_STATUS_BUILDING_PREVIEW,
    MAP_STATUS_BUILDING_TILES,
    MAP_STATUS_DUPLICATE_REVIEW,
    MAP_STATUS_FAILED,
    MAP_STATUS_INSPECTING,
    MAP_STATUS_OPTIMIZING,
    MAP_STATUS_PROCESSING,
    MAP_STATUS_QUICK_BUILDING,
    MAP_STATUS_QUICK_READY,
    MAP_STATUS_RAW_READY,
    MAP_STATUS_READY,
    MAP_STATUS_WARPING,
)
from app.gis.bounds import center, union_bounds
from app.gis.geojson_processor import process_geojson
from app.gis.geopackage_processor import process_geopackage
from app.gis.geopdf_inspector import inspect_geopdf_measure
from app.gis.geopdf_mbtiles import process_geopdf_to_mbtiles_pure_python
from app.gis.geopdf_processor import process_geopdf
from app.gis.geotiff_processor import process_geotiff
from app.gis.mbtiles_builder import process_mbtiles
from app.gis.pdf_renderer import render_pdf_page_to_png
from app.gis.preview_builder import create_preview
from app.gis.raster_processor import raster_bounds_wgs84
from app.gis.shapefile_processor import process_shapefile
from app.models import MapFile, MapLayer, MapProject, ProcessingJob
from app.services.map_duplicate_service import (
    apply_duplicate_metadata,
    find_duplicates,
    spatial_fingerprint,
)
from app.services.metadata_service import build_metadata, metadata_layer
from app.services.package_service import build_package, copy_original, file_sha256, write_json
from app.services.r2_storage_service import R2StorageService, is_r2_enabled, r2_key_for_map_file
from app.services.storage_service import (
    make_directory,
    is_r2_uri,
    materialize_file,
    permanent_key,
    remove_tree,
    r2_uri,
    upload_directory,
    upload_permanent_file,
    using_r2,
)


def _update_job(
    db: Session,
    map_project: MapProject,
    job: ProcessingJob,
    step: str,
    progress: int,
    status: str | None = None,
) -> None:
    progress = max(0, min(100, int(progress)))
    if job.progress is not None:
        progress = max(job.progress, progress)

    job.step = step
    job.progress = progress
    if status:
        map_project.status = status
    map_project.processing_message = step
    db.commit()


def create_quick_geopdf_view(db: Session, map_id: str, job_id: str) -> None:
    map_project = db.get(MapProject, map_id)
    job = db.get(ProcessingJob, job_id)
    if not map_project or not job:
        raise GeoCampoError("MAP_NOT_FOUND", "Mapa o job no encontrado.", 404)

    job.status = "running"
    job.started_at = datetime.now(UTC)
    map_project.status = MAP_STATUS_QUICK_BUILDING
    map_project.processing_message = "Preparando vista rapida HD"
    db.commit()

    try:
        source = materialize_file(map_project.original_file_path)
        if not source or not source.is_file():
            raise GeoCampoError("ORIGINAL_NOT_FOUND", "No se encontro el archivo original.")

        if map_project.source_type != "geopdf":
            raise GeoCampoError(
                "QUICK_VIEW_ONLY_GEOPDF",
                "La vista rapida solo aplica para GeoPDF.",
                422,
            )

        _update_job(db, map_project, job, "Validando GeoPDF", 10, MAP_STATUS_INSPECTING)
        inspection = inspect_geopdf_measure(source)
        bounds = inspection["bounds"]
        company_id = map_project.project.company_id
        quick_root = make_directory(
            settings.PROCESSED_FILES_PATH,
            company_id,
            map_project.project_id,
            map_project.id,
            "quick",
        )
        remove_tree(quick_root)
        quick_root.mkdir(parents=True, exist_ok=True)
        quick_temp = make_directory(settings.TEMP_PATH, map_project.id, "quick")
        remove_tree(quick_temp)
        quick_temp.mkdir(parents=True, exist_ok=True)

        _update_job(db, map_project, job, "Leyendo georreferencia", 35, MAP_STATUS_INSPECTING)
        map_project.bounds_geometry = bounds
        map_project.bounds_geom = _bounds_polygon(bounds)
        map_project.center_lat = inspection["center"]["lat"]
        map_project.center_lng = inspection["center"]["lng"]
        map_project.crs_original = "EPSG:4326"
        map_project.crs_app = "EPSG:4326"
        map_project.footprint_geometry = inspection["footprint"]
        map_project.footprint_geom = _geojson_polygon(inspection["footprint"])
        map_project.georef_metadata = {
            "method": inspection["georef_method"],
            "width": inspection["page_width"],
            "height": inspection["page_height"],
            "viewport_bbox": inspection.get("viewport_bbox"),
            "control_points": inspection["control_points"],
        }
        map_project.raster_width = int(inspection["page_width"])
        map_project.raster_height = int(inspection["page_height"])
        map_project.georef_method = inspection["georef_method"]
        map_project.pdf_page_count = inspection["page_count"]
        map_project.pdf_selected_page = inspection["selected_page"]
        if not map_project.file_checksum_sha256:
            map_project.file_checksum_sha256 = file_sha256(source)
        map_project.spatial_fingerprint = spatial_fingerprint(bounds, map_project.crs_original)
        db.commit()

        _update_job(db, map_project, job, "Generando tiles HD", 45, MAP_STATUS_QUICK_BUILDING)

        def on_quick_tiles_progress(done: int, total: int) -> None:
            if total <= 0:
                return
            percent = 45 + int((done / total) * 50)
            _update_job(
                db,
                map_project,
                job,
                f"Creando vista HD {done}/{total}",
                percent,
                MAP_STATUS_QUICK_BUILDING,
            )

        quick_mbtiles, quick_zoom = process_geopdf_to_mbtiles_pure_python(
            source,
            quick_root,
            temp_dir=quick_temp,
            inspection=inspection,
            clean_render=False,
            make_white_transparent=False,
            render_zoom=max(float(settings.GEOPDF_RENDER_ZOOM), 3.0),
            output_name="quick.mbtiles",
            on_progress=on_quick_tiles_progress,
        )

        map_project.quick_mbtiles_file_path = upload_permanent_file(
            quick_mbtiles,
            permanent_key(
                "processed",
                company_id,
                map_project.project_id,
                map_project.id,
                "quick/quick.mbtiles",
            ),
            content_type="application/vnd.sqlite3",
        )
        map_project.quick_min_zoom = int(quick_zoom["min"])
        map_project.quick_max_zoom = int(quick_zoom["max"])
        map_project.quick_default_zoom = int(quick_zoom["default"])
        map_project.quick_created_at = datetime.now(UTC)
        map_project.status = MAP_STATUS_QUICK_READY
        map_project.processing_message = "Vista rapida HD lista · PDF sin limpiar"
        map_project.active_view_mode = "quick"
        job.status = "completed"
        job.step = "Vista rapida HD lista"
        job.progress = 100
        job.finished_at = datetime.now(UTC)
        db.commit()
    except Exception as exc:
        db.rollback()
        map_project = db.get(MapProject, map_id)
        job = db.get(ProcessingJob, job_id)
        if map_project and job:
            map_project.status = MAP_STATUS_FAILED
            map_project.processing_message = str(exc)[:2000]
            job.status = "failed"
            job.step = "Error"
            job.error_message = str(exc)[:2000]
            job.finished_at = datetime.now(UTC)
            db.commit()
        raise


def prepare_raw_geopdf_view(db: Session, map_id: str) -> MapProject:
    map_project = db.get(MapProject, map_id)
    if not map_project:
        raise GeoCampoError("MAP_NOT_FOUND", "Mapa no encontrado.", 404)

    source = materialize_file(map_project.original_file_path)
    if not source or not source.is_file():
        raise GeoCampoError("ORIGINAL_NOT_FOUND", "No se encontro el PDF original.", 404)

    if map_project.source_type != "geopdf":
        raise GeoCampoError(
            "RAW_VIEW_ONLY_GEOPDF",
            "La vista de PDF original solo aplica para GeoPDF.",
            422,
        )

    map_project.status = MAP_STATUS_PROCESSING
    map_project.processing_message = "Leyendo georreferencia del PDF"
    db.commit()

    inspection = inspect_geopdf_measure(source)
    bounds = inspection["bounds"]
    center_data = inspection["center"]
    raw_root = make_directory(
        settings.PROCESSED_FILES_PATH,
        map_project.project.company_id,
        map_project.project_id,
        map_project.id,
    )

    map_project.processed_folder_path = str(raw_root)
    map_project.bounds_geometry = bounds
    map_project.bounds_geom = _bounds_polygon(bounds)
    map_project.center_lat = center_data["lat"]
    map_project.center_lng = center_data["lng"]
    map_project.raw_bounds_geometry = bounds
    map_project.raw_center_lat = center_data["lat"]
    map_project.raw_center_lng = center_data["lng"]
    map_project.raw_pdf_page = inspection["selected_page"]
    map_project.crs_original = "EPSG:4326"
    map_project.crs_app = "EPSG:4326"
    map_project.footprint_geometry = inspection["footprint"]
    map_project.footprint_geom = _geojson_polygon(inspection["footprint"])
    map_project.georef_metadata = {
        "method": inspection["georef_method"],
        "page_width": inspection["page_width"],
        "page_height": inspection["page_height"],
        "viewport_bbox": inspection.get("viewport_bbox"),
        "control_points": inspection.get("control_points"),
    }
    map_project.raster_width = int(inspection["page_width"])
    map_project.raster_height = int(inspection["page_height"])
    map_project.georef_method = inspection["georef_method"]
    map_project.pdf_page_count = inspection["page_count"]
    map_project.pdf_selected_page = inspection["selected_page"]
    if not map_project.file_checksum_sha256:
        map_project.file_checksum_sha256 = file_sha256(source)
    map_project.spatial_fingerprint = spatial_fingerprint(bounds, map_project.crs_original)
    map_project.status = MAP_STATUS_RAW_READY
    map_project.processing_message = "PDF original montado con georreferencia"
    map_project.raw_view_ready_at = datetime.now(UTC)
    if map_project.quick_mbtiles_file_path:
        map_project.active_view_mode = "quick"
    elif settings.APP_ENV == "production":
        map_project.active_view_mode = "quick"
        map_project.processing_message = "Generando vista rapida del mapa"
    else:
        map_project.active_view_mode = "raw"
    db.commit()
    db.refresh(map_project)
    return map_project


def process_map(db: Session, map_id: str, job_id: str) -> None:
    map_project = db.get(MapProject, map_id)
    job = db.get(ProcessingJob, job_id)
    if not map_project or not job:
        raise GeoCampoError("MAP_NOT_FOUND", "Mapa o job no encontrado.", 404)

    job.status = "running"
    job.started_at = datetime.now(UTC)
    map_project.status = (
        MAP_STATUS_OPTIMIZING
        if map_project.raw_view_ready_at or map_project.quick_mbtiles_file_path
        else MAP_STATUS_PROCESSING
    )
    map_project.package_file_path = None
    if not map_project.quick_mbtiles_file_path:
        map_project.preview_file_path = None
    map_project.package_version = None
    map_project.package_size_bytes = None
    map_project.package_checksum_sha256 = None
    map_project.package_created_at = None
    if not map_project.quick_mbtiles_file_path:
        map_project.footprint_geometry = None
        map_project.footprint_geom = None
        map_project.georef_metadata = None
    map_project.raster_width = None
    map_project.raster_height = None
    map_project.georef_method = None
    map_project.pdf_page_count = None
    map_project.pdf_selected_page = None
    map_project.processing_message = "Archivo recibido"
    db.commit()

    try:
        _update_job(db, map_project, job, "Archivo recibido", 0, MAP_STATUS_PROCESSING)
        source = materialize_file(map_project.original_file_path)
        if not source or not source.is_file():
            raise GeoCampoError("ORIGINAL_NOT_FOUND", "No se encontró el archivo original.")

        if not map_project.file_checksum_sha256:
            map_project.file_checksum_sha256 = file_sha256(source)
            db.commit()

        company_id = map_project.project.company_id
        package_root = make_directory(
            settings.PROCESSED_FILES_PATH,
            company_id,
            map_project.project_id,
            map_project.id,
        )
        remove_tree(package_root)
        package_root.mkdir(parents=True, exist_ok=True)
        layers_dir = package_root / "layers"
        legend_dir = package_root / "legend"
        layers_dir.mkdir()
        legend_dir.mkdir()

        temp_dir = make_directory(settings.TEMP_PATH, map_project.id)
        remove_tree(temp_dir)
        temp_dir.mkdir(parents=True, exist_ok=True)

        _update_job(db, map_project, job, "Validando archivo", 5, MAP_STATUS_INSPECTING)
        processed_layers = []
        raster_path: Path | None = None
        raster_bounds: dict[str, float] | None = None
        geopdf_inspection: dict | None = None

        if map_project.source_type == "geojson":
            _update_job(db, map_project, job, "Leyendo georreferencia", 10, MAP_STATUS_INSPECTING)
            processed_layers, original_crs = process_geojson(source, layers_dir)
        elif map_project.source_type == "shapefile":
            _update_job(db, map_project, job, "Leyendo georreferencia", 10, MAP_STATUS_INSPECTING)
            processed_layers, original_crs = process_shapefile(source, layers_dir, temp_dir)
        elif map_project.source_type == "geopackage":
            _update_job(db, map_project, job, "Leyendo georreferencia", 10, MAP_STATUS_INSPECTING)
            processed_layers, original_crs = process_geopackage(source, layers_dir)
        elif map_project.source_type == "mbtiles":
            _update_job(db, map_project, job, "Leyendo georreferencia", 10, MAP_STATUS_INSPECTING)
            raster_path, raster_bounds, _ = process_mbtiles(source, package_root)
            original_crs = "EPSG:3857"
        elif map_project.source_type == "geotiff":
            _update_job(db, map_project, job, "Leyendo georreferencia", 10, MAP_STATUS_INSPECTING)
            raster_bounds, original_crs = raster_bounds_wgs84(source)
            _update_job(db, map_project, job, "Calculando bounds", 18, MAP_STATUS_INSPECTING)
        elif map_project.source_type == "geopdf":
            _update_job(db, map_project, job, "Leyendo georreferencia", 10, MAP_STATUS_INSPECTING)
            geopdf_inspection = inspect_geopdf_measure(source)
            raster_bounds = geopdf_inspection["bounds"]
            original_crs = "EPSG:4326"
            _update_job(db, map_project, job, "Calculando bounds", 18, MAP_STATUS_INSPECTING)
        else:
            raise GeoCampoError("UNSUPPORTED_FORMAT", "Tipo de mapa no procesable.")

        all_bounds = [layer.bounds for layer in processed_layers]
        if raster_bounds:
            all_bounds.append(raster_bounds)
        bounds = union_bounds(all_bounds)
        if not bounds:
            raise GeoCampoError("INVALID_BOUNDS", "No fue posible calcular los bounds del mapa.")

        if geopdf_inspection:
            map_project.bounds_geometry = geopdf_inspection["bounds"]
            map_project.center_lat = geopdf_inspection["center"]["lat"]
            map_project.center_lng = geopdf_inspection["center"]["lng"]
            map_project.crs_original = original_crs
            map_project.footprint_geometry = geopdf_inspection["footprint"]
            map_project.footprint_geom = _geojson_polygon(geopdf_inspection["footprint"])
            map_project.georef_metadata = {
                "method": geopdf_inspection["georef_method"],
                "width": geopdf_inspection["page_width"],
                "height": geopdf_inspection["page_height"],
                "control_points": geopdf_inspection["control_points"],
            }
            map_project.raster_width = int(geopdf_inspection["page_width"])
            map_project.raster_height = int(geopdf_inspection["page_height"])
            map_project.georef_method = geopdf_inspection["georef_method"]
            map_project.pdf_page_count = geopdf_inspection["page_count"]
            map_project.pdf_selected_page = geopdf_inspection["selected_page"]
            db.commit()

        map_project.crs_original = original_crs
        map_project.bounds_geometry = map_project.bounds_geometry or bounds
        map_project.bounds_geom = _bounds_polygon(bounds)
        current_center = center(bounds)
        map_project.center_lat = (
            map_project.center_lat
            if map_project.center_lat is not None
            else current_center["lat"]
        )
        map_project.center_lng = (
            map_project.center_lng
            if map_project.center_lng is not None
            else current_center["lng"]
        )
        map_project.crs_app = "EPSG:4326"
        map_project.spatial_fingerprint = spatial_fingerprint(bounds, map_project.crs_original)
        db.commit()

        _update_job(db, map_project, job, "Revisando duplicados", 22, MAP_STATUS_INSPECTING)
        duplicate_candidates = find_duplicates(db, map_project)
        primary_duplicate = duplicate_candidates[0] if duplicate_candidates else None
        duplicate_accepted = map_project.duplicate_reason in {
            "replace_existing",
            "save_new_version",
            "upload_anyway",
        }
        apply_duplicate_metadata(map_project, primary_duplicate)
        if primary_duplicate and primary_duplicate.score >= 95 and not duplicate_accepted:
            map_project.status = MAP_STATUS_DUPLICATE_REVIEW
            map_project.processing_message = "Mapa pendiente de revision por posible duplicado"
            job.status = "completed"
            job.step = "Revision de duplicado requerida"
            job.progress = 100
            job.finished_at = datetime.now(UTC)
            db.commit()
            return

        _update_job(db, map_project, job, "Generando preview", 30, MAP_STATUS_BUILDING_PREVIEW)
        if geopdf_inspection:
            preview = render_pdf_page_to_png(
                source,
                package_root / "preview.png",
                page_index=geopdf_inspection["selected_page"] - 1,
                zoom=min(settings.GEOPDF_RENDER_ZOOM, 0.75),
            )
        else:
            preview = create_preview(package_root / "preview.png", map_project.name, bounds)
        copy_original(source, package_root)
        _update_job(db, map_project, job, "Preview generado", 30, MAP_STATUS_BUILDING_PREVIEW)

        db.execute(delete(MapLayer).where(MapLayer.map_project_id == map_project.id))
        db.execute(
            delete(MapFile).where(
                MapFile.map_project_id == map_project.id,
                MapFile.file_type != "original",
            )
        )
        db.flush()

        layer_metadata = []
        for layer in processed_layers:
            layer_metadata.append(metadata_layer(layer, package_root))
            db.add(
                MapLayer(
                    map_project_id=map_project.id,
                    name=layer.name,
                    layer_key=layer.key,
                    layer_type=layer.layer_type,
                    geometry_type=layer.geometry_type,
                    file_path=str(layer.path),
                    visible_default=True,
                    opacity_default=1.0,
                    properties_schema=layer.properties_schema,
                    feature_count=layer.feature_count,
                )
            )
            db.add(
                MapFile(
                    map_project_id=map_project.id,
                    file_type="geojson",
                    original_name=layer.path.name,
                    stored_name=layer.path.name,
                    file_path=str(layer.path),
                    mime_type="application/geo+json",
                    size_bytes=layer.path.stat().st_size,
                )
            )

        if raster_path:
            _update_job(db, map_project, job, "Generando tiles", 70, MAP_STATUS_BUILDING_TILES)
        elif map_project.source_type == "geotiff":
            _update_job(db, map_project, job, "Reproyectando raster", 45, MAP_STATUS_WARPING)
            raster_path, raster_bounds, original_crs = process_geotiff(
                source,
                package_root,
                temp_dir,
                bounds=raster_bounds,
                crs=original_crs,
            )
            _update_job(db, map_project, job, "Generando tiles", 80, MAP_STATUS_BUILDING_TILES)
        elif map_project.source_type == "geopdf":
            _update_job(db, map_project, job, "Renderizando raster", 40, MAP_STATUS_WARPING)
            _update_job(db, map_project, job, "Reproyectando raster", 45, MAP_STATUS_WARPING)

            def on_tiles_progress(done: int, total: int) -> None:
                if total <= 0:
                    return
                percent = 45 + int((done / total) * 35)
                _update_job(
                    db,
                    map_project,
                    job,
                    f"Generando tiles {done}/{total}",
                    percent,
                    MAP_STATUS_BUILDING_TILES,
                )

            raster_path, raster_bounds, original_crs, geopdf_inspection = process_geopdf(
                source,
                package_root,
                temp_dir,
                inspection=geopdf_inspection,
                on_tiles_progress=on_tiles_progress,
            )
            tile_zoom = geopdf_inspection.get("tile_zoom") if geopdf_inspection else None
            if tile_zoom:
                map_project.min_zoom = int(tile_zoom["min"])
                map_project.max_zoom = int(tile_zoom["max"])
                map_project.default_zoom = int(tile_zoom["default"])
            _update_job(db, map_project, job, "Generando tiles", 80, MAP_STATUS_BUILDING_TILES)

        if raster_path:
            db.add(
                MapLayer(
                    map_project_id=map_project.id,
                    name="Mapa PDF" if map_project.source_type == "geopdf" else "Mapa raster",
                    layer_key="raster_main",
                    layer_type="raster",
                    geometry_type=None,
                    file_path=str(raster_path),
                    visible_default=True,
                    opacity_default=1.0,
                    properties_schema={
                        "tile_format": "mbtiles",
                        "source": map_project.source_type,
                    },
                    feature_count=0,
                )
            )

        map_project.bounds_geometry = map_project.bounds_geometry or bounds
        map_project.bounds_geom = _bounds_polygon(bounds)
        map_project.center_lat = map_project.center_lat if map_project.center_lat is not None else current_center["lat"]
        map_project.center_lng = map_project.center_lng if map_project.center_lng is not None else current_center["lng"]
        map_project.crs_app = "EPSG:4326"
        map_project.spatial_fingerprint = spatial_fingerprint(bounds, map_project.crs_original)
        db.commit()

        files = {
            "preview": "preview.png",
            "legend": "legend/legend.json",
            "original_info": "original_info.json",
        }
        if raster_path:
            files["raster"] = "map.mbtiles"

        legend_items = [
            {
                "layer_id": layer["id"],
                "label": layer["name"],
                "type": layer["type"],
                **layer.get("style", {}),
            }
            for layer in layer_metadata
        ]
        write_json(legend_dir / "legend.json", {"version": "1.0.0", "items": legend_items})
        metadata = build_metadata(map_project, layer_metadata, bounds, files)
        metadata_path = write_json(package_root / "metadata.json", metadata)

        _update_job(db, map_project, job, "Guardando metadata", 85, MAP_STATUS_BUILDING_PACKAGE)
        package_dir = make_directory(
            settings.PACKAGES_PATH,
            company_id,
            map_project.project_id,
            map_project.id,
        )
        try:
            def on_package_progress(done: int, total: int) -> None:
                if total <= 0:
                    return
                percent = 90 + int((done / total) * 8)
                _update_job(
                    db,
                    map_project,
                    job,
                    f"Generando paquete zip {done}/{total}",
                    percent,
                    MAP_STATUS_BUILDING_PACKAGE,
                )

            package_path = build_package(
                package_root,
                package_dir,
                map_project.name,
                on_progress=on_package_progress,
            )
        except GeoCampoError:
            raise
        except Exception as exc:
            raise GeoCampoError("PACKAGE_BUILD_FAILED", "No se pudo generar el paquete offline.", 500) from exc

        package_version = "1.0.0"
        package_size = package_path.stat().st_size
        package_checksum = file_sha256(package_path)
        processed_key_prefix = permanent_key(
            "processed",
            company_id,
            map_project.project_id,
            map_project.id,
            "",
        )
        uploaded_paths = upload_directory(package_root, processed_key_prefix)
        if is_r2_enabled():
            package_stored_path = r2_key_for_map_file(
                kind="packages",
                company_id=company_id,
                project_id=map_project.project_id,
                map_id=map_project.id,
                filename=package_path.name,
            )
            R2StorageService().upload_file(
                local_path=package_path,
                key=package_stored_path,
                content_type="application/zip",
            )
        else:
            package_stored_path = str(package_path)

        def stored_path(path: Path) -> str:
            return uploaded_paths.get(path.resolve(), str(path))

        if using_r2():
            for layer in db.scalars(select(MapLayer).where(MapLayer.map_project_id == map_project.id)):
                if not is_r2_uri(layer.file_path):
                    layer.file_path = stored_path(Path(layer.file_path))
            for map_file in db.scalars(select(MapFile).where(MapFile.map_project_id == map_project.id)):
                if not is_r2_uri(map_file.file_path):
                    map_file.file_path = stored_path(Path(map_file.file_path))

        for file_type, path in (
            ("metadata", metadata_path),
            ("preview", preview),
            ("legend", legend_dir / "legend.json"),
            ("original_info", package_root / "original_info.json"),
            ("package", package_path),
        ):
            db.add(
                MapFile(
                    map_project_id=map_project.id,
                    file_type=file_type,
                    original_name=path.name,
                    stored_name=path.name,
                    file_path=package_stored_path if file_type == "package" else stored_path(path),
                    mime_type="application/zip" if file_type == "package" else None,
                    size_bytes=path.stat().st_size,
                )
            )
        if raster_path:
            db.add(
                MapFile(
                    map_project_id=map_project.id,
                    file_type="mbtiles",
                    original_name="map.mbtiles",
                    stored_name="map.mbtiles",
                    file_path=stored_path(raster_path),
                    mime_type="application/vnd.sqlite3",
                    size_bytes=raster_path.stat().st_size,
                )
            )

        map_project.status = MAP_STATUS_READY
        map_project.active_view_mode = "optimized"
        map_project.processed_folder_path = (
            r2_uri(processed_key_prefix) if using_r2() else str(package_root)
        )
        map_project.package_file_path = package_stored_path
        map_project.package_version = package_version
        map_project.package_size_bytes = package_size
        map_project.package_checksum_sha256 = package_checksum
        map_project.package_created_at = datetime.now(UTC)
        map_project.preview_file_path = stored_path(preview)
        map_project.processed_at = datetime.now(UTC)
        map_project.processing_message = "Mapa limpio · Offline · Alta calidad"
        job.status = "completed"
        job.step = "Listo optimizado"
        job.progress = 100
        job.finished_at = datetime.now(UTC)
        db.commit()
    except Exception as exc:
        db.rollback()
        map_project = db.get(MapProject, map_id)
        job = db.get(ProcessingJob, job_id)
        if map_project and job:
            map_project.status = MAP_STATUS_FAILED
            map_project.processing_message = str(exc)[:2000]
            job.status = "failed"
            job.step = "Error"
            job.error_message = str(exc)[:2000]
            job.finished_at = datetime.now(UTC)
            db.commit()
        raise
    finally:
        temp_path = Path(settings.TEMP_PATH) / map_id
        remove_tree(temp_path)


def _bounds_polygon(bounds: dict[str, float]) -> WKTElement:
    min_lng = bounds["min_lng"]
    min_lat = bounds["min_lat"]
    max_lng = bounds["max_lng"]
    max_lat = bounds["max_lat"]
    wkt = (
        "POLYGON(("
        f"{min_lng} {min_lat}, "
        f"{max_lng} {min_lat}, "
        f"{max_lng} {max_lat}, "
        f"{min_lng} {max_lat}, "
        f"{min_lng} {min_lat}"
        "))"
    )
    if settings.DATABASE_URL.startswith("sqlite"):
        return wkt
    return WKTElement(wkt, srid=4326)


def _geojson_polygon(geometry: dict) -> WKTElement | None:
    coordinates = geometry.get("coordinates")
    if not coordinates or geometry.get("type") != "Polygon":
        return None
    ring = coordinates[0]
    wkt_points = ", ".join(f"{lng} {lat}" for lng, lat in ring)
    wkt = f"POLYGON(({wkt_points}))"
    if settings.DATABASE_URL.startswith("sqlite"):
        return wkt
    return WKTElement(wkt, srid=4326)

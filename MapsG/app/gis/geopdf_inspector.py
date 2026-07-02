from pathlib import Path

from pypdf import PdfReader

from app.core.exceptions import GeoCampoError


def inspect_geopdf_measure(source: Path) -> dict:
    try:
        reader = PdfReader(str(source))
    except Exception as exc:
        message = str(exc).lower()
        if "password" in message or "encrypted" in message:
            raise GeoCampoError(
                "PDF_PASSWORD_PROTECTED",
                "El PDF está protegido con contraseña.",
                422,
            ) from exc
        raise GeoCampoError("INVALID_PDF", "No se pudo abrir el PDF.", 422) from exc

    if reader.is_encrypted:
        raise GeoCampoError(
            "PDF_PASSWORD_PROTECTED",
            "El PDF está protegido con contraseña.",
            422,
        )

    if not reader.pages:
        raise GeoCampoError("EMPTY_PDF", "El PDF no contiene páginas.", 422)

    page = reader.pages[0]
    page_width = float(page.mediabox.width)
    page_height = float(page.mediabox.height)

    if "/VP" not in page:
        raise GeoCampoError(
            "PDF_WITHOUT_GEOREFERENCE",
            "El PDF no contiene viewport geoespacial /VP.",
            422,
        )

    viewports = page["/VP"]
    for viewport_ref in viewports:
        viewport = viewport_ref.get_object()
        if "/Measure" not in viewport:
            continue

        measure = viewport["/Measure"].get_object()
        if measure.get("/Subtype") != "/GEO":
            continue

        gpts = [float(value) for value in measure["/GPTS"]]
        lpts = [float(value) for value in measure["/LPTS"]]
        viewport_bbox = _viewport_bbox(viewport.get("/BBox"), page_width, page_height)
        points = []
        control_points = []

        for index in range(0, len(gpts), 2):
            lat = gpts[index]
            lng = gpts[index + 1]
            lpt_index = index
            local_x = lpts[lpt_index]
            local_y = lpts[lpt_index + 1]
            points.append({"lat": lat, "lng": lng})
            control_points.append(
                {
                    "name": f"gcp_{index // 2 + 1}",
                    "lat": lat,
                    "lng": lng,
                    "local_x": local_x,
                    "local_y": local_y,
                }
            )

        if len(points) < 4:
            raise GeoCampoError(
                "PDF_WITHOUT_GEOREFERENCE",
                "El PDF no contiene suficientes puntos geoespaciales.",
                422,
            )

        min_lat = min(point["lat"] for point in points)
        max_lat = max(point["lat"] for point in points)
        min_lng = min(point["lng"] for point in points)
        max_lng = max(point["lng"] for point in points)

        footprint = {
            "type": "Polygon",
            "coordinates": [
                [
                    [points[0]["lng"], points[0]["lat"]],
                    [points[1]["lng"], points[1]["lat"]],
                    [points[2]["lng"], points[2]["lat"]],
                    [points[3]["lng"], points[3]["lat"]],
                    [points[0]["lng"], points[0]["lat"]],
                ]
            ],
        }

        return {
            "is_georeferenced": True,
            "page_count": len(reader.pages),
            "selected_page": 1,
            "georef_method": "pdf_measure_geo",
            "gpts": gpts,
            "lpts": lpts,
            "page_width": page_width,
            "page_height": page_height,
            "viewport_bbox": viewport_bbox,
            "control_points": control_points,
            "bounds": {
                "min_lat": min_lat,
                "min_lng": min_lng,
                "max_lat": max_lat,
                "max_lng": max_lng,
            },
            "center": {
                "lat": (min_lat + max_lat) / 2,
                "lng": (min_lng + max_lng) / 2,
            },
            "footprint": footprint,
        }

    raise GeoCampoError(
        "PDF_WITHOUT_GEOREFERENCE",
        "El PDF no contiene medida geoespacial válida /Measure /GEO.",
        422,
    )


def _viewport_bbox(raw_bbox: object, page_width: float, page_height: float) -> dict[str, float]:
    try:
        values = [float(value) for value in raw_bbox] if raw_bbox else []
    except TypeError:
        values = []
    if len(values) < 4:
        return _full_page_bbox(page_width, page_height)

    min_x = max(0.0, min(values[0], values[2]))
    max_x = min(page_width, max(values[0], values[2]))
    min_y = max(0.0, min(values[1], values[3]))
    max_y = min(page_height, max(values[1], values[3]))
    if min_x >= max_x or min_y >= max_y:
        return _full_page_bbox(page_width, page_height)
    return {
        "x0": values[0],
        "y0": values[1],
        "x1": values[2],
        "y1": values[3],
        "min_x": min_x,
        "min_y": min_y,
        "max_x": max_x,
        "max_y": max_y,
    }


def _full_page_bbox(page_width: float, page_height: float) -> dict[str, float]:
    return {
        "x0": 0.0,
        "y0": 0.0,
        "x1": page_width,
        "y1": page_height,
        "min_x": 0.0,
        "min_y": 0.0,
        "max_x": page_width,
        "max_y": page_height,
    }

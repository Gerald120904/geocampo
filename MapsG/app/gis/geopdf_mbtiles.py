import io
import math
import sqlite3
from collections.abc import Callable
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

from app.core.config import settings
from app.core.exceptions import GeoCampoError
from app.gis.pdf_renderer import render_pdf_page_to_png

TILE_SIZE = 256
WHITE_ALPHA_THRESHOLD = 248
WHITE_CHROMA_TOLERANCE = 10
MAP_COLOR_MIN_SATURATION = 18
MAP_COLOR_MIN_VALUE = 45
MASK_GROW_RADIUS = 17
AffineTransform = tuple[tuple[float, float, float], tuple[float, float, float]]
ProgressCallback = Callable[[int, int], None]


def process_geopdf_to_mbtiles_pure_python(
    source: Path,
    package_root: Path,
    temp_dir: Path,
    inspection: dict,
    *,
    clean_render: bool = True,
    make_white_transparent: bool = True,
    render_zoom: float | None = None,
    output_name: str = "map.mbtiles",
    on_progress: ProgressCallback | None = None,
) -> tuple[Path, dict[str, int]]:
    rendered = render_pdf_page_to_png(
        source,
        temp_dir / f"{Path(output_name).stem}_rendered.png",
        page_index=inspection["selected_page"] - 1,
        zoom=render_zoom or settings.GEOPDF_RENDER_ZOOM,
    )
    destination = package_root / output_name
    bounds = inspection["bounds"]

    with Image.open(rendered) as opened:
        image = opened.convert("RGBA")
        if clean_render and settings.GEOPDF_CLEAN_RENDER:
            image = clean_geopdf_render(image)

    control = _control_points(inspection, image.width, image.height)
    min_zoom, max_zoom = _zoom_range(bounds)
    tile_jobs = [
        (zoom, tile_x, tile_y)
        for zoom in range(min_zoom, max_zoom + 1)
        for tile_x, tile_y in _tiles_for_bounds(bounds, zoom)
    ]
    total_tiles = len(tile_jobs)
    done_tiles = 0

    destination.unlink(missing_ok=True)
    connection = sqlite3.connect(destination)
    try:
        connection.execute("PRAGMA journal_mode=OFF")
        connection.execute("PRAGMA synchronous=OFF")
        connection.execute("PRAGMA temp_store=MEMORY")
        _create_schema(connection)
        tile_count = 0
        pending_tiles = []
        for zoom, tile_x, tile_y in tile_jobs:
            tile = _render_tile(
                image,
                control,
                tile_x,
                tile_y,
                zoom,
                make_white_transparent=make_white_transparent,
            )
            done_tiles += 1

            if on_progress and (done_tiles == total_tiles or done_tiles % 10 == 0):
                on_progress(done_tiles, total_tiles)

            if tile is None:
                continue
            tms_y = (1 << zoom) - 1 - tile_y
            pending_tiles.append((zoom, tile_x, tms_y, tile))
            tile_count += 1

            if len(pending_tiles) >= 100:
                connection.executemany(
                    "INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?)",
                    pending_tiles,
                )
                pending_tiles.clear()

        if pending_tiles:
            connection.executemany(
                "INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?)",
                pending_tiles,
            )
            pending_tiles.clear()

        if tile_count == 0:
            raise GeoCampoError("MBTILES_NOT_CREATED", "No se generaron tiles para el GeoPDF.")

        metadata = {
            "name": source.stem,
            "type": "overlay",
            "version": "1.0.0",
            "description": "GeoPDF renderizado por GeoCampo",
            "format": "png",
            "scheme": "tms",
            "bounds": f"{bounds['min_lng']},{bounds['min_lat']},{bounds['max_lng']},{bounds['max_lat']}",
            "center": f"{inspection['center']['lng']},{inspection['center']['lat']},{min(max(inspection.get('default_zoom', max_zoom), min_zoom), max_zoom)}",
            "minzoom": str(min_zoom),
            "maxzoom": str(max_zoom),
        }
        connection.executemany(
            "INSERT INTO metadata (name, value) VALUES (?, ?)",
            metadata.items(),
        )
        connection.commit()
    finally:
        connection.close()

    if not destination.is_file() or destination.stat().st_size == 0:
        raise GeoCampoError("MBTILES_NOT_CREATED", "No se generó un MBTiles válido.")

    return destination, {
        "min": min_zoom,
        "max": max_zoom,
        "default": min(max(settings.GEOPDF_DEFAULT_ZOOM, min_zoom), max_zoom),
    }


def _create_schema(connection: sqlite3.Connection) -> None:
    connection.execute("CREATE TABLE metadata (name TEXT, value TEXT)")
    connection.execute(
        "CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB)"
    )
    connection.execute(
        "CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row)"
    )


def _zoom_range(bounds: dict[str, float]) -> tuple[int, int]:
    min_zoom = max(0, min(settings.GEOPDF_MIN_ZOOM, settings.GEOPDF_MAX_ZOOM))
    max_zoom = max(min_zoom, settings.GEOPDF_MAX_ZOOM)

    selected_max = min_zoom
    for zoom in range(min_zoom, max_zoom + 1):
        count = sum(1 for _ in _tiles_for_bounds(bounds, zoom))
        if count > settings.GEOPDF_MAX_GENERATED_TILES:
            break
        selected_max = zoom
    return min_zoom, selected_max


def _tiles_for_bounds(bounds: dict[str, float], zoom: int):
    n = 1 << zoom
    x_min = _lon_to_tile_x(bounds["min_lng"], zoom)
    x_max = _lon_to_tile_x(bounds["max_lng"], zoom)
    y_min = _lat_to_tile_y(bounds["max_lat"], zoom)
    y_max = _lat_to_tile_y(bounds["min_lat"], zoom)

    x_min = max(0, min(n - 1, x_min))
    x_max = max(0, min(n - 1, x_max))
    y_min = max(0, min(n - 1, y_min))
    y_max = max(0, min(n - 1, y_max))

    for x in range(x_min, x_max + 1):
        for y in range(y_min, y_max + 1):
            yield x, y


def _render_tile(
    image: Image.Image,
    control: AffineTransform,
    tile_x: int,
    tile_y: int,
    zoom: int,
    *,
    make_white_transparent: bool = True,
) -> bytes | None:
    corners = [
        _tile_corner(tile_x, tile_y, zoom, 0, 0),
        _tile_corner(tile_x, tile_y, zoom, 0, 1),
        _tile_corner(tile_x, tile_y, zoom, 1, 1),
        _tile_corner(tile_x, tile_y, zoom, 1, 0),
    ]
    source_quad = []
    for lng, lat in corners:
        point = _geo_to_pixel(lng, lat, control, image.width, image.height)
        if point is None:
            return None
        source_quad.extend(point)

    tile = image.transform(
        (TILE_SIZE, TILE_SIZE),
        Image.Transform.QUAD,
        tuple(source_quad),
        resample=Image.Resampling.BILINEAR,
        fillcolor=(255, 255, 255, 0),
    )
    if make_white_transparent:
        tile = _make_white_transparent(tile)
    if tile.getbbox() is None:
        return None

    payload = io.BytesIO()
    tile.save(payload, format="PNG", compress_level=3)
    return payload.getvalue()


def _make_white_transparent(tile: Image.Image) -> Image.Image:
    rgba = tile.convert("RGBA")
    pixels = []
    for red, green, blue, alpha in rgba.getdata():
        if (
            alpha > 0
            and red >= WHITE_ALPHA_THRESHOLD
            and green >= WHITE_ALPHA_THRESHOLD
            and blue >= WHITE_ALPHA_THRESHOLD
            and max(red, green, blue) - min(red, green, blue) <= WHITE_CHROMA_TOLERANCE
        ):
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((red, green, blue, alpha))
    rgba.putdata(pixels)
    return rgba


def clean_geopdf_render(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    component_mask = _largest_map_component_mask(rgba)
    alpha_mask = _fill_mask_holes(component_mask)
    grown_mask = alpha_mask.filter(ImageFilter.MaxFilter(MASK_GROW_RADIUS))
    pixels = []
    for (red, green, blue, alpha), keep in zip(rgba.getdata(), grown_mask.getdata(), strict=True):
        if not keep or _is_near_white(red, green, blue, alpha):
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((red, green, blue, alpha))
    rgba.putdata(pixels)
    return rgba


def clean_geopdf_render_file(path: Path) -> Path:
    with Image.open(path) as opened:
        cleaned = clean_geopdf_render(opened.convert("RGBA"))
    cleaned.save(path)
    return path


def _largest_map_component_mask(image: Image.Image) -> Image.Image:
    color_mask = Image.new("L", image.size, 0)
    mask_pixels = color_mask.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = image.getpixel((x, y))
            if _is_map_color(red, green, blue, alpha):
                mask_pixels[x, y] = 255

    closed = color_mask.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))
    mask = closed.load()
    visited = bytearray(image.width * image.height)
    best_points: list[tuple[int, int]] = []
    for y in range(image.height):
        for x in range(image.width):
            index = y * image.width + x
            if visited[index] or mask[x, y] == 0:
                continue
            points = _collect_component(mask, visited, image.width, image.height, x, y)
            if len(points) > len(best_points):
                best_points = points

    output = Image.new("L", image.size, 0)
    output_pixels = output.load()
    for x, y in best_points:
        output_pixels[x, y] = 255
    return output


def _collect_component(
    mask,
    visited: bytearray,
    width: int,
    height: int,
    start_x: int,
    start_y: int,
) -> list[tuple[int, int]]:
    queue = deque([(start_x, start_y)])
    visited[start_y * width + start_x] = 1
    points = []
    while queue:
        x, y = queue.popleft()
        points.append((x, y))
        for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if next_x < 0 or next_y < 0 or next_x >= width or next_y >= height:
                continue
            index = next_y * width + next_x
            if visited[index] or mask[next_x, next_y] == 0:
                continue
            visited[index] = 1
            queue.append((next_x, next_y))
    return points


def _fill_mask_holes(mask: Image.Image) -> Image.Image:
    width, height = mask.size
    source = mask.load()
    outside = bytearray(width * height)
    queue = deque()

    for x in range(width):
        for y in (0, height - 1):
            if source[x, y] == 0 and not outside[y * width + x]:
                outside[y * width + x] = 1
                queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            if source[x, y] == 0 and not outside[y * width + x]:
                outside[y * width + x] = 1
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if next_x < 0 or next_y < 0 or next_x >= width or next_y >= height:
                continue
            index = next_y * width + next_x
            if outside[index] or source[next_x, next_y] != 0:
                continue
            outside[index] = 1
            queue.append((next_x, next_y))

    filled = Image.new("L", mask.size, 0)
    output = filled.load()
    for y in range(height):
        for x in range(width):
            if source[x, y] != 0 or not outside[y * width + x]:
                output[x, y] = 255
    return filled


def _is_map_color(red: int, green: int, blue: int, alpha: int) -> bool:
    if alpha == 0 or _is_near_white(red, green, blue, alpha):
        return False
    value = max(red, green, blue)
    saturation = value - min(red, green, blue)
    return value >= MAP_COLOR_MIN_VALUE and saturation >= MAP_COLOR_MIN_SATURATION


def _is_near_white(red: int, green: int, blue: int, alpha: int) -> bool:
    return (
        alpha > 0
        and red >= WHITE_ALPHA_THRESHOLD
        and green >= WHITE_ALPHA_THRESHOLD
        and blue >= WHITE_ALPHA_THRESHOLD
        and max(red, green, blue) - min(red, green, blue) <= WHITE_CHROMA_TOLERANCE
    )


def _control_points(inspection: dict, width: int, height: int) -> AffineTransform:
    page_width = float(inspection["page_width"])
    page_height = float(inspection["page_height"])
    viewport = inspection.get("viewport_bbox") or {
        "min_x": 0.0,
        "min_y": 0.0,
        "max_x": page_width,
        "max_y": page_height,
    }
    viewport_x0 = float(viewport.get("x0", viewport["min_x"]))
    viewport_y0 = float(viewport.get("y0", viewport["min_y"]))
    viewport_x1 = float(viewport.get("x1", viewport["max_x"]))
    viewport_y1 = float(viewport.get("y1", viewport["max_y"]))

    points = []
    for point in inspection["control_points"][:4]:
        page_x = viewport_x0 + float(point["local_x"]) * (viewport_x1 - viewport_x0)
        pdf_y = viewport_y0 + float(point["local_y"]) * (viewport_y1 - viewport_y0)
        page_y = page_height - pdf_y
        x = page_x / page_width * width
        y = page_y / page_height * height
        points.append((x / width, y / height, float(point["lng"]), float(point["lat"])))
    if len(points) < 4:
        raise GeoCampoError(
            "PDF_WITHOUT_GEOREFERENCE",
            "El PDF no contiene suficientes puntos geoespaciales.",
            422,
        )
    return _affine_transform(points)


def _geo_to_pixel(
    lng: float,
    lat: float,
    control: AffineTransform,
    width: int,
    height: int,
) -> tuple[float, float] | None:
    x_coeffs, y_coeffs = control
    x = x_coeffs[0] * lng + x_coeffs[1] * lat + x_coeffs[2]
    y = y_coeffs[0] * lng + y_coeffs[1] * lat + y_coeffs[2]
    return x * width, y * height


def _affine_transform(points: list[tuple[float, float, float, float]]) -> AffineTransform:
    matrix = []
    target_x = []
    target_y = []
    for pixel_x, pixel_y, lng, lat in points:
        matrix.append((lng, lat, 1.0))
        target_x.append(pixel_x)
        target_y.append(pixel_y)
    return _solve_least_squares(matrix, target_x), _solve_least_squares(matrix, target_y)


def _solve_least_squares(matrix: list[tuple[float, float, float]], target: list[float]) -> tuple[float, float, float]:
    normal = [[0.0, 0.0, 0.0] for _ in range(3)]
    rhs = [0.0, 0.0, 0.0]
    for row, value in zip(matrix, target, strict=True):
        for i in range(3):
            rhs[i] += row[i] * value
            for j in range(3):
                normal[i][j] += row[i] * row[j]
    return _solve_3x3(normal, rhs)


def _solve_3x3(matrix: list[list[float]], rhs: list[float]) -> tuple[float, float, float]:
    augmented = [row[:] + [value] for row, value in zip(matrix, rhs, strict=True)]
    for column in range(3):
        pivot = max(range(column, 3), key=lambda row: abs(augmented[row][column]))
        if abs(augmented[pivot][column]) < 1e-12:
            raise GeoCampoError("INVALID_GEOREFERENCE", "No fue posible transformar los puntos del GeoPDF.", 422)
        augmented[column], augmented[pivot] = augmented[pivot], augmented[column]
        divisor = augmented[column][column]
        for index in range(column, 4):
            augmented[column][index] /= divisor
        for row in range(3):
            if row == column:
                continue
            factor = augmented[row][column]
            for index in range(column, 4):
                augmented[row][index] -= factor * augmented[column][index]
    return augmented[0][3], augmented[1][3], augmented[2][3]


def _tile_corner(tile_x: int, tile_y: int, zoom: int, x_offset: int, y_offset: int) -> tuple[float, float]:
    n = 1 << zoom
    x = tile_x + x_offset
    y = tile_y + y_offset
    lng = x / n * 360.0 - 180.0
    lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * y / n)))
    return lng, math.degrees(lat_rad)


def _lon_to_tile_x(lng: float, zoom: int) -> int:
    return int(math.floor((lng + 180.0) / 360.0 * (1 << zoom)))


def _lat_to_tile_y(lat: float, zoom: int) -> int:
    lat_rad = math.radians(max(-85.05112878, min(85.05112878, lat)))
    value = (1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * (1 << zoom)
    return int(math.floor(value))

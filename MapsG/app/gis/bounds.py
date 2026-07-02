from collections.abc import Iterable


def bounds_dict(values: Iterable[float]) -> dict[str, float]:
    min_lng, min_lat, max_lng, max_lat = [float(value) for value in values]
    if not (-180 <= min_lng <= 180 and -180 <= max_lng <= 180):
        raise ValueError("Longitudes fuera de EPSG:4326")
    if not (-90 <= min_lat <= 90 and -90 <= max_lat <= 90):
        raise ValueError("Latitudes fuera de EPSG:4326")
    return {"min_lat": min_lat, "min_lng": min_lng, "max_lat": max_lat, "max_lng": max_lng}


def union_bounds(items: list[dict[str, float]]) -> dict[str, float] | None:
    if not items:
        return None
    return {
        "min_lat": min(item["min_lat"] for item in items),
        "min_lng": min(item["min_lng"] for item in items),
        "max_lat": max(item["max_lat"] for item in items),
        "max_lng": max(item["max_lng"] for item in items),
    }


def center(bounds: dict[str, float]) -> dict[str, float]:
    return {
        "lat": (bounds["min_lat"] + bounds["max_lat"]) / 2,
        "lng": (bounds["min_lng"] + bounds["max_lng"]) / 2,
    }


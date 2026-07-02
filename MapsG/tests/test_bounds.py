import pytest

from app.gis.bounds import bounds_dict, center, union_bounds


def test_bounds_union_and_center():
    first = bounds_dict([-84.0, 10.0, -83.9, 10.1])
    second = bounds_dict([-84.2, 9.9, -83.8, 10.2])
    merged = union_bounds([first, second])
    assert merged is not None
    assert merged == {
        "min_lat": 9.9,
        "min_lng": -84.2,
        "max_lat": 10.2,
        "max_lng": -83.8,
    }
    assert center(merged) == {"lat": pytest.approx(10.05), "lng": -84.0}


def test_rejects_invalid_latitude():
    with pytest.raises(ValueError):
        bounds_dict([-84, -91, -83, 10])

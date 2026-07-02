import 'package:latlong2/latlong.dart';

String formatLatLng(double lat, double lng) {
  return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
}

bool pointInPolygon(LatLng point, List<LatLng> polygon) {
  if (polygon.length < 3) return false;

  var inside = false;
  var j = polygon.length - 1;

  for (var i = 0; i < polygon.length; i++) {
    final xi = polygon[i].longitude;
    final yi = polygon[i].latitude;
    final xj = polygon[j].longitude;
    final yj = polygon[j].latitude;

    final intersect =
        ((yi > point.latitude) != (yj > point.latitude)) &&
        (point.longitude <
            (xj - xi) *
                    (point.latitude - yi) /
                    ((yj - yi) == 0 ? 0.0000001 : (yj - yi)) +
                xi);

    if (intersect) inside = !inside;
    j = i;
  }

  return inside;
}

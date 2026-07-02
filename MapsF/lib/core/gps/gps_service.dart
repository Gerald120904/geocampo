import 'package:geolocator/geolocator.dart';

import '../../models/current_location.dart';

class GpsService {
  Future<CurrentLocation> getCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('El GPS está desactivado.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado.');
    }

    final position = await Geolocator.getCurrentPosition();
    return CurrentLocation(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
    );
  }
}

import '../../models/current_location.dart';

class GpsState {
  const GpsState({required this.loading, this.location, this.error});

  final bool loading;
  final CurrentLocation? location;
  final String? error;
}

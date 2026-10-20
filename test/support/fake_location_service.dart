import 'package:attendance/core/location/location_service.dart';

class FakeLocationService implements LocationService {
  FakeLocationService({
    this.reading = const LocationReading(
      latitude: 12.971599,
      longitude: 77.594566,
      accuracyMeters: 8,
    ),
    this.error,
  });

  LocationReading reading;
  Object? error;
  int calls = 0;

  @override
  Future<LocationReading> currentPosition() async {
    calls++;
    if (error != null) throw error!;
    return reading;
  }
}

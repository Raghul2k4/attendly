import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../errors/app_exception.dart';

/// A single foreground location reading. Accuracy is the radius (in metres)
/// reported by the platform; the server decides whether it is acceptable.
class LocationReading {
  const LocationReading({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

/// Thin, injectable boundary over geolocation so punch flows are testable
/// without platform channels.
abstract class LocationService {
  Future<LocationReading> currentPosition();
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationReading> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const AppException(
          'Turn on Android location services, then try again.',
          kind: AppErrorKind.permission,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const AppException(
          'Location permission is blocked. Allow it in Android Settings, '
          'then try again.',
          kind: AppErrorKind.permission,
        );
      }
      if (permission == LocationPermission.denied) {
        throw const AppException(
          'Location permission is needed to verify attendance. Allow it and '
          'try again.',
          kind: AppErrorKind.permission,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          !position.accuracy.isFinite ||
          position.accuracy < 0) {
        throw const AppException(
          'We couldn’t read a valid location. Try again in a moment.',
        );
      }

      return LocationReading(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException(
        'We couldn’t get a fresh location. Step outside or near a window and '
        'try again.',
      );
    } on LocationServiceDisabledException {
      throw const AppException(
        'Turn on Android location services, then try again.',
        kind: AppErrorKind.permission,
      );
    } on PermissionDeniedException {
      throw const AppException(
        'Location permission is needed to verify attendance. Allow it and '
        'try again.',
        kind: AppErrorKind.permission,
      );
    } catch (error) {
      throw AppException(
        'We couldn’t read your location. Try again.',
        cause: error,
      );
    }
  }
}

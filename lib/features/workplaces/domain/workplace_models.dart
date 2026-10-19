/// Workplace (geofence) domain models. Coordinates and radius come from the
/// server; the client never invents or rounds them for storage.
class Workplace {
  const Workplace({
    required this.id,
    required this.organisationId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
  });

  factory Workplace.fromRow(Map<String, dynamic> row) => Workplace(
    id: row['id'] as String,
    organisationId: row['organisation_id'] as String,
    name: (row['name'] as String).trim(),
    latitude: _toDouble(row['latitude']),
    longitude: _toDouble(row['longitude']),
    radiusMeters: (row['radius_meters'] as num).toInt(),
    isActive: row['is_active'] as bool? ?? true,
  );

  final String id;
  final String organisationId;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isActive;

  String get coordinateLabel =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

/// Metadata for a workplace's live QR token. The raw payload and its hash are
/// never part of this model.
class WorkplaceQrStatus {
  const WorkplaceQrStatus({required this.workplaceId, required this.createdAt});

  factory WorkplaceQrStatus.fromRow(Map<String, dynamic> row) =>
      WorkplaceQrStatus(
        workplaceId: row['workplace_id'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  final String workplaceId;
  final DateTime createdAt;
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw FormatException('Unexpected coordinate value: $value');
}

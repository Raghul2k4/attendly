import 'package:attendance/features/workplaces/domain/workplace_models.dart';

/// Obviously-fake workplace rows shaped like server responses.
Workplace testWorkplace({
  String id = 'wp-1',
  String organisationId = 'org-1',
  String name = 'Main shop',
  double latitude = 12.971599,
  double longitude = 77.594566,
  int radiusMeters = 100,
  bool isActive = true,
}) => Workplace(
  id: id,
  organisationId: organisationId,
  name: name,
  latitude: latitude,
  longitude: longitude,
  radiusMeters: radiusMeters,
  isActive: isActive,
);

WorkplaceQrStatus testQrStatus({
  String workplaceId = 'wp-1',
  DateTime? createdAt,
}) => WorkplaceQrStatus(
  workplaceId: workplaceId,
  createdAt: createdAt ?? DateTime.utc(2026, 10, 19, 9, 30),
);

import 'package:attendance/features/workplaces/data/workplace_repository.dart';
import 'package:attendance/features/workplaces/domain/workplace_models.dart';

/// Deterministic WorkplaceRepository fake: scripts rows/errors and records the
/// calls made by screens. No Supabase or map tiles involved.
class FakeWorkplaceRepository implements WorkplaceRepository {
  FakeWorkplaceRepository({
    List<Workplace>? workplaces,
    Map<String, WorkplaceQrStatus>? qrStatuses,
    this.generateResult = 'attendance:workplace:v1:ABCDE-FGHJK-MNPQR-STUVW',
    this.fetchError,
    this.qrStatusError,
    this.createError,
    this.updateError,
    this.generateError,
    this.revokeError,
  }) : workplaces = workplaces ?? const [],
       qrStatuses = qrStatuses ?? const {};

  List<Workplace> workplaces;
  Map<String, WorkplaceQrStatus> qrStatuses;
  String generateResult;

  Object? fetchError;
  Object? qrStatusError;
  Object? createError;
  Object? updateError;
  Object? generateError;
  Object? revokeError;

  int fetchCalls = 0;
  int qrStatusCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int generateCalls = 0;
  int revokeCalls = 0;

  String? lastOrgId;
  String? lastWorkplaceId;
  String? lastName;
  double? lastLatitude;
  double? lastLongitude;
  int? lastRadius;
  bool? lastIsActive;

  @override
  Future<List<Workplace>> fetchWorkplaces(String organisationId) async {
    fetchCalls++;
    lastOrgId = organisationId;
    if (fetchError != null) throw fetchError!;
    return workplaces;
  }

  @override
  Future<Workplace> createWorkplace({
    required String organisationId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    createCalls++;
    lastOrgId = organisationId;
    lastName = name;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastRadius = radiusMeters;
    if (createError != null) throw createError!;
    return Workplace(
      id: 'wp-new',
      organisationId: organisationId,
      name: name.trim(),
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      isActive: true,
    );
  }

  @override
  Future<Workplace> updateWorkplace({
    required String organisationId,
    required String workplaceId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required bool isActive,
  }) async {
    updateCalls++;
    lastOrgId = organisationId;
    lastWorkplaceId = workplaceId;
    lastName = name;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastRadius = radiusMeters;
    lastIsActive = isActive;
    if (updateError != null) throw updateError!;
    return Workplace(
      id: workplaceId,
      organisationId: organisationId,
      name: name.trim(),
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      isActive: isActive,
    );
  }

  @override
  Future<Map<String, WorkplaceQrStatus>> fetchQrStatuses(
    String organisationId,
  ) async {
    qrStatusCalls++;
    lastOrgId = organisationId;
    if (qrStatusError != null) throw qrStatusError!;
    return qrStatuses;
  }

  @override
  Future<String> generateQr({
    required String organisationId,
    required String workplaceId,
  }) async {
    generateCalls++;
    lastOrgId = organisationId;
    lastWorkplaceId = workplaceId;
    if (generateError != null) throw generateError!;
    qrStatuses = {
      ...qrStatuses,
      workplaceId: WorkplaceQrStatus(
        workplaceId: workplaceId,
        createdAt: DateTime.utc(2026, 10, 19, 9, 30),
      ),
    };
    return generateResult;
  }

  @override
  Future<void> revokeQr({
    required String organisationId,
    required String workplaceId,
  }) async {
    revokeCalls++;
    lastOrgId = organisationId;
    lastWorkplaceId = workplaceId;
    if (revokeError != null) throw revokeError!;
    qrStatuses = {...qrStatuses}..remove(workplaceId);
  }
}

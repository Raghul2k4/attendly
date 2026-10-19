import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../domain/workplace_models.dart';

/// Data access for workplace geofences and their QR codes.
///
/// Workplace rows are written directly under owner-only RLS (single-row
/// operations, validated by table constraints). QR operations go through
/// owner-checked definer RPCs because the raw token must be returned exactly
/// once and the stored hash must never be readable.
abstract class WorkplaceRepository {
  Future<List<Workplace>> fetchWorkplaces(String organisationId);

  Future<Workplace> createWorkplace({
    required String organisationId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
  });

  Future<Workplace> updateWorkplace({
    required String organisationId,
    required String workplaceId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required bool isActive,
  });

  Future<Map<String, WorkplaceQrStatus>> fetchQrStatuses(String organisationId);

  /// Returns the full QR payload. The server keeps only a hash; this value is
  /// the only copy the client will ever see.
  Future<String> generateQr({
    required String organisationId,
    required String workplaceId,
  });

  Future<void> revokeQr({
    required String organisationId,
    required String workplaceId,
  });
}

class SupabaseWorkplaceRepository implements WorkplaceRepository {
  SupabaseWorkplaceRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, organisation_id, name, latitude, longitude, radius_meters, '
      'is_active';

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, st) {
      Error.throwWithStackTrace(mapBackendError(error), st);
    }
  }

  @override
  Future<List<Workplace>> fetchWorkplaces(String organisationId) =>
      _guard(() async {
        final rows = await _client
            .from('workplaces')
            .select(_columns)
            .eq('organisation_id', organisationId)
            .order('created_at');
        return rows.map(Workplace.fromRow).toList(growable: false);
      });

  @override
  Future<Workplace> createWorkplace({
    required String organisationId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) => _guard(() async {
    final row = await _client
        .from('workplaces')
        .insert({
          'organisation_id': organisationId,
          'name': name.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'radius_meters': radiusMeters,
        })
        .select(_columns)
        .single();
    return Workplace.fromRow(row);
  });

  @override
  Future<Workplace> updateWorkplace({
    required String organisationId,
    required String workplaceId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required bool isActive,
  }) => _guard(() async {
    final row = await _client
        .from('workplaces')
        .update({
          'name': name.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'radius_meters': radiusMeters,
          'is_active': isActive,
        })
        .eq('id', workplaceId)
        .eq('organisation_id', organisationId)
        .select(_columns)
        .single();
    return Workplace.fromRow(row);
  });

  @override
  Future<Map<String, WorkplaceQrStatus>> fetchQrStatuses(
    String organisationId,
  ) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'list_workplace_qr_statuses',
      params: {'p_org': organisationId},
    );
    return {
      for (final row in rows)
        (row as Map)['workplace_id'] as String: WorkplaceQrStatus.fromRow(
          row.cast<String, dynamic>(),
        ),
    };
  });

  @override
  Future<String> generateQr({
    required String organisationId,
    required String workplaceId,
  }) => _guard(
    () async => await _client.rpc<String>(
      'generate_workplace_qr',
      params: {'p_org': organisationId, 'p_workplace': workplaceId},
    ),
  );

  @override
  Future<void> revokeQr({
    required String organisationId,
    required String workplaceId,
  }) => _guard(
    () async => await _client.rpc<void>(
      'revoke_workplace_qr',
      params: {'p_org': organisationId, 'p_workplace': workplaceId},
    ),
  );
}

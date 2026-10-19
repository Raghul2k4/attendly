import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart' show supabaseClientProvider;
import '../data/workplace_repository.dart';
import '../domain/workplace_models.dart';

final workplaceRepositoryProvider = Provider<WorkplaceRepository>(
  (ref) => SupabaseWorkplaceRepository(ref.watch(supabaseClientProvider)),
);

final workplacesProvider = FutureProvider.autoDispose
    .family<List<Workplace>, String>(
      (ref, organisationId) => ref
          .watch(workplaceRepositoryProvider)
          .fetchWorkplaces(organisationId),
    );

/// Live QR metadata by workplace id. Absence means no printable QR currently
/// works. Fetch failures are non-fatal for the list screen.
final qrStatusesProvider = FutureProvider.autoDispose
    .family<Map<String, WorkplaceQrStatus>, String>(
      (ref, organisationId) => ref
          .watch(workplaceRepositoryProvider)
          .fetchQrStatuses(organisationId),
    );

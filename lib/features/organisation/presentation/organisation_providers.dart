import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../auth/data/auth_repository.dart' show supabaseClientProvider;
import '../../auth/presentation/auth_controller.dart';
import '../data/organisation_repository.dart';
import '../domain/organisation_models.dart';

/// Single data source for organisation/membership operations. Overridden in
/// widget tests with a fake; production talks to Supabase through RLS/RPCs.
final organisationRepositoryProvider = Provider<OrganisationRepository>(
  (ref) => SupabaseOrganisationRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's membership (or null before they create/join an
/// organisation). Recomputed when auth changes and invalidated after any
/// mutation that affects membership or seat counts.
final myAccountProvider = FutureProvider<MyAccount?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isSignedIn) return null;
  return ref.watch(organisationRepositoryProvider).fetchMyAccount();
});

/// Staff rows for an organisation. RLS decides what the caller may see; the
/// owner receives every member, employees only their own row.
final staffProvider = FutureProvider.autoDispose
    .family<List<Membership>, String>(
      (ref, organisationId) => ref
          .watch(organisationRepositoryProvider)
          .fetchMembers(organisationId),
    );

/// IANA zone reported by the platform (Android returns e.g. Asia/Kolkata).
/// Falling back to UTC keeps organisation creation possible when a platform
/// channel is unavailable — the owner can always pick another zone.
final deviceTimezoneProvider = FutureProvider<String>((ref) async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  } catch (_) {
    return 'UTC';
  }
});

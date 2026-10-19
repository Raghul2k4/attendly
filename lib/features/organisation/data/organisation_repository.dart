import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../domain/organisation_models.dart';

/// Data access for organisations and memberships. The UI depends on this
/// abstraction so widget tests drive real flows with a fake.
abstract class OrganisationRepository {
  /// Current user's membership with org + plan, or null when they haven't
  /// joined/created one yet.
  Future<MyAccount?> fetchMyAccount();

  /// All members of an organisation (owner-visible; RLS enforces it).
  Future<List<Membership>> fetchMembers(String organisationId);

  Future<String> createOrganisation({
    required String name,
    required String timezone,
  });

  Future<InviteResult> inviteEmployee({
    required String organisationId,
    required String fullName,
  });

  Future<String> claimMembership(String inviteToken);

  Future<void> setMemberStatus({
    required String organisationId,
    required String memberId,
    required bool active,
  });
}

class SupabaseOrganisationRepository implements OrganisationRepository {
  SupabaseOrganisationRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, st) {
      Error.throwWithStackTrace(mapBackendError(error), st);
    }
  }

  @override
  Future<MyAccount?> fetchMyAccount() => _guard(() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final memberRow = await _client
        .from('organisation_members')
        .select(
          'id, organisation_id, user_id, role, status, full_name, employee_code',
        )
        .eq('user_id', uid)
        .maybeSingle();
    if (memberRow == null) return null;

    final membership = Membership.fromRow(memberRow);

    final orgRow = await _client
        .from('organisations')
        .select('id, name, timezone, plan_id')
        .eq('id', membership.organisationId)
        .maybeSingle();
    if (orgRow == null) return MyAccount(membership: membership);

    final organisation = Organisation.fromRow(orgRow);

    final planRow = await _client
        .from('subscription_plans')
        .select('plan_id, display_name, max_active_employees')
        .eq('plan_id', organisation.planId)
        .maybeSingle();

    return MyAccount(
      membership: membership,
      organisation: organisation,
      plan: planRow == null ? null : PlanInfo.fromRow(planRow),
    );
  });

  @override
  Future<List<Membership>> fetchMembers(String organisationId) =>
      _guard(() async {
        final rows = await _client
            .from('organisation_members')
            .select(
              'id, organisation_id, user_id, role, status, full_name, employee_code',
            )
            .eq('organisation_id', organisationId)
            .order('created_at');
        return rows.map(Membership.fromRow).toList(growable: false);
      });

  @override
  Future<String> createOrganisation({
    required String name,
    required String timezone,
  }) => _guard(
    () async => await _client.rpc<String>(
      'create_organisation',
      params: {
        'p_name': name.trim(),
        'p_timezone': timezone,
        'p_plan_id': 'free',
      },
    ),
  );

  @override
  Future<InviteResult> inviteEmployee({
    required String organisationId,
    required String fullName,
  }) => _guard(() async {
    final response = await _client.rpc<List<dynamic>>(
      'invite_employee',
      params: {'p_org': organisationId, 'p_full_name': fullName.trim()},
    );
    final row = (response.first as Map).cast<String, dynamic>();
    return InviteResult.fromRow(row, employeeName: fullName.trim());
  });

  @override
  Future<String> claimMembership(String inviteToken) => _guard(
    () async => await _client.rpc<String>(
      'claim_membership',
      params: {'p_invite_token': inviteToken},
    ),
  );

  @override
  Future<void> setMemberStatus({
    required String organisationId,
    required String memberId,
    required bool active,
  }) => _guard(
    () async => await _client.rpc<void>(
      'set_member_status',
      params: {
        'p_org': organisationId,
        'p_member': memberId,
        'p_status': active ? 'active' : 'inactive',
      },
    ),
  );
}

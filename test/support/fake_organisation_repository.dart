import 'package:attendance/features/organisation/data/organisation_repository.dart';
import 'package:attendance/features/organisation/domain/organisation_models.dart';

/// Deterministic OrganisationRepository fake: tests script the data and
/// errors, then assert the calls screens made. No Supabase involved.
class FakeOrganisationRepository implements OrganisationRepository {
  FakeOrganisationRepository({
    this.account,
    this.members = const [],
    this.inviteResult,
    this.createResult = 'org-1',
    this.claimResult = 'org-1',
    this.fetchAccountError,
    this.fetchMembersError,
    this.createError,
    this.inviteError,
    this.claimError,
    this.statusError,
  });

  MyAccount? account;
  List<Membership> members;
  InviteResult? inviteResult;
  String createResult;
  String claimResult;

  Object? fetchAccountError;
  Object? fetchMembersError;
  Object? createError;
  Object? inviteError;
  Object? claimError;
  Object? statusError;

  int fetchAccountCalls = 0;
  int fetchMembersCalls = 0;
  int createCalls = 0;
  int inviteCalls = 0;
  int claimCalls = 0;
  int statusCalls = 0;

  String? lastMembersOrganisationId;
  String? lastCreateName;
  String? lastCreateTimezone;
  String? lastInviteName;
  String? lastClaimToken;
  String? lastStatusMemberId;
  bool? lastStatusActive;

  @override
  Future<MyAccount?> fetchMyAccount() async {
    fetchAccountCalls++;
    if (fetchAccountError != null) throw fetchAccountError!;
    return account;
  }

  @override
  Future<List<Membership>> fetchMembers(String organisationId) async {
    fetchMembersCalls++;
    lastMembersOrganisationId = organisationId;
    if (fetchMembersError != null) throw fetchMembersError!;
    return members;
  }

  @override
  Future<String> createOrganisation({
    required String name,
    required String timezone,
  }) async {
    createCalls++;
    lastCreateName = name;
    lastCreateTimezone = timezone;
    if (createError != null) throw createError!;
    return createResult;
  }

  @override
  Future<InviteResult> inviteEmployee({
    required String organisationId,
    required String fullName,
  }) async {
    inviteCalls++;
    lastInviteName = fullName;
    if (inviteError != null) throw inviteError!;
    final result = inviteResult;
    if (result == null) {
      throw StateError('FakeOrganisationRepository.inviteResult not set');
    }
    return result;
  }

  @override
  Future<String> claimMembership(String inviteToken) async {
    claimCalls++;
    lastClaimToken = inviteToken;
    if (claimError != null) throw claimError!;
    return claimResult;
  }

  @override
  Future<void> setMemberStatus({
    required String organisationId,
    required String memberId,
    required bool active,
  }) async {
    statusCalls++;
    lastStatusMemberId = memberId;
    lastStatusActive = active;
    if (statusError != null) throw statusError!;
  }
}

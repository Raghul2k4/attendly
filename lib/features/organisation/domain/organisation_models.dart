/// Domain models for organisations and memberships. Only plain data —
/// server-authoritative fields are mapped as-is, never recomputed.
enum MemberRole { owner, employee }

enum MemberStatus { invited, active, inactive }

MemberRole _roleFrom(Object? value) =>
    value == 'owner' ? MemberRole.owner : MemberRole.employee;

MemberStatus _statusFrom(Object? value) => switch (value) {
  'active' => MemberStatus.active,
  'invited' => MemberStatus.invited,
  _ => MemberStatus.inactive,
};

class Organisation {
  const Organisation({
    required this.id,
    required this.name,
    required this.timezone,
    required this.planId,
  });

  factory Organisation.fromRow(Map<String, dynamic> row) => Organisation(
    id: row['id'] as String,
    name: row['name'] as String,
    timezone: row['timezone'] as String? ?? 'UTC',
    planId: row['plan_id'] as String? ?? 'free',
  );

  final String id;
  final String name;
  final String timezone;
  final String planId;

  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

class PlanInfo {
  const PlanInfo({
    required this.planId,
    required this.displayName,
    required this.maxActiveEmployees,
  });

  factory PlanInfo.fromRow(Map<String, dynamic> row) => PlanInfo(
    planId: row['plan_id'] as String,
    displayName: row['display_name'] as String? ?? 'Free',
    maxActiveEmployees: (row['max_active_employees'] as num?)?.toInt(),
  );

  final String planId;
  final String displayName;

  /// Null means the plan has no staff limit (the free plan). Kept nullable so
  /// a future paid plan can impose one without a schema change.
  final int? maxActiveEmployees;

  bool get hasStaffLimit => maxActiveEmployees != null;
}

class Membership {
  const Membership({
    required this.id,
    required this.organisationId,
    required this.userId,
    required this.role,
    required this.status,
    required this.fullName,
    required this.employeeCode,
  });

  factory Membership.fromRow(Map<String, dynamic> row) => Membership(
    id: row['id'] as String,
    organisationId: row['organisation_id'] as String,
    userId: row['user_id'] as String?,
    role: _roleFrom(row['role']),
    status: _statusFrom(row['status']),
    fullName: (row['full_name'] as String?) ?? 'Employee',
    employeeCode: row['employee_code'] as String?,
  );

  final String id;
  final String organisationId;
  final String? userId;
  final MemberRole role;
  final MemberStatus status;
  final String fullName;
  final String? employeeCode;

  bool get isOwner => role == MemberRole.owner;
  bool get isActive => status == MemberStatus.active;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Everything the signed-in user needs to be routed: their membership plus
/// the organisation and plan they belong to (null when not yet visible).
class MyAccount {
  const MyAccount({required this.membership, this.organisation, this.plan});

  final Membership membership;
  final Organisation? organisation;
  final PlanInfo? plan;
}

class InviteResult {
  const InviteResult({
    required this.memberId,
    required this.employeeCode,
    required this.inviteToken,
    required this.employeeName,
  });

  factory InviteResult.fromRow(
    Map<String, dynamic> row, {
    required String employeeName,
  }) => InviteResult(
    memberId: row['member_id'] as String,
    employeeCode: row['employee_code'] as String,
    inviteToken: row['invite_token'] as String,
    employeeName: employeeName,
  );

  final String memberId;
  final String employeeCode;

  /// One-time claim secret — the server keeps only its hash. Shown once.
  final String inviteToken;
  final String employeeName;
}

/// Derived staffing numbers for the owner dashboard (regular counts, not
/// attendance metrics).
extension StaffSummary on List<Membership> {
  int get activeEmployees => where(
    (m) => m.role == MemberRole.employee && m.status == MemberStatus.active,
  ).length;

  int get pendingInvites =>
      where((m) => m.status == MemberStatus.invited).length;

  Membership? get ownerMember {
    for (final member in this) {
      if (member.isOwner) return member;
    }
    return null;
  }
}

import 'package:attendance/features/organisation/domain/organisation_models.dart';

/// Shared, obviously-fake fixtures for organisation widget tests. Values are
/// shaped like real rows so parsing/formatting paths are exercised.
const testOrganisation = Organisation(
  id: 'org-1',
  name: 'Corner Cafe',
  timezone: 'Asia/Kolkata',
  planId: 'free',
);

const testFreePlan = PlanInfo(
  planId: 'free',
  displayName: 'Free',
  maxActiveEmployees: null,
);

Membership testMember({
  String id = 'm-1',
  String? userId = 'u-1',
  MemberRole role = MemberRole.employee,
  MemberStatus status = MemberStatus.active,
  String fullName = 'Priya Sharma',
  String? employeeCode = 'ABCD-EFGH',
}) => Membership(
  id: id,
  organisationId: testOrganisation.id,
  userId: userId,
  role: role,
  status: status,
  fullName: fullName,
  employeeCode: employeeCode,
);

MyAccount testOwnerAccount({
  Organisation organisation = testOrganisation,
  PlanInfo plan = testFreePlan,
}) => MyAccount(
  membership: testMember(
    id: 'm-owner',
    userId: 'u-owner',
    role: MemberRole.owner,
    fullName: 'Ada Owner',
    employeeCode: null,
  ),
  organisation: organisation,
  plan: plan,
);

MyAccount testEmployeeAccount({
  String fullName = 'Priya Sharma',
  String? employeeCode = 'ABCD-EFGH',
  Organisation organisation = testOrganisation,
  PlanInfo plan = testFreePlan,
}) => MyAccount(
  membership: testMember(fullName: fullName, employeeCode: employeeCode),
  organisation: organisation,
  plan: plan,
);

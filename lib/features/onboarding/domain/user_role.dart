/// Onboarding-time intent ("I own a business" vs "I am an employee").
/// Never used for authorization — the database decides what's allowed.
enum UserRole { owner, employee }

extension UserRoleCopy on UserRole {
  String get label => this == UserRole.owner ? 'Owner' : 'Employee';

  String get signUpSubtitle => this == UserRole.owner
      ? 'Create an account to set up your organisation.'
      : 'Create an account, then enter the staff code from your owner.';
}

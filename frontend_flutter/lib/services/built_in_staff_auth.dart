import '../models/app_user.dart';

/// Temporary built-in dashboard accounts (no Supabase row). Tier is sent to backend via header.
enum BuiltInStaffTier { none, admin, superAdmin }

BuiltInStaffTier matchBuiltInStaff(String identifier, String password) {
  final id = identifier.trim().toLowerCase();
  final pw = password;
  if (id == 'admin' && pw == 'admin123') {
    return BuiltInStaffTier.admin;
  }
  if (id == 'superadmin' && pw == 'admin321') {
    return BuiltInStaffTier.superAdmin;
  }
  return BuiltInStaffTier.none;
}

String builtInStaffTierHeaderValue(BuiltInStaffTier tier) {
  switch (tier) {
    case BuiltInStaffTier.admin:
      return 'admin';
    case BuiltInStaffTier.superAdmin:
      return 'super';
    case BuiltInStaffTier.none:
      return '';
  }
}

AppUser syntheticStaffProfile(BuiltInStaffTier tier) {
  switch (tier) {
    case BuiltInStaffTier.admin:
      return const AppUser(
        id: '00000000-0000-4000-8000-000000000001',
        email: 'built-in-admin@airs.local',
        username: 'Admin',
        role: 'Admin',
      );
    case BuiltInStaffTier.superAdmin:
      return const AppUser(
        id: '00000000-0000-4000-8000-000000000002',
        email: 'built-in-superadmin@airs.local',
        username: 'Superadmin',
        role: 'Super Administrator',
      );
    case BuiltInStaffTier.none:
      throw StateError('No synthetic profile for none tier');
  }
}

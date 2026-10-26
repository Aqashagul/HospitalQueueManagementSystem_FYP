import 'package:shared_preferences/shared_preferences.dart';


enum UserRole { admin, doctor, patient }

UserRole? roleFromString(String? value) {
  for (final r in UserRole.values) {
    if (r.name == value) return r;
  }
  return null;
}

/// Mirrors the Firestore document at users/{uid}.
class AppUser {
  const AppUser({
    required this.uid,
    required this.role,
    this.doctorId,
    this.disabled = false,
  });

  final String uid;
  final UserRole role;
  final String? doctorId; // only set when role == doctor

  /// True when the admin has cancelled the invitation or removed this
  /// doctor's access. A disabled user cannot open the app.
  final bool disabled;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      role: roleFromString(map['role'] as String?) ?? UserRole.patient,
      doctorId: map['doctorId'] as String?,
      disabled: map['disabled'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'role': role.name,
        if (doctorId != null) 'doctorId': doctorId,
        'disabled': disabled,
      };
}

/// Remembers the Patient/Doctor choice so the selection screen
/// is only shown on the very first open.
/// NOTE: this is UI convenience only. Real security = Firestore role + rules.
class RoleStorage {
  static const _key = 'selected_role';

  static Future<UserRole?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return roleFromString(prefs.getString(_key));
  }

  static Future<void> save(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, role.name);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
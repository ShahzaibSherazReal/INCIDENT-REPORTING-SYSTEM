class AppUser {
  final String id;
  final String email;
  final String? username;
  final String role;

  const AppUser({
    required this.id,
    required this.email,
    this.username,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username']?.toString(),
      role: json['role'] as String,
    );
  }
}

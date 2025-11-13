class UserProfile {
  const UserProfile({
    required this.username,
    required this.role,
    this.userId,
  });

  final String username;
  final String role;
  final int? userId;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: (json['username'] ?? json['name'] ?? '') as String,
      role: (json['role'] ?? json['roleName'] ?? '') as String,
      userId: json['id'] is num
          ? (json['id'] as num).toInt()
          : json['userId'] as int?,
    );
  }

  String get normalizedRole => role.toLowerCase().replaceAll(' ', '_');
}

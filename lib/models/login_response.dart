class LoginResponse {
  final int? userId;
  final String username;
  final String role;

  const LoginResponse({this.userId, required this.username, required this.role});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final String? rawRole = (json['role'] ?? json['roleName']) as String?;
    return LoginResponse(
      userId: json['id'] is num ? (json['id'] as num).toInt() : json['userId'] as int?,
      username: (json['username'] ?? json['name'] ?? '') as String,
      role: rawRole ?? 'user',
    );
  }

  String get normalizedRole => role.toLowerCase().replaceAll(' ', '_');
}

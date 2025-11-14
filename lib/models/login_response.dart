class LoginResponse {
  final int? userId;
  final String username;
  final String role;

  const LoginResponse({this.userId, required this.username, required this.role});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      userId: json['id'] is num
          ? (json['id'] as num).toInt()
          : json['userId'] is num
              ? (json['userId'] as num).toInt()
              : null,
      username: (json['username'] ?? json['name'] ?? '') as String,
      role: (json['role'] ?? json['roleName'] ?? 'user') as String,
    );
  }
}

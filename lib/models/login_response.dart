class LoginResponse {
  final String username;
  final String role;

  LoginResponse({required this.username, required this.role});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      username: json['username'] as String,
      role: json['role'] as String,
    );
  }
}

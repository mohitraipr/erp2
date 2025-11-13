import 'package:flutter/foundation.dart';

import '../models/login_response.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';

class AuthController extends ChangeNotifier {
  final ApiService apiService;

  LoginResponse? _user;
  bool _isLoading = false;
  String? _error;

  AuthController(this.apiService);

  LoginResponse? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _error;

  Future<LoginResponse> login(String username, String password) async {
    if (_isLoading) throw StateError('Login already in progress');
    _setLoading(true);
    try {
      final response = await apiService.login(username: username, password: password);
      _user = response;
      _error = null;
      notifyListeners();
      return response;
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void logout() {
    apiService.clearSession();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void handleUnauthorized() {
    logout();
  }

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }
}

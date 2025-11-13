import 'package:flutter/foundation.dart';

import '../models/login_response.dart';
import '../services/api_client.dart';

class SessionController extends ChangeNotifier {
  SessionController({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;
  LoginResponse? _user;
  bool _loading = false;
  String? _error;

  LoginResponse? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _loading;
  String? get error => _error;
  String get baseUrl => _api.baseUrl;

  ApiClient get api => _api;

  String get normalizedRole => _user?.normalizedRole ?? '';

  bool get isCuttingManager =>
      normalizedRole == 'cutting_manager' || normalizedRole == 'cutting_master';

  bool get isOperator => normalizedRole == 'operator';

  bool get canManageMasters =>
      normalizedRole == 'back_pocket' ||
      normalizedRole == 'stitching_master' ||
      normalizedRole == 'jeans_assembly';

  bool get isBackPocketOrStitching =>
      normalizedRole == 'back_pocket' || normalizedRole == 'stitching_master';

  bool get isJeansAssembly => normalizedRole == 'jeans_assembly';

  bool get isWashing => normalizedRole == 'washing';

  bool get isWashingIn => normalizedRole == 'washing_in';

  bool get isFinishing => normalizedRole == 'finishing';

  Future<void> login(String username, String password) async {
    _setLoading(true);
    notifyListeners();
    _error = null;
    try {
      final response = await _api.login(username: username, password: password);
      _user = response;
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void setBaseUrl(String value) {
    _api.updateBaseUrl(value);
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_loading != value) {
      _loading = value;
    }
  }
}

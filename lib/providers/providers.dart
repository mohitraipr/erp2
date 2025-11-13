import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  final UserProfile? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => user != null;
  String? get role => user?.normalizedRole;

  AuthState copyWith({
    UserProfile? user,
    bool? isLoading,
    String? errorMessage,
    bool resetError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: resetError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState());

  final ErpRepository _repository;

  Future<bool> login({required String username, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, resetError: true);
    try {
      final user = await _repository.login(username, password);
      state = AuthState(user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message, resetError: true);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
        resetError: true,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }

  Future<void> handleUnauthorized(String message) async {
    await _repository.logout();
    state = AuthState(errorMessage: message);
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig());

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ApiClient(baseUrl: config.baseUrl);
  ref.onDispose(() {
    // Clear cookies on dispose to avoid leaking sessions between app instances.
    unawaited(client.clearCookies());
  });
  return client;
});

final erpRepositoryProvider = Provider<ErpRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ErpRepository(client);
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(erpRepositoryProvider);
  return AuthController(repository);
});

Future<T> performApiCall<T>(WidgetRef ref, Future<T> Function(ErpRepository repo) action) async {
  final repository = ref.read(erpRepositoryProvider);
  try {
    return await action(repository);
  } on UnauthorizedException catch (e) {
    await ref.read(authControllerProvider.notifier).handleUnauthorized(e.message);
    rethrow;
  }
}

import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../utils/constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final Dio _dio;
  final CookieJar _cookieJar;

  ApiClient._(this._dio, this._cookieJar);

  factory ApiClient({String? baseUrl}) {
    final normalizedBaseUrl = (baseUrl ?? defaultBaseUrl).trim();
    final dio = Dio(
      BaseOptions(
        baseUrl: normalizedBaseUrl.endsWith('/')
            ? normalizedBaseUrl.substring(0, normalizedBaseUrl.length - 1)
            : normalizedBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json, text/plain, */*',
        },
      ),
    );
    final jar = CookieJar();
    dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) => handler.next(response),
        onError: (error, handler) => handler.next(error),
      ),
    );
    return ApiClient._(dio, jar);
  }

  String get baseUrl => _dio.options.baseUrl;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: query,
        options: options,
      );
      _ensureSuccess(response);
      return response;
    } on DioException catch (error) {
      throw _wrapError(error);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: query,
        options: options,
      );
      _ensureSuccess(response);
      return response;
    } on DioException catch (error) {
      throw _wrapError(error);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: query,
        options: options,
      );
      _ensureSuccess(response);
      return response;
    } on DioException catch (error) {
      throw _wrapError(error);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: query,
        options: options,
      );
      _ensureSuccess(response);
      return response;
    } on DioException catch (error) {
      throw _wrapError(error);
    }
  }

  void clearSession() {
    _cookieJar.deleteAll();
  }

  ApiException _wrapError(DioException error) {
    final response = error.response;
    if (response == null) {
      final message = error.message ?? 'Network error. Please try again.';
      return ApiException(message);
    }

    String? message;
    final data = response.data;
    if (data is Map<String, dynamic>) {
      message = _extractMessage(data);
    } else if (data is String) {
      message = data.trim().isEmpty ? null : data.trim();
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          message = _extractMessage(decoded) ?? message;
        }
      } catch (_) {}
    }

    message ??= 'Request failed with status ${response.statusCode}.';
    return ApiException(message, statusCode: response.statusCode);
  }

  void _ensureSuccess(Response response) {
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw _wrapError(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        ),
      );
    }
  }

  static String? _extractMessage(Map<String, dynamic> json) {
    final possibleKeys = [
      'error',
      'message',
      'detail',
      'msg',
      'reason',
    ];

    for (final key in possibleKeys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is Map<String, dynamic>) {
        final nested = _extractMessage(value);
        if (nested != null) return nested;
      }
      if (value is List) {
        for (final item in value) {
          if (item is String && item.trim().isNotEmpty) {
            return item.trim();
          }
          if (item is Map<String, dynamic>) {
            final nested = _extractMessage(item);
            if (nested != null) return nested;
          }
        }
      }
    }
    return null;
  }
}

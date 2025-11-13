import 'dart:async';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message)
      : super(message, statusCode: 401);
}

class ConflictException extends ApiException {
  ConflictException(String message)
      : super(message, statusCode: 409);
}

class ApiClient {
  ApiClient({required String baseUrl}) {
    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json, text/plain, */*',
      },
      responseType: ResponseType.json,
    );

    _dio = Dio(options);
    _cookieJar = CookieJar();
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  late final Dio _dio;
  late final CookieJar _cookieJar;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) async {
    return _performRequest(
      () => _dio.get(path, queryParameters: query, options: options),
    );
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? query,
    dynamic data,
    Options? options,
  }) async {
    final mergedOptions = (options ?? Options()).copyWith(
      contentType: options?.contentType ?? Headers.jsonContentType,
    );
    return _performRequest(
      () => _dio.post(
        path,
        queryParameters: query,
        data: data,
        options: mergedOptions,
      ),
    );
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? query,
    dynamic data,
    Options? options,
  }) async {
    return _performRequest(
      () => _dio.put(
        path,
        queryParameters: query,
        data: data,
        options: options,
      ),
    );
  }

  Future<dynamic> _performRequest(Future<Response<dynamic>> Function() action) async {
    try {
      final response = await action();
      return _wrapResponse(response);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      final message = _messageFromPayload(data, status) ?? error.message;

      if (status == 401) {
        throw UnauthorizedException(message ?? 'Unauthorized');
      }
      if (status == 409) {
        throw ConflictException(message ?? 'Conflict');
      }

      throw ApiException(message ?? 'Request failed', statusCode: status);
    }
  }

  dynamic _wrapResponse(Response<dynamic> response) {
    final status = response.statusCode ?? 200;
    final data = response.data;

    if (status >= 200 && status < 300) {
      return data;
    }

    final message = _messageFromPayload(data, status) ??
        'Request failed with status $status';

    if (status == 401) throw UnauthorizedException(message);
    if (status == 409) throw ConflictException(message);
    throw ApiException(message, statusCode: status);
  }

  String? _messageFromPayload(dynamic data, int? status) {
    if (data == null) return null;
    if (data is String) {
      if (data.trim().isEmpty) return null;
      if (data.length > 240) return 'Request failed';
      return data;
    }
    if (data is Map) {
      final keys = [
        'message',
        'error',
        'detail',
        'msg',
        'reason',
      ];
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
        if (value is Map && value['message'] is String) {
          return value['message'] as String;
        }
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is String) return first;
          if (first is Map && first['message'] is String) {
            return first['message'] as String;
          }
        }
      }
    }
    if (status == 401) return 'Unauthorized';
    return null;
  }

  Future<void> clearCookies() async {
    await _cookieJar.deleteAll();
  }
}

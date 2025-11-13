import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(super.message) : super(statusCode: 401);
}

class ConflictException extends ApiException {
  ConflictException(super.message) : super(statusCode: 409);
}

class ApiRequestOptions {
  ApiRequestOptions({
    Map<String, String>? headers,
    this.timeout,
    this.contentType,
  }) : headers = headers == null ? null : Map.unmodifiable(headers);

  final Map<String, String>? headers;
  final Duration? timeout;
  final String? contentType;

  ApiRequestOptions copyWith({
    Map<String, String>? headers,
    Duration? timeout,
    String? contentType,
  }) {
    return ApiRequestOptions(
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      contentType: contentType ?? this.contentType,
    );
  }
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
  })  : _baseUri = Uri.parse(baseUrl),
        _defaultTimeout = connectTimeout + receiveTimeout,
        _client = http.Client();

  final Uri _baseUri;
  final Duration _defaultTimeout;
  final http.Client _client;
  final Map<String, String> _cookies = <String, String>{};

  static const Map<String, String> _baseHeaders = <String, String>{
    'Accept': 'application/json, text/plain, */*',
  };

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    ApiRequestOptions? options,
  }) async {
    return _performRequest(
      'GET',
      path,
      query: query,
      options: options,
    );
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? query,
    dynamic data,
    ApiRequestOptions? options,
  }) async {
    final mergedOptions = (options ?? ApiRequestOptions()).copyWith(
      contentType: options?.contentType ?? 'application/json',
    );
    return _performRequest(
      'POST',
      path,
      query: query,
      data: data,
      options: mergedOptions,
    );
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? query,
    dynamic data,
    ApiRequestOptions? options,
  }) async {
    return _performRequest(
      'PUT',
      path,
      query: query,
      data: data,
      options: options,
    );
  }

  Future<dynamic> _performRequest(
    String method,
    String path, {
    Map<String, dynamic>? query,
    dynamic data,
    ApiRequestOptions? options,
  }) async {
    final request = http.Request(method, _resolveUri(path, query));

    final effectiveHeaders = <String, String>{..._baseHeaders};
    if (options?.headers != null) {
      effectiveHeaders.addAll(options!.headers!);
    }
    if (_cookies.isNotEmpty) {
      effectiveHeaders['Cookie'] = _cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }

    final bodyDetails = _prepareRequestBody(data, options?.contentType);
    final contentType = bodyDetails.contentType;
    final body = bodyDetails.body;

    if (contentType.isNotEmpty) {
      effectiveHeaders['Content-Type'] = contentType;
    }

    request.headers.addAll(effectiveHeaders);
    if (body is List<int>) {
      request.bodyBytes = body;
    } else if (body is String) {
      request.body = body;
    }

    final timeout = options?.timeout ?? _defaultTimeout;
    try {
      final streamedResponse = await _client
          .send(request)
          .timeout(timeout, onTimeout: () => throw TimeoutException('Request timed out after ${timeout.inSeconds} seconds'));
      final response = await http.Response.fromStream(streamedResponse);
      _storeCookies(response);
      return _wrapResponse(response);
    } on TimeoutException {
      throw ApiException('Request timed out', statusCode: null);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Request failed: $error');
    }
  }

  Uri _resolveUri(String path, Map<String, dynamic>? query) {
    final resolved = _baseUri.resolve(path);
    if (query == null || query.isEmpty) {
      return resolved;
    }

    final buffer = StringBuffer();
    var hasEntries = false;
    if (resolved.hasQuery && resolved.query.isNotEmpty) {
      buffer.write(resolved.query);
      hasEntries = true;
    }

    void addPair(String key, String value) {
      if (hasEntries) {
        buffer.write('&');
      }
      buffer
        ..write(Uri.encodeQueryComponent(key))
        ..write('=')
        ..write(Uri.encodeQueryComponent(value));
      hasEntries = true;
    }

    query.forEach((key, value) {
      if (value == null) return;
      if (value is Iterable) {
        var added = false;
        for (final item in value) {
          if (item == null) continue;
          addPair(key, item.toString());
          added = true;
        }
        if (!added) {
          addPair(key, '');
        }
      } else if (value is Map) {
        addPair(key, json.encode(value));
      } else {
        addPair(key, value.toString());
      }
    });

    return resolved.replace(query: buffer.toString());
  }

  void _storeCookies(http.Response response) {
    final setCookieHeader = response.headers['set-cookie'];
    if (setCookieHeader == null || setCookieHeader.isEmpty) {
      return;
    }

    for (final rawCookie in _splitSetCookieHeader(setCookieHeader)) {
      final segments = rawCookie.split(';');
      if (segments.isEmpty) continue;
      final nameValue = segments.first.trim();
      final separatorIndex = nameValue.indexOf('=');
      if (separatorIndex == -1) continue;
      final name = nameValue.substring(0, separatorIndex).trim();
      final value = nameValue.substring(separatorIndex + 1).trim();
      if (name.isEmpty) continue;
      _cookies[name] = value;
    }
  }

  Iterable<String> _splitSetCookieHeader(String header) sync* {
    var buffer = StringBuffer();
    var inExpiresAttribute = false;
    for (var i = 0; i < header.length; i++) {
      final char = header[i];
      if (char == ',') {
        if (inExpiresAttribute) {
          buffer.write(char);
          continue;
        }
        final cookie = buffer.toString().trim();
        if (cookie.isNotEmpty) {
          yield cookie;
        }
        buffer = StringBuffer();
        continue;
      }

      buffer.write(char);
      final lowerBuffer = buffer.toString().toLowerCase();
      if (!inExpiresAttribute && lowerBuffer.endsWith('expires=')) {
        inExpiresAttribute = true;
      } else if (inExpiresAttribute && char == ';') {
        inExpiresAttribute = false;
      }
    }
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      yield remaining;
    }
  }

  _RequestBodyDetails _prepareRequestBody(dynamic data, String? contentType) {
    if (data == null) {
      return _RequestBodyDetails(null, contentType ?? '');
    }

    if (data is List<int>) {
      return _RequestBodyDetails(data, contentType ?? '');
    }

    if (data is String) {
      return _RequestBodyDetails(
        data,
        contentType ?? 'text/plain; charset=utf-8',
      );
    }

    try {
      final encoded = json.encode(data);
      return _RequestBodyDetails(
        encoded,
        contentType ?? 'application/json',
      );
    } catch (_) {
      return _RequestBodyDetails(
        data.toString(),
        contentType ?? 'text/plain; charset=utf-8',
      );
    }
  }

  dynamic _wrapResponse(http.Response response) {
    final status = response.statusCode;
    final data = _decodeBody(response);

    if (status >= 200 && status < 300) {
      return data;
    }

    final message =
        _messageFromPayload(data, status) ?? 'Request failed with status $status';

    if (status == 401) throw UnauthorizedException(message);
    if (status == 409) throw ConflictException(message);
    throw ApiException(message, statusCode: status);
  }

  dynamic _decodeBody(http.Response response) {
    final body = response.body;
    if (body.isEmpty) {
      return null;
    }
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('application/json')) {
      try {
        return json.decode(body);
      } catch (_) {
        return body;
      }
    }
    return body;
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
    _cookies.clear();
  }
}

class _RequestBodyDetails {
  const _RequestBodyDetails(this.body, this.contentType);

  final Object? body;
  final String contentType;
}

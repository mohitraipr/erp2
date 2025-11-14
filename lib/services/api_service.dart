import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/login_response.dart';

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  static const String _baseUrl = 'https://aurora-anthologies.com';
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<LoginResponse> login({
    required String username,
    required String password,
    bool sendAsForm = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/login');

    try {
      final headers = <String, String>{
        'Accept': 'application/json, text/plain, */*',
        'Content-Type':
            sendAsForm ? 'application/x-www-form-urlencoded' : 'application/json',
      };

      final body = sendAsForm
          ? {'username': username, 'password': password}
          : jsonEncode({'username': username, 'password': password});

      final res = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      final status = res.statusCode;
      final raw = _safeDecodeUtf8(res.bodyBytes);
      final Map<String, dynamic>? json = _tryParseJson(raw);

      if (status >= 200 && status < 300) {
        if (json != null && json['username'] is String && json['role'] is String) {
          return LoginResponse.fromJson(json);
        }
        final msg =
            _extractMessage(json, raw) ?? 'Login failed: unexpected server response.';
        throw ApiException(msg);
      }

      if (status == 400 || status == 401 || status == 403) {
        final msg = _extractMessage(json, raw) ?? 'Invalid username or password.';
        throw ApiException(msg);
      }

      final msg =
          _extractMessage(json, raw) ?? 'Server error ($status). Please try again.';
      throw ApiException(msg);
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.');
    } on SocketException {
      throw ApiException('No internet connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  void dispose() => _client.close();

  static String _safeDecodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return const Latin1Decoder().convert(bytes);
    }
  }

  static Map<String, dynamic>? _tryParseJson(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  static String? _extractMessage(Map<String, dynamic>? json, String raw) {
    if (json == null) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      if (text.length > 240) return 'Request failed.';
      return text;
    }

    const keys = [
      'message',
      'error',
      'detail',
      'errors',
      'msg',
      'status',
      'reason',
    ];

    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value;
      if (value is Map && value['message'] is String) return value['message'] as String;
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String) return first;
        if (first is Map && first['message'] is String) {
          return first['message'] as String;
        }
      }
    }

    if (json['ok'] == false && json['message'] is String) {
      return json['message'] as String;
    }

    final rawLower = json.toString().toLowerCase();
    if (rawLower.contains('invalid') || rawLower.contains('unauthorized')) {
      return 'Invalid username or password.';
    }

    return null;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_lot.dart';
import '../models/fabric_roll.dart';
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
  String? _sessionCookie;
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _authorizedHeaders({Map<String, String>? base}) {
    final headers = <String, String>{
      'Accept': 'application/json, text/plain, */*',
      if (base != null) ...base,
    };
    if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      headers['Cookie'] = _sessionCookie!;
    }
    return headers;
  }

  /// Set [sendAsForm] = true if your endpoint expects x-www-form-urlencoded.
  Future<LoginResponse> login({
    required String username,
    required String password,
    bool sendAsForm = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/login');

    try {
      final headers = _authorizedHeaders(
        base: {
          'Content-Type': sendAsForm
              ? 'application/x-www-form-urlencoded'
              : 'application/json',
        },
      );

      final body = sendAsForm
          ? {'username': username, 'password': password}
          : jsonEncode({'username': username, 'password': password});

      final res = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      final status = res.statusCode;
      final raw = _safeDecodeUtf8(res.bodyBytes); // handles non-utf8 too
      final Map<String, dynamic>? json = _tryParseJson(raw);

      // ----- Success path: must have BOTH fields -----
      if (status >= 200 && status < 300) {
        final rawCookie = res.headers['set-cookie'];
        if (rawCookie != null && rawCookie.isNotEmpty) {
          _sessionCookie = rawCookie.split(';').first;
        }
        if (json != null &&
            json['username'] is String &&
            json['role'] is String) {
          return LoginResponse.fromJson(json);
        }

        // 2xx but missing expected fields → treat as login failure or bad shape
        final msg =
            _extractMessage(json, raw) ??
            'Login failed: server did not return expected fields.';
        debugPrint('login() bad response [$status]: $raw');
        throw ApiException(msg);
      }

      // ----- Common auth failures -----
      if (status == 400 || status == 401 || status == 403) {
        final msg =
            _extractMessage(json, raw) ?? 'Invalid username or password.';
        debugPrint('login() auth failure [$status]: $raw');
        throw ApiException(msg);
      }

      // ----- Other server errors -----
      final msg =
          _extractMessage(json, raw) ??
          'Server error ($status). Please try again.';
      debugPrint('login() server error [$status]: $raw');
      throw ApiException(msg);
    } on TimeoutException catch (e) {
      debugPrint('login() timeout: $e');
      throw ApiException('Request timed out. Check your connection.');
    } on SocketException catch (e) {
      debugPrint('login() network error: $e');
      throw ApiException('No internet connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('login() unexpected error: $e');
      throw ApiException('Unexpected error: $e');
    }
  }

  Future<Map<String, List<FabricRoll>>> fetchFabricRolls() async {
    final uri = Uri.parse('$_baseUrl/api/fabric-rolls');
    try {
      final headers = _authorizedHeaders();
      final res = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));

      final status = res.statusCode;
      final raw = _safeDecodeUtf8(res.bodyBytes);
      final Map<String, dynamic>? json = _tryParseJson(raw);

      if (status >= 200 && status < 300 && json != null) {
        final Map<String, List<FabricRoll>> data = {};
        json.forEach((key, value) {
          if (value is List) {
            data[key] = value
                .whereType<Map>()
                .map((e) =>
                    FabricRoll.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        });
        return data;
      }

      final msg = _extractMessage(json, raw) ??
          'Failed to fetch fabric rolls (status: $status).';
      debugPrint('fetchFabricRolls() error [$status]: $raw');
      throw ApiException(msg);
    } on TimeoutException catch (e) {
      debugPrint('fetchFabricRolls() timeout: $e');
      throw ApiException('Request timed out. Check your connection.');
    } on SocketException catch (e) {
      debugPrint('fetchFabricRolls() network error: $e');
      throw ApiException('No internet connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('fetchFabricRolls() unexpected error: $e');
      throw ApiException('Unexpected error: $e');
    }
  }

  Future<ApiLot> createLot({
    required String sku,
    required String fabricType,
    required int bundleSize,
    String? remark,
    required List<Map<String, dynamic>> sizes,
    required List<Map<String, dynamic>> rolls,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/lots');
    try {
      final res = await _client
          .post(
            uri,
            headers: _authorizedHeaders(
              base: const {'Content-Type': 'application/json'},
            ),
            body: jsonEncode({
              'sku': sku,
              'fabricType': fabricType,
              'remark': remark,
              'bundleSize': bundleSize,
              'sizes': sizes,
              'rolls': rolls,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final status = res.statusCode;
      final raw = _safeDecodeUtf8(res.bodyBytes);
      final Map<String, dynamic>? json = _tryParseJson(raw);

      if (status >= 200 && status < 300 && json != null) {
        final lotJson = json['lot'];
        if (lotJson is Map<String, dynamic>) {
          return ApiLot.fromJson(lotJson);
        }
      }

      final msg = _extractMessage(json, raw) ??
          'Failed to create lot (status: $status).';
      debugPrint('createLot() error [$status]: $raw');
      throw ApiException(msg);
    } on TimeoutException catch (e) {
      debugPrint('createLot() timeout: $e');
      throw ApiException('Request timed out. Please try again.');
    } on SocketException catch (e) {
      debugPrint('createLot() network error: $e');
      throw ApiException('No internet connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('createLot() unexpected error: $e');
      throw ApiException('Unexpected error: $e');
    }
  }

  Future<List<ApiLotSummary>> fetchMyLots() async {
    final fallbackPaths = <String>['/api/lots', '/api/my-lots', '/api/lots/my'];
    ApiException? notFoundError;

    for (final path in fallbackPaths) {
      final uri = Uri.parse('$_baseUrl$path');
      try {
        final res = await _client
            .get(uri, headers: _authorizedHeaders())
            .timeout(const Duration(seconds: 20));

        final status = res.statusCode;
        final raw = _safeDecodeUtf8(res.bodyBytes);
        final decoded = _tryDecodeJson(raw);

        if (status >= 200 && status < 300 && decoded != null) {
          return _parseLotSummaries(decoded);
        }

        final msg = _extractMessage(decoded, raw) ??
            'Failed to fetch lots (status: $status).';
        debugPrint('fetchMyLots(${uri.path}) error [$status]: $raw');

        if (status == 404 || status == 405) {
          notFoundError = ApiException(msg);
          continue;
        }

        throw ApiException(msg);
      } on TimeoutException catch (e) {
        debugPrint('fetchMyLots(${uri.path}) timeout: $e');
        throw ApiException('Request timed out. Check your connection.');
      } on SocketException catch (e) {
        debugPrint('fetchMyLots(${uri.path}) network error: $e');
        throw ApiException('No internet connection.');
      } on ApiException {
        rethrow;
      } catch (e) {
        debugPrint('fetchMyLots(${uri.path}) unexpected error: $e');
        throw ApiException('Unexpected error: $e');
      }
    }

    debugPrint('fetchMyLots() exhausted fallbacks.');
    throw notFoundError ?? ApiException('Failed to fetch lots.');
  }

  Future<ApiLot> fetchLotDetail(int lotId) async {
    final uri = Uri.parse('$_baseUrl/api/lots/$lotId');
    try {
      final res = await _client
          .get(uri, headers: _authorizedHeaders())
          .timeout(const Duration(seconds: 20));

      final status = res.statusCode;
      final raw = _safeDecodeUtf8(res.bodyBytes);
      final Map<String, dynamic>? json = _tryParseJson(raw);

      if (status >= 200 && status < 300 && json != null) {
        return ApiLot.fromJson(json);
      }

      final msg = _extractMessage(json, raw) ??
          'Failed to fetch lot $lotId (status: $status).';
      debugPrint('fetchLotDetail() error [$status]: $raw');
      throw ApiException(msg);
    } on TimeoutException catch (e) {
      debugPrint('fetchLotDetail() timeout: $e');
      throw ApiException('Request timed out. Check your connection.');
    } on SocketException catch (e) {
      debugPrint('fetchLotDetail() network error: $e');
      throw ApiException('No internet connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('fetchLotDetail() unexpected error: $e');
      throw ApiException('Unexpected error: $e');
    }
  }

  Future<String> downloadLotCsv({
    required int lotId,
    required LotCsvType type,
  }) async {
    final path = type == LotCsvType.bundles
        ? 'bundles'
        : 'pieces';
    final uri = Uri.parse('$_baseUrl/api/lots/$lotId/$path/download');
    try {
      final res = await _client
          .get(uri, headers: _authorizedHeaders())
          .timeout(const Duration(seconds: 20));

      final status = res.statusCode;
      final raw = _safeDecodeUtf8(res.bodyBytes);

      if (status >= 200 && status < 300) {
        return raw;
      }

      final Map<String, dynamic>? json = _tryParseJson(raw);
      final msg = _extractMessage(json, raw) ??
          'Failed to download ${type.name} CSV (status: $status).';
      debugPrint('downloadLotCsv() error [$status]: $raw');
      throw ApiException(msg);
    } on TimeoutException catch (e) {
      debugPrint('downloadLotCsv() timeout: $e');
      throw ApiException('Request timed out. Check your connection.');
    } on SocketException catch (e) {
      debugPrint('downloadLotCsv() network error: $e');
      throw ApiException('No internet connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('downloadLotCsv() unexpected error: $e');
      throw ApiException('Unexpected error: $e');
    }
  }

  void dispose() => _client.close();

  // ---------- Helpers ----------
  static String _safeDecodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return const Latin1Decoder().convert(bytes);
    }
  }

  static dynamic _tryDecodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static List<ApiLotSummary> _parseLotSummaries(dynamic decoded) {
    Iterable<Map<dynamic, dynamic>> rawList = const [];

    if (decoded is Iterable) {
      rawList = decoded.whereType<Map<dynamic, dynamic>>();
    } else if (decoded is Map) {
      final map = decoded as Map;
      final lotsValue = map['lots'] ?? map['data'];

      if (lotsValue is Iterable) {
        rawList = lotsValue.whereType<Map<dynamic, dynamic>>();
      } else if (lotsValue is Map) {
        rawList = (lotsValue as Map)
            .values
            .whereType<Iterable>()
            .expand((element) => element)
            .whereType<Map<dynamic, dynamic>>();
      } else {
        rawList = map.values
            .whereType<Iterable>()
            .expand((element) => element)
            .whereType<Map<dynamic, dynamic>>();
      }
    }

    return rawList
        .map((e) => ApiLotSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Map<String, dynamic>? _tryParseJson(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null; // not JSON; could be HTML/text
    }
  }

  /// Extract a human-friendly message from many possible API shapes.
  static String? _extractMessage(Map<String, dynamic>? json, String raw) {
    if (json == null) {
      // Plain text like "Unauthorized" or an HTML snippet.
      final txt = raw.trim();
      if (txt.isEmpty) return null;
      if (txt.length > 240) return 'Request failed.';
      return txt;
    }

    // Common keys used by various backends
    final keys = [
      'message',
      'error',
      'detail',
      'errors',
      'msg',
      'status',
      'reason',
    ];

    for (final k in keys) {
      final v = json[k];
      if (v is String && v.trim().isNotEmpty) return v;
      if (v is Map && v['message'] is String) return v['message'] as String;
      if (v is List && v.isNotEmpty) {
        final first = v.first;
        if (first is String) return first;
        if (first is Map && first['message'] is String) {
          return first['message'] as String;
        }
      }
    }

    // Heuristic: sometimes APIs return { ok:false, message:"..." }
    if (json['ok'] == false && json['message'] is String) {
      return json['message'] as String;
    }

    // If we see fields that scream "invalid login"
    final rawAll = json.toString().toLowerCase();
    if (rawAll.contains('invalid') || rawAll.contains('unauthorized')) {
      return 'Invalid username or password.';
    }

    return null;
  }
}

enum LotCsvType { bundles, pieces }

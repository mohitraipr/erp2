import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_lot.dart';
import '../models/fabric_roll.dart';
import '../models/filter_options.dart';
import '../models/login_response.dart';
import '../models/master.dart';
import '../models/production_flow.dart';

class ApiConfig {
  static const defaultBaseUrl = String.fromEnvironment(
    'AURORA_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(String message)
      : super(message, statusCode: HttpStatus.unauthorized);
}

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl?.trim().isNotEmpty == true
            ? baseUrl!.trim()
            : ApiConfig.defaultBaseUrl,
        _client = client ?? http.Client();

  String _baseUrl;
  String? _sessionCookie;
  final http.Client _client;

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String value) {
    final normalized = value.trim();
    _baseUrl = normalized.isEmpty ? ApiConfig.defaultBaseUrl : normalized;
  }

  void clearSession() {
    _sessionCookie = null;
  }

  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    final uri = _buildUri('/api/login');
    final body = jsonEncode({'username': username, 'password': password});
    final response = await _sendRaw(
      () => _client.post(
        uri,
        headers: _headers(contentType: 'application/json'),
        body: body,
      ),
    );

    final json = _decodeJson(response.bodyBytes);
    final cookie = response.headers['set-cookie'];
    if (cookie != null && cookie.isNotEmpty) {
      _sessionCookie = _parseSetCookie(cookie);
    }

    if (json == null) {
      throw ApiException(
        'Login failed: unexpected response.',
        statusCode: response.statusCode,
      );
    }

    return LoginResponse.fromJson(json);
  }

  Future<void> logout() async {
    clearSession();
  }

  Future<Map<String, List<FabricRoll>>> fetchFabricRolls() async {
    final res = await _get('/api/fabric-rolls');
    final json = res.json;
    if (json == null) {
      return const {};
    }

    final Map<String, List<FabricRoll>> rolls = {};
    json.forEach((key, value) {
      if (value is List) {
        rolls[key] = value
            .whereType<Map>()
            .map((e) => FabricRoll.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    });
    return rolls;
  }

  Future<FilterOptions> fetchFilters() async {
    final res = await _get('/api/filters');
    final json = res.json;
    if (json == null) {
      throw ApiException('Failed to decode filters.');
    }
    return FilterOptions.fromJson(json);
  }

  Future<ApiLot> createLot({
    required String sku,
    required String fabricType,
    required int bundleSize,
    String? remark,
    required List<Map<String, dynamic>> sizes,
    required List<Map<String, dynamic>> rolls,
  }) async {
    final res = await _post(
      '/api/lots',
      body: {
        'sku': sku,
        'fabricType': fabricType,
        'remark': remark,
        'bundleSize': bundleSize,
        'sizes': sizes,
        'rolls': rolls,
      },
    );

    final json = res.json;
    if (json == null || json['lot'] is! Map<String, dynamic>) {
      throw ApiException('Malformed lot response.');
    }
    return ApiLot.fromJson(Map<String, dynamic>.from(json['lot']));
  }

  Future<List<ApiLotSummary>> fetchLots() async {
    final res = await _get('/api/lots');
    final decoded = res.decoded;
    return _parseLotSummaries(decoded);
  }

  Future<ApiLot> fetchLotDetail(int lotId) async {
    final res = await _get('/api/lots/$lotId');
    final json = res.json;
    if (json == null) {
      throw ApiException('Failed to decode lot detail.');
    }
    return ApiLot.fromJson(json);
  }

  Future<String> downloadLotCsv({
    required int lotId,
    required LotCsvType type,
  }) async {
    final path = type == LotCsvType.bundles
        ? '/api/lots/$lotId/bundles/download'
        : '/api/lots/$lotId/pieces/download';
    final res = await _get(path, expectJson: false);
    return res.rawBody;
  }

  Future<List<Master>> fetchMasters() async {
    final res = await _get('/api/masters');
    final decoded = res.decoded;
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Master.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Master.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<Master> createMaster({
    required String name,
    String? contactNumber,
    String? notes,
  }) async {
    final res = await _post(
      '/api/masters',
      body: {
        'name': name,
        if (contactNumber != null && contactNumber.isNotEmpty)
          'contactNumber': contactNumber,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );

    final json = res.json;
    if (json == null) {
      throw ApiException('Failed to decode create master response.');
    }
    final masterJson = json['master'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['master'] as Map)
        : json;
    return Master.fromJson(masterJson);
  }

  Future<ProductionSubmissionResult> submitPatternAssignments({
    required String lotNumber,
    required List<ProductionAssignment> assignments,
    int? masterId,
    String? masterName,
  }) async {
    final payload = <String, dynamic>{
      'code': lotNumber,
      if (assignments.isNotEmpty)
        'assignments': assignments.map((e) => e.toJson()).toList(),
      if (masterId != null) 'masterId': masterId,
      if (masterName != null && masterName.isNotEmpty) 'masterName': masterName,
    };

    final res = await _post('/api/production-flow/entries', body: payload);
    final json = res.json;
    if (json == null) {
      throw ApiException('Failed to decode production assignment response.');
    }
    return ProductionSubmissionResult.fromJson(json);
  }

  Future<ProductionSubmissionResult> submitJeansAssembly({
    required String bundleCode,
    int? masterId,
    String? remark,
    List<String> rejectedPieces = const [],
  }) async {
    final res = await _post(
      '/api/production-flow/entries',
      body: {
        'code': bundleCode,
        if (masterId != null) 'masterId': masterId,
        if (remark != null && remark.isNotEmpty) 'remark': remark,
        if (rejectedPieces.isNotEmpty) 'rejectedPieces': rejectedPieces,
      },
    );
    final json = res.json;
    if (json == null) {
      throw ApiException('Failed to decode jeans assembly response.');
    }
    return ProductionSubmissionResult.fromJson(json);
  }

  Future<ProductionSubmissionResult> submitWashing({
    required String lotNumber,
    String? remark,
  }) async {
    final res = await _post(
      '/api/production-flow/entries',
      body: {
        'code': lotNumber,
        if (remark != null && remark.isNotEmpty) 'remark': remark,
      },
    );
    final json = res.json;
    if (json == null) {
      throw ApiException('Failed to decode washing response.');
    }
    return ProductionSubmissionResult.fromJson(json);
  }

  Future<ProductionSubmissionResult> submitWashingIn({
    String? pieceCode,
    String? remark,
    List<String> rejectedPieces = const [],
  }) async {
    final body = <String, dynamic>{
      if (pieceCode != null && pieceCode.isNotEmpty) 'code': pieceCode,
      if (remark != null && remark.isNotEmpty) 'remark': remark,
      if (rejectedPieces.isNotEmpty) 'rejectedPieces': rejectedPieces,
    };
    final res = await _post('/api/production-flow/entries', body: body);
    final json = res.json;
    if (json == null) {
      throw ApiException('Failed to decode washing in response.');
    }
    return ProductionSubmissionResult.fromJson(json);
  }

  Future<ProductionSubmissionResult> submitFinishing({
    required String bundleCode,
    int? masterId,
    String? remark,
    List<String> rejectedPieces = const [],
  }) async {
    final res = await _post(
      '/api/production-flow/entries',
      body: {
        'code': bundleCode,
        if (masterId != null) 'masterId': masterId,
        if (remark != null && remark.isNotEmpty) 'remark': remark,
        if (rejectedPieces.isNotEmpty) 'rejectedPieces': rejectedPieces,
      },
    );
    final json = res.json;
    if (json == null) {
      throw ApiException('Failed to decode finishing response.');
    }
    return ProductionSubmissionResult.fromJson(json);
  }

  Future<ProductionFlowBundleInfo> fetchBundleInfo(String bundleCode) async {
    final res = await _get('/api/production-flow/bundles/$bundleCode');
    final json = res.json;
    if (json == null) {
      throw ApiException('Failed to decode bundle response.');
    }
    return ProductionFlowBundleInfo.fromJson(json);
  }

  Future<List<ProductionFlowEvent>> fetchProductionEvents({
    ProductionStage? stage,
    int? limit,
  }) async {
    final query = <String, String>{};
    if (stage != null) query['stage'] = stage.apiName;
    if (limit != null) query['limit'] = '$limit';

    final res = await _get('/api/production-flow/entries', query: query);
    final decoded = res.decoded;

    Iterable eventsIterable = const [];
    if (decoded is Map) {
      if (stage != null && decoded['data'] is Map) {
        final stageData = decoded['data'][stage.apiName];
        if (stageData is List) eventsIterable = stageData;
      } else if (decoded['data'] is List) {
        eventsIterable = decoded['data'] as List;
      } else if (decoded.values.any((v) => v is List)) {
        eventsIterable = decoded.values.firstWhereOrNull((v) => v is List) as
            List? ??
            const [];
      }
    } else if (decoded is List) {
      eventsIterable = decoded;
    }

    return eventsIterable
        .whereType<Map>()
        .map((e) => ProductionFlowEvent.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  void dispose() {
    _client.close();
  }

  // --- Internal helpers ---
  Uri _buildUri(String path, {Map<String, String>? query}) {
    final uri = Uri.parse(_baseUrl);
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path).replace(queryParameters: query);
    }
    return uri.replace(
      path: _normalizePath(uri.path, path),
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
  }

  String _normalizePath(String base, String path) {
    final buffer = StringBuffer();
    if (base.isNotEmpty && !base.endsWith('/')) {
      buffer.write(base);
      buffer.write('/');
    } else if (base.isNotEmpty) {
      buffer.write(base);
    }
    final trimmed = path.startsWith('/') ? path.substring(1) : path;
    buffer.write(trimmed);
    return buffer.toString();
  }

  Future<_ApiResponse> _get(
    String path, {
    Map<String, String>? query,
    bool expectJson = true,
  }) async {
    final uri = _buildUri(path, query: query);
    final response = await _sendRaw(
      () => _client.get(uri, headers: _headers()),
      expectJson: expectJson,
    );
    return _wrapResponse(response, expectJson: expectJson);
  }

  Future<_ApiResponse> _post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final response = await _sendRaw(
      () => _client.post(
        uri,
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    return _wrapResponse(response);
  }

  Future<http.Response> _sendRaw(
    Future<http.Response> Function() send, {
    bool expectJson = true,
  }) async {
    try {
      final response = await send().timeout(const Duration(seconds: 30));
      _captureCookie(response);
      if (response.statusCode == HttpStatus.unauthorized) {
        final message = _messageFromBody(response, expectJson: expectJson) ??
            'Session expired. Please login again.';
        throw UnauthorizedException(message);
      }
      if (response.statusCode >= 400) {
        final message = _messageFromBody(response, expectJson: expectJson) ??
            'Request failed (${response.statusCode}).';
        throw ApiException(message, statusCode: response.statusCode);
      }
      return response;
    } on TimeoutException {
      throw const ApiException('Request timed out. Please try again.');
    } on SocketException {
      throw const ApiException('Unable to reach the server.');
    }
  }

  Map<String, String> _headers({String? contentType}) {
    final headers = <String, String>{
      'Accept': 'application/json, text/plain, */*',
    };
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      headers['Cookie'] = _sessionCookie!;
    }
    return headers;
  }

  void _captureCookie(http.Response response) {
    final cookie = response.headers['set-cookie'];
    if (cookie != null && cookie.isNotEmpty) {
      _sessionCookie = _parseSetCookie(cookie);
    }
  }

  String _parseSetCookie(String raw) {
    final segments = raw.split(',');
    if (segments.length == 1) {
      return segments.first.split(';').first;
    }
    // Multiple cookies separated by comma; take those with '='
    final cookies = segments
        .map((segment) => segment.trim())
        .where((segment) => segment.contains('='))
        .map((segment) => segment.split(';').first)
        .join('; ');
    return cookies;
  }

  Map<String, dynamic>? _decodeJson(List<int> bytes) {
    final raw = _safeDecode(bytes);
    try {
      final result = jsonDecode(raw);
      if (result is Map<String, dynamic>) return result;
      return null;
    } catch (_) {
      return null;
    }
  }

  dynamic _decodeDynamic(List<int> bytes) {
    final raw = _safeDecode(bytes);
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  String _safeDecode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return const Latin1Decoder().convert(bytes);
    }
  }

  _ApiResponse _wrapResponse(http.Response res, {bool expectJson = true}) {
    final raw = _safeDecode(res.bodyBytes);
    final decoded = expectJson ? _decodeDynamic(res.bodyBytes) : raw;
    final json = expectJson ? _decodeJson(res.bodyBytes) : null;
    return _ApiResponse(res, json, decoded, raw);
  }

  String? _messageFromBody(http.Response response, {bool expectJson = true}) {
    if (expectJson) {
      final json = _decodeJson(response.bodyBytes);
      final message = _extractMessage(json, response.bodyBytes);
      if (message != null) return message;
    }
    final raw = _safeDecode(response.bodyBytes).trim();
    if (raw.isEmpty) return null;
    if (raw.length > 240) return null;
    return raw;
  }

  static String? _extractMessage(
    Map<String, dynamic>? json,
    List<int> bodyBytes,
  ) {
    if (json == null) return null;
    final keys = [
      'error',
      'message',
      'detail',
      'status',
      'reason',
      'msg',
    ];
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
      if (value is Map && value['message'] is String) {
        return (value['message'] as String).trim();
      }
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.trim().isNotEmpty) {
          return first.trim();
        }
        if (first is Map && first['message'] is String) {
          return (first['message'] as String).trim();
        }
      }
    }
    return null;
  }

  List<ApiLotSummary> _parseLotSummaries(dynamic decoded) {
    final results = <ApiLotSummary>[];
    final seen = <String>{};

    void walk(dynamic value) {
      if (value is Iterable) {
        for (final element in value) {
          walk(element);
        }
        return;
      }
      if (value is Map) {
        final map = <String, dynamic>{};
        value.forEach((key, dynamic v) {
          if (key is String) map[key] = v;
        });
        if (_looksLikeLotSummary(map)) {
          final fingerprint = _lotFingerprint(map);
          if (fingerprint == null || seen.add(fingerprint)) {
            results.add(ApiLotSummary.fromJson(map));
          }
        }
        for (final child in value.values) {
          walk(child);
        }
      }
    }

    walk(decoded);
    return results;
  }

  bool _looksLikeLotSummary(Map<String, dynamic> json) {
    if (json.isEmpty) return false;
    final hasLotNumber = json.containsKey('lotNumber') ||
        json.containsKey('lot_number') ||
        json.containsKey('lotNo') ||
        json.containsKey('lot_no');
    final hasSku = json.containsKey('sku');
    final hasFabric =
        json.containsKey('fabricType') || json.containsKey('fabric_type');
    final hasId = json.containsKey('id') ||
        json.containsKey('lotId') ||
        json.containsKey('lot_id') ||
        json.containsKey('lotID');
    return hasLotNumber && (hasSku || hasFabric || hasId);
  }

  String? _lotFingerprint(Map<String, dynamic> json) {
    final id = json['id'] ?? json['lotId'] ?? json['lot_id'] ?? json['lotID'];
    if (id != null) return 'id:$id';
    final lotNumber = json['lotNumber'] ??
        json['lot_number'] ??
        json['lotNo'] ??
        json['lot_no'];
    if (lotNumber != null) return 'lot:$lotNumber';
    final sku = json['sku'];
    final fabric = json['fabricType'] ?? json['fabric_type'];
    return 'sku:${sku ?? ''}|fabric:${fabric ?? ''}';
  }
}

class _ApiResponse {
  final http.Response response;
  final Map<String, dynamic>? json;
  final dynamic decoded;
  final String rawBody;

  const _ApiResponse(
    this.response,
    this.json,
    this.decoded,
    this.rawBody,
  );
}

enum LotCsvType { bundles, pieces }

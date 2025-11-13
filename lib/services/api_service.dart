import 'package:dio/dio.dart';

import '../models/fabric_roll.dart';
import '../models/filter_options.dart';
import '../models/login_response.dart';
import '../models/lot_models.dart';
import '../models/master.dart';
import '../models/production_flow.dart';
import 'api_client.dart';

class ApiService {
  final ApiClient _client;

  ApiService({ApiClient? client}) : _client = client ?? ApiClient();

  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/login',
      data: {
        'username': username,
        'password': password,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    return LoginResponse.fromJson(response.data ?? const {});
  }

  void clearSession() => _client.clearSession();

  Future<Map<String, List<FabricRoll>>> fetchFabricRolls() async {
    final response = await _client.get<Map<String, dynamic>>('/api/fabric-rolls');
    final data = response.data ?? const {};
    final rolls = <String, List<FabricRoll>>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is List) {
        rolls[entry.key] = value
            .whereType<Map>()
            .map((e) => FabricRoll.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return rolls;
  }

  Future<FilterOptions> fetchFilters() async {
    final response = await _client.get<Map<String, dynamic>>('/api/filters');
    return FilterOptions.fromJson(response.data ?? const {});
  }

  Future<LotDetail> createLot(LotCreationRequest request) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/lots',
      data: request.toJson(),
    );
    final payload = response.data ?? const {};
    final lotJson = payload['lot'] as Map<String, dynamic>? ?? payload;
    return LotDetail.fromJson(lotJson);
  }

  Future<List<LotSummary>> fetchLots() async {
    final response = await _client.get<List<dynamic>>('/api/lots');
    final data = response.data ?? const [];
    return data
        .whereType<Map>()
        .map((e) => LotSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<LotDetail> fetchLotDetail(int lotId) async {
    final response = await _client.get<Map<String, dynamic>>('/api/lots/$lotId');
    return LotDetail.fromJson(response.data ?? const {});
  }

  Future<LotDetail> fetchLotByNumber(String lotNumber) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/lots/by-number/$lotNumber',
      );
      return LotDetail.fromJson(response.data ?? const {});
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        final lots = await fetchLots();
        final needle = lotNumber.toLowerCase();
        LotSummary? match;
        for (final lot in lots) {
          if (lot.lotNumber.toLowerCase() == needle) {
            match = lot;
            break;
          }
        }
        match ??= () {
          for (final lot in lots) {
            if (lot.sku.toLowerCase() == needle) {
              return lot;
            }
          }
          return null;
        }();
        if (match != null) {
          return fetchLotDetail(match.id);
        }
      }
      rethrow;
    }
  }

  Uri resolveDownloadUrl(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${_client.baseUrl}$normalized');
  }

  Future<List<MasterInfo>> fetchMasters() async {
    final response = await _client.get<List<dynamic>>('/api/masters');
    final data = response.data ?? const [];
    return data
        .whereType<Map>()
        .map((e) => MasterInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MasterInfo> createMaster(MasterPayload payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/masters',
      data: payload.toJson(),
    );
    final body = response.data ?? const {};
    final masterJson = body['master'] as Map<String, dynamic>? ?? body;
    return MasterInfo.fromJson(masterJson);
  }

  Future<Map<String, dynamic>> submitProductionEntry(Map<String, dynamic> payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/production-flow/entries',
      data: payload,
    );
    return response.data ?? const {};
  }

  Future<BundleLookupInfo> lookupBundle(String bundleCode) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/production-flow/bundles/$bundleCode',
    );
    final body = response.data ?? const {};
    final bundleJson = body['bundle'] as Map<String, dynamic>? ?? body;
    return BundleLookupInfo.fromJson(bundleJson);
  }

  Future<Map<String, List<ProductionFlowEvent>>> fetchProductionEntries({
    String? stage,
    int? limit,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/production-flow/entries',
      query: {
        if (stage != null && stage.isNotEmpty) 'stage': stage,
        if (limit != null) 'limit': '$limit',
      },
    );
    final data = response.data ?? const {};
    final result = <String, List<ProductionFlowEvent>>{};

    if (stage != null && stage.isNotEmpty) {
      final dataField = data['data'];
      if (dataField is Map) {
        final list = dataField[stage];
        if (list is List) {
          result[stage] = list
              .whereType<Map>()
              .map((e) => ProductionFlowEvent.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } else {
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is List) {
          result[entry.key] = value
              .whereType<Map>()
              .map((e) => ProductionFlowEvent.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else if (value is Map) {
          result[entry.key] = value.values
              .whereType<List>()
              .expand((list) => list)
              .whereType<Map>()
              .map((e) => ProductionFlowEvent.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    }

    return result;
  }
}

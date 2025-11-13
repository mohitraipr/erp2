import 'dart:convert';

import '../models/api_lot.dart';
import '../models/fabric_roll.dart';
import '../models/filter_options.dart';
import '../models/master.dart';
import '../models/production_flow.dart';
import '../models/user.dart';
import '../utils/download_helper.dart';
import 'api_client.dart';

class LotCreationPayload {
  LotCreationPayload({
    required this.sku,
    required this.fabricType,
    required this.bundleSize,
    required this.sizes,
    required this.rolls,
    this.remark,
  });

  final String sku;
  final String fabricType;
  final int bundleSize;
  final List<LotSizePayload> sizes;
  final List<LotRollPayload> rolls;
  final String? remark;

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'fabricType': fabricType,
      'remark': remark,
      'bundleSize': bundleSize,
      'sizes': sizes.map((e) => e.toJson()).toList(),
      'rolls': rolls.map((e) => e.toJson()).toList(),
    };
  }
}

class LotSizePayload {
  LotSizePayload({required this.sizeLabel, required this.patternCount});

  final String sizeLabel;
  final int patternCount;

  Map<String, dynamic> toJson() => {
        'sizeLabel': sizeLabel,
        'patternCount': patternCount,
      };
}

class LotRollPayload {
  LotRollPayload({
    required this.rollNo,
    required this.weightUsed,
    required this.layers,
  });

  final String rollNo;
  final double weightUsed;
  final int layers;

  Map<String, dynamic> toJson() => {
        'rollNo': rollNo,
        'weightUsed': weightUsed,
        'layers': layers,
      };
}

class ProductionAssignmentPayload {
  ProductionAssignmentPayload({
    required this.code,
    required this.assignments,
    this.masterId,
    this.masterName,
    this.remark,
    this.rejectedPieces,
  });

  final String code;
  final List<Map<String, dynamic>> assignments;
  final int? masterId;
  final String? masterName;
  final String? remark;
  final List<String>? rejectedPieces;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      if (assignments.isNotEmpty) 'assignments': assignments,
      if (masterId != null) 'masterId': masterId,
      if (masterName != null) 'masterName': masterName,
      if (remark != null && remark!.isNotEmpty) 'remark': remark,
      if (rejectedPieces != null && rejectedPieces!.isNotEmpty)
        'rejectedPieces': rejectedPieces,
    };
  }
}

class ErpRepository {
  ErpRepository(this._client);

  final ApiClient _client;

  Future<UserProfile> login(String username, String password) async {
    final response = await _client.post(
      '/api/login',
      data: {
        'username': username,
        'password': password,
      },
    );
    if (response is Map<String, dynamic>) {
      return UserProfile.fromJson(response);
    }
    throw ApiException('Invalid login response');
  }

  Future<Map<String, List<FabricRoll>>> getFabricRolls() async {
    final response = await _client.get('/api/fabric-rolls');
    if (response is Map) {
      final rawMap = (response as Map).cast<dynamic, dynamic>();
      final result = <String, List<FabricRoll>>{};
      for (final entry in rawMap.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          result[key] = value
              .whereType<Map>()
              .map((e) => FabricRoll.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
      return result;
    }
    return const {};
  }

  Future<FilterOptions> getFilters() async {
    final response = await _client.get('/api/filters');
    if (response is Map<String, dynamic>) {
      return FilterOptions.fromJson(response);
    }
    return const FilterOptions(genders: [], categories: []);
  }

  Future<ApiLot> createLot(LotCreationPayload payload) async {
    final response = await _client.post(
      '/api/lots',
      data: payload.toJson(),
    );
    if (response is Map<String, dynamic>) {
      final lotJson = response['lot'];
      if (lotJson is Map<String, dynamic>) {
        return ApiLot.fromJson(lotJson);
      }
    }
    throw ApiException('Unexpected response while creating lot');
  }

  Future<List<ApiLotSummary>> getLots() async {
    final response = await _client.get('/api/lots');
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => ApiLotSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (response is Map) {
      final List<ApiLotSummary> lots = [];
      void walk(dynamic value) {
        if (value is List) {
          for (final element in value) {
            walk(element);
          }
        } else if (value is Map) {
          final mapValue = (value as Map).cast<dynamic, dynamic>();
          if (mapValue.containsKey('lotNumber') ||
              mapValue.containsKey('lot_number')) {
            final mapped = Map<String, dynamic>.fromEntries(
              mapValue.entries.map(
                (entry) => MapEntry(entry.key.toString(), entry.value),
              ),
            );
            lots.add(ApiLotSummary.fromJson(mapped));
          } else {
            for (final element in mapValue.values) {
              walk(element);
            }
          }
        }
      }

      walk(response);
      return lots;
    }
    return const [];
  }

  Future<ApiLot> getLotDetail(int lotId) async {
    final response = await _client.get('/api/lots/$lotId');
    if (response is Map<String, dynamic>) {
      return ApiLot.fromJson(response);
    }
    throw ApiException('Lot not found');
  }

  Future<String> downloadLotCsv(int lotId, LotCsvType type) async {
    final path = type == LotCsvType.bundles ? 'bundles' : 'pieces';
    final response = await _client.get('/api/lots/$lotId/$path/download');
    if (response is String) {
      return response;
    }
    if (response is Map || response is List) {
      return const JsonEncoder.withIndent('  ').convert(response);
    }
    return response?.toString() ?? '';
  }

  Future<List<MasterRecord>> getMasters() async {
    final response = await _client.get('/api/masters');
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => MasterRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<MasterRecord> createMaster({
    required String name,
    required String contactNumber,
    String? notes,
  }) async {
    final response = await _client.post(
      '/api/masters',
      data: {
        'name': name,
        'contactNumber': contactNumber,
        'notes': notes,
      },
    );
    if (response is Map<String, dynamic>) {
      final masterJson = response['master'];
      if (masterJson is Map<String, dynamic>) {
        return MasterRecord.fromJson(masterJson);
      }
    }
    throw ApiException('Unexpected response while creating master');
  }

  Future<ProductionEntryResponse> submitProductionEntry(
    ProductionAssignmentPayload payload,
  ) async {
    final response = await _client.post(
      '/api/production-flow/entries',
      data: payload.toJson(),
    );
    if (response is Map<String, dynamic>) {
      return ProductionEntryResponse.fromJson(response);
    }
    throw ApiException('Invalid production entry response');
  }

  Future<ProductionBundleInfo> getBundleByCode(String bundleCode) async {
    final response =
        await _client.get('/api/production-flow/bundles/$bundleCode');
    if (response is Map<String, dynamic>) {
      final bundleJson = response['bundle'];
      if (bundleJson is Map<String, dynamic>) {
        return ProductionBundleInfo.fromJson(bundleJson);
      }
    }
    throw ApiException('Bundle not found');
  }

  Future<List<ProductionFlowEvent>> getProductionFlowEvents({
    String? stage,
    int? limit,
  }) async {
    final response = await _client.get(
      '/api/production-flow/entries',
      query: {
        if (stage != null && stage.isNotEmpty) 'stage': stage,
        if (limit != null) 'limit': limit,
      },
    );
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      final List<ProductionFlowEvent> events = [];
      if (stage != null && stage.isNotEmpty) {
        final list = data is Map ? data[stage] : null;
        if (list is List) {
          events.addAll(list
              .whereType<Map>()
              .map((e) => ProductionFlowEvent.fromJson(
                  Map<String, dynamic>.from(e))));
        }
      } else if (data is Map) {
        for (final entry in data.entries) {
          final value = entry.value;
          if (value is List) {
            events.addAll(value
                .whereType<Map>()
                .map((e) => ProductionFlowEvent.fromJson(
                    Map<String, dynamic>.from(e))));
          }
        }
      }
      return events;
    }
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => ProductionFlowEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<bool> saveCsv({
    required int lotId,
    required LotCsvType type,
    required String filename,
  }) async {
    final csvContent = await downloadLotCsv(lotId, type);
    return saveCsvToDevice(filename, csvContent);
  }

  Future<void> logout() async {
    await _client.clearCookies();
  }
}

enum LotCsvType { bundles, pieces }

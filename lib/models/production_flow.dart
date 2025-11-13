import 'dart:convert';

class ProductionFlowSubmissionResult {
  final bool success;
  final String stage;
  final Map<String, dynamic>? data;
  final Map<String, dynamic> raw;

  const ProductionFlowSubmissionResult({
    required this.success,
    required this.stage,
    required this.raw,
    this.data,
  });

  factory ProductionFlowSubmissionResult.fromJson(Map<String, dynamic> json) {
    final success = json['success'] == true;
    final stage = (json['stage'] ?? '').toString();
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json['data'] is Map
            ? (json['data'] as Map).cast<String, dynamic>()
            : null;

    return ProductionFlowSubmissionResult(
      success: success,
      stage: stage,
      data: data,
      raw: json,
    );
  }

  String prettyPrinted() {
    try {
      return const JsonEncoder.withIndent('  ').convert(raw);
    } catch (_) {
      return raw.toString();
    }
  }
}

class ProductionFlowEntry {
  final int id;
  final String stage;
  final String codeType;
  final String codeValue;
  final String? lotNumber;
  final String? bundleCode;
  final String? sizeLabel;
  final String? pieceCode;
  final String? eventStatus;
  final bool isClosed;
  final DateTime? createdAt;
  final DateTime? closedAt;

  const ProductionFlowEntry({
    required this.id,
    required this.stage,
    required this.codeType,
    required this.codeValue,
    this.lotNumber,
    this.bundleCode,
    this.sizeLabel,
    this.pieceCode,
    this.eventStatus,
    this.isClosed = false,
    this.createdAt,
    this.closedAt,
  });

  factory ProductionFlowEntry.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    String _string(dynamic value) => value?.toString() ?? '';

    int _int(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    return ProductionFlowEntry(
      id: _int(json['id']),
      stage: _string(json['stage']).toLowerCase(),
      codeType: _string(json['codeType'] ?? json['code_type']),
      codeValue: _string(json['codeValue'] ?? json['code_value']),
      lotNumber: json['lotNumber']?.toString() ?? json['lot_number']?.toString(),
      bundleCode: json['bundleCode']?.toString() ?? json['bundle_code']?.toString(),
      sizeLabel: json['sizeLabel']?.toString() ?? json['size_label']?.toString(),
      pieceCode: json['pieceCode']?.toString() ?? json['piece_code']?.toString(),
      eventStatus: json['eventStatus']?.toString() ?? json['event_status']?.toString(),
      isClosed: (json['isClosed'] ?? json['is_closed']) == true ||
          (json['isClosed'] ?? json['is_closed']) == 1,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      closedAt: _parseDate(json['closedAt'] ?? json['closed_at']),
    );
  }
}

class BundleLookup {
  final int bundleId;
  final String bundleCode;
  final int? piecesInBundle;
  final int lotId;
  final String lotNumber;
  final String? sku;
  final String? fabricType;
  final int? pieceCount;

  const BundleLookup({
    required this.bundleId,
    required this.bundleCode,
    required this.lotId,
    required this.lotNumber,
    this.piecesInBundle,
    this.sku,
    this.fabricType,
    this.pieceCount,
  });

  factory BundleLookup.fromJson(Map<String, dynamic> json) {
    int _int(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    int? _intOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    String? _string(dynamic value) {
      if (value == null) return null;
      return value.toString();
    }

    return BundleLookup(
      bundleId: _int(json['bundleId'] ?? json['bundle_id'] ?? json['id']),
      bundleCode: _string(json['bundleCode'] ?? json['bundle_code']) ?? '',
      piecesInBundle: _intOrNull(json['piecesInBundle'] ?? json['pieces_in_bundle']),
      lotId: _int(json['lotId'] ?? json['lot_id']),
      lotNumber: _string(json['lotNumber'] ?? json['lot_number']) ?? '',
      sku: _string(json['sku']),
      fabricType: _string(json['fabricType'] ?? json['fabric_type']),
      pieceCount: _intOrNull(json['pieceCount'] ?? json['piece_count']),
    );
  }
}

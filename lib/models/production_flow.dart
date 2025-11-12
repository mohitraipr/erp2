class ProductionFlowEntry {
  final int id;
  final String stage;
  final String? codeType;
  final String? codeValue;
  final int? lotId;
  final int? bundleId;
  final int? sizeId;
  final int? pieceId;
  final String? lotNumber;
  final String? bundleCode;
  final int? bundleSequence;
  final String? sizeLabel;
  final String? pieceCode;
  final int? patternCount;
  final int? bundleCount;
  final int? piecesTotal;
  final int? userId;
  final String? userUsername;
  final String? userRole;
  final int? masterId;
  final String? masterName;
  final String? remark;
  final String? eventStatus;
  final bool isClosed;
  final String? closedByStage;
  final int? closedByUserId;
  final String? closedByUserUsername;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductionFlowEntry({
    required this.id,
    required this.stage,
    this.codeType,
    this.codeValue,
    this.lotId,
    this.bundleId,
    this.sizeId,
    this.pieceId,
    this.lotNumber,
    this.bundleCode,
    this.bundleSequence,
    this.sizeLabel,
    this.pieceCode,
    this.patternCount,
    this.bundleCount,
    this.piecesTotal,
    this.userId,
    this.userUsername,
    this.userRole,
    this.masterId,
    this.masterName,
    this.remark,
    this.eventStatus,
    required this.isClosed,
    this.closedByStage,
    this.closedByUserId,
    this.closedByUserUsername,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductionFlowEntry.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.trim().isEmpty) return null;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;
        final num? parsed = num.tryParse(value);
        if (parsed != null) return parsed != 0;
      }
      return false;
    }

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String && value.trim().isNotEmpty) {
        return int.tryParse(value);
      }
      return null;
    }

    return ProductionFlowEntry(
      id: parseInt(json['id']) ?? 0,
      stage: (json['stage'] ?? '') as String,
      codeType: json['codeType'] as String? ?? json['code_type'] as String?,
      codeValue: json['codeValue'] as String? ?? json['code_value'] as String?,
      lotId: parseInt(json['lotId'] ?? json['lot_id']),
      bundleId: parseInt(json['bundleId'] ?? json['bundle_id']),
      sizeId: parseInt(json['sizeId'] ?? json['size_id']),
      pieceId: parseInt(json['pieceId'] ?? json['piece_id']),
      lotNumber: json['lotNumber'] as String? ?? json['lot_number'] as String?,
      bundleCode: json['bundleCode'] as String? ?? json['bundle_code'] as String?,
      bundleSequence: parseInt(json['bundleSequence'] ?? json['bundle_sequence']),
      sizeLabel: json['sizeLabel'] as String? ?? json['size_label'] as String?,
      pieceCode: json['pieceCode'] as String? ?? json['piece_code'] as String?,
      patternCount: parseInt(json['patternCount'] ?? json['pattern_count']),
      bundleCount: parseInt(json['bundleCount'] ?? json['bundle_count']),
      piecesTotal: parseInt(json['piecesTotal'] ?? json['pieces_total']),
      userId: parseInt(json['userId'] ?? json['user_id']),
      userUsername:
          json['userUsername'] as String? ?? json['user_username'] as String?,
      userRole: json['userRole'] as String? ?? json['user_role'] as String?,
      masterId: parseInt(json['masterId'] ?? json['master_id']),
      masterName: json['masterName'] as String? ?? json['master_name'] as String?,
      remark: json['remark'] as String?,
      eventStatus: json['eventStatus'] as String? ?? json['event_status'] as String?,
      isClosed: parseBool(json['isClosed'] ?? json['is_closed']),
      closedByStage:
          json['closedByStage'] as String? ?? json['closed_by_stage'] as String?,
      closedByUserId:
          parseInt(json['closedByUserId'] ?? json['closed_by_user_id']),
      closedByUserUsername: (json['closedByUserUsername'] ??
          json['closed_by_user_username']) as String?,
      closedAt: parseDate(json['closedAt'] ?? json['closed_at']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  String get displayCode {
    final parts = <String?>[
      codeValue,
      bundleCode,
      pieceCode,
      lotNumber,
    ].whereType<String>().toList();
    if (parts.isEmpty) {
      return '—';
    }
    return parts.first;
  }
}

class ProductionFlowSubmissionResult {
  final bool success;
  final String stage;
  final Map<String, dynamic> data;

  const ProductionFlowSubmissionResult({
    required this.success,
    required this.stage,
    required this.data,
  });

  factory ProductionFlowSubmissionResult.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    final Map<String, dynamic> parsedData;
    if (rawData is Map<String, dynamic>) {
      parsedData = rawData;
    } else if (rawData is Map) {
      parsedData = rawData.cast<String, dynamic>();
    } else {
      parsedData = {};
    }

    return ProductionFlowSubmissionResult(
      success: json['success'] == true,
      stage: (json['stage'] ?? '') as String,
      data: parsedData,
    );
  }
}

class ProductionBundleInfo {
  final int bundleId;
  final String bundleCode;
  final int piecesInBundle;
  final int lotId;
  final String lotNumber;
  final String? sku;
  final String? fabricType;
  final int pieceCount;

  const ProductionBundleInfo({
    required this.bundleId,
    required this.bundleCode,
    required this.piecesInBundle,
    required this.lotId,
    required this.lotNumber,
    this.sku,
    this.fabricType,
    required this.pieceCount,
  });

  factory ProductionBundleInfo.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String && value.trim().isNotEmpty) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return 0;
    }

    return ProductionBundleInfo(
      bundleId: parseInt(json['bundleId'] ?? json['id']),
      bundleCode: (json['bundleCode'] ?? json['bundle_code'] ?? '') as String,
      piecesInBundle:
          parseInt(json['piecesInBundle'] ?? json['pieces_in_bundle']),
      lotId: parseInt(json['lotId'] ?? json['lot_id']),
      lotNumber: (json['lotNumber'] ?? json['lot_number'] ?? '') as String,
      sku: json['sku'] as String?,
      fabricType: json['fabricType'] as String? ?? json['fabric_type'] as String?,
      pieceCount: parseInt(json['pieceCount'] ?? json['piece_count']),
    );
  }
}

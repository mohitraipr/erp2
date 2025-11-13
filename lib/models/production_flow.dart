enum ProductionStage {
  backPocket('back_pocket'),
  stitchingMaster('stitching_master'),
  jeansAssembly('jeans_assembly'),
  washing('washing'),
  washingIn('washing_in'),
  finishing('finishing');

  final String apiName;
  const ProductionStage(this.apiName);

  static ProductionStage? fromApi(String? value) {
    if (value == null) return null;
    final normalized = value.toLowerCase();
    for (final stage in ProductionStage.values) {
      if (stage.apiName == normalized) return stage;
    }
    return null;
  }
}

class ProductionAssignment {
  final String sizeLabel;
  final List<int> patternNumbers;
  final int? masterId;
  final String? masterName;

  const ProductionAssignment({
    required this.sizeLabel,
    required this.patternNumbers,
    this.masterId,
    this.masterName,
  });

  Map<String, dynamic> toJson() {
    return {
      'sizeLabel': sizeLabel,
      'patternNos': patternNumbers,
      if (masterId != null) 'masterId': masterId,
      if (masterName != null && masterName!.isNotEmpty)
        'masterName': masterName,
    };
  }
}

class ProductionSubmissionResult {
  final bool success;
  final ProductionStage? stage;
  final Map<String, dynamic> data;
  final String? message;

  const ProductionSubmissionResult({
    required this.success,
    this.stage,
    this.data = const {},
    this.message,
  });

  factory ProductionSubmissionResult.fromJson(Map<String, dynamic> json) {
    final stage = ProductionStage.fromApi(json['stage']?.toString());
    final data = json['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    return ProductionSubmissionResult(
      success: json['success'] == true || json['ok'] == true,
      stage: stage,
      data: data,
      message: json['message'] as String?,
    );
  }
}

class ProductionFlowBundleInfo {
  final int? bundleId;
  final String bundleCode;
  final int? piecesInBundle;
  final int? lotId;
  final int? patternId;
  final int? patternNo;
  final String? lotNumber;
  final String? sku;
  final String? fabricType;
  final int? pieceCount;

  const ProductionFlowBundleInfo({
    this.bundleId,
    required this.bundleCode,
    this.piecesInBundle,
    this.lotId,
    this.patternId,
    this.patternNo,
    this.lotNumber,
    this.sku,
    this.fabricType,
    this.pieceCount,
  });

  factory ProductionFlowBundleInfo.fromJson(Map<String, dynamic> json) {
    final bundleJson = json['bundle'] is Map<String, dynamic>
        ? json['bundle'] as Map<String, dynamic>
        : json;
    int? parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return ProductionFlowBundleInfo(
      bundleId: parseInt(bundleJson['bundleId'] ?? bundleJson['id']),
      bundleCode: (bundleJson['bundleCode'] ?? bundleJson['code'] ?? '')
          .toString(),
      piecesInBundle: parseInt(
          bundleJson['piecesInBundle'] ?? bundleJson['pieces_in_bundle'] ?? bundleJson['pieceCount'] ?? bundleJson['pieces']),
      lotId: parseInt(bundleJson['lotId'] ?? bundleJson['lot_id']),
      patternId: parseInt(bundleJson['patternId'] ?? bundleJson['pattern_id']),
      patternNo: parseInt(bundleJson['patternNo'] ?? bundleJson['pattern_no']),
      lotNumber: bundleJson['lotNumber']?.toString(),
      sku: bundleJson['sku']?.toString(),
      fabricType: bundleJson['fabricType']?.toString(),
      pieceCount: parseInt(bundleJson['pieceCount'] ?? bundleJson['pieces']),
    );
  }
}

class ProductionFlowEvent {
  final int id;
  final ProductionStage? stage;
  final String? codeType;
  final String? codeValue;
  final int? lotId;
  final int? bundleId;
  final int? sizeId;
  final int? patternId;
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

  const ProductionFlowEvent({
    required this.id,
    this.stage,
    this.codeType,
    this.codeValue,
    this.lotId,
    this.bundleId,
    this.sizeId,
    this.patternId,
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

  factory ProductionFlowEvent.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final stage = ProductionStage.fromApi(json['stage']?.toString());
    final isClosed = json['isClosed'] == true || json['is_closed'] == true;

    return ProductionFlowEvent(
      id: parseInt(json['id']) ?? 0,
      stage: stage,
      codeType: json['codeType']?.toString(),
      codeValue: json['codeValue']?.toString(),
      lotId: parseInt(json['lotId'] ?? json['lot_id']),
      bundleId: parseInt(json['bundleId'] ?? json['bundle_id']),
      sizeId: parseInt(json['sizeId'] ?? json['size_id']),
      patternId: parseInt(json['patternId'] ?? json['pattern_id']),
      pieceId: parseInt(json['pieceId'] ?? json['piece_id']),
      lotNumber: json['lotNumber']?.toString(),
      bundleCode: json['bundleCode']?.toString(),
      bundleSequence:
          parseInt(json['bundleSequence'] ?? json['bundle_sequence']),
      sizeLabel: json['sizeLabel']?.toString(),
      pieceCode: json['pieceCode']?.toString(),
      patternCount: parseInt(json['patternCount'] ?? json['pattern_count']),
      bundleCount: parseInt(json['bundleCount'] ?? json['bundle_count']),
      piecesTotal: parseInt(json['piecesTotal'] ?? json['pieces_total']),
      userId: parseInt(json['userId'] ?? json['user_id']),
      userUsername: json['userUsername']?.toString(),
      userRole: json['userRole']?.toString(),
      masterId: parseInt(json['masterId'] ?? json['master_id']),
      masterName: json['masterName']?.toString(),
      remark: json['remark']?.toString(),
      eventStatus: json['eventStatus']?.toString(),
      isClosed: isClosed,
      closedByStage: json['closedByStage']?.toString(),
      closedByUserId:
          parseInt(json['closedByUserId'] ?? json['closed_by_user_id']),
      closedByUserUsername:
          json['closedByUserUsername']?.toString(),
      closedAt: parseDate(json['closedAt'] ?? json['closed_at']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

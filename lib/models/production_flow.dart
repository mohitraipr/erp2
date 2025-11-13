class ProductionAssignment {
  final String sizeLabel;
  final List<int> patternNos;
  final int? masterId;
  final String? masterName;

  const ProductionAssignment({
    required this.sizeLabel,
    required this.patternNos,
    this.masterId,
    this.masterName,
  });

  Map<String, dynamic> toJson() => {
        'sizeLabel': sizeLabel,
        'patternNos': patternNos,
        if (masterId != null) 'masterId': masterId,
        if (masterName != null) 'masterName': masterName,
      };
}

class ProductionFlowEvent {
  final int id;
  final String stage;
  final String codeType;
  final String codeValue;
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
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductionFlowEvent({
    required this.id,
    required this.stage,
    required this.codeType,
    required this.codeValue,
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
    this.isClosed = false,
    this.closedByStage,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductionFlowEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return ProductionFlowEvent(
      id: (json['id'] as num).toInt(),
      stage: (json['stage'] ?? '') as String,
      codeType: (json['codeType'] ?? '') as String,
      codeValue: (json['codeValue'] ?? '') as String,
      lotId: json['lotId'] is num ? (json['lotId'] as num).toInt() : null,
      bundleId: json['bundleId'] is num ? (json['bundleId'] as num).toInt() : null,
      sizeId: json['sizeId'] is num ? (json['sizeId'] as num).toInt() : null,
      patternId: json['patternId'] is num ? (json['patternId'] as num).toInt() : null,
      pieceId: json['pieceId'] is num ? (json['pieceId'] as num).toInt() : null,
      lotNumber: json['lotNumber'] as String?,
      bundleCode: json['bundleCode'] as String?,
      bundleSequence: json['bundleSequence'] is num ? (json['bundleSequence'] as num).toInt() : null,
      sizeLabel: json['sizeLabel'] as String?,
      pieceCode: json['pieceCode'] as String?,
      patternCount: json['patternCount'] is num ? (json['patternCount'] as num).toInt() : null,
      bundleCount: json['bundleCount'] is num ? (json['bundleCount'] as num).toInt() : null,
      piecesTotal: json['piecesTotal'] is num ? (json['piecesTotal'] as num).toInt() : null,
      userId: json['userId'] is num ? (json['userId'] as num).toInt() : null,
      userUsername: json['userUsername'] as String?,
      userRole: json['userRole'] as String?,
      masterId: json['masterId'] is num ? (json['masterId'] as num).toInt() : null,
      masterName: json['masterName'] as String?,
      remark: json['remark'] as String?,
      eventStatus: json['eventStatus'] as String?,
      isClosed: (json['isClosed'] ?? 0) == 1 || json['isClosed'] == true,
      closedByStage: json['closedByStage'] as String?,
      closedAt: parseDate(json['closedAt']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}

class BundleLookupInfo {
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

  const BundleLookupInfo({
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

  factory BundleLookupInfo.fromJson(Map<String, dynamic> json) {
    return BundleLookupInfo(
      bundleId: json['bundleId'] is num ? (json['bundleId'] as num).toInt() : null,
      bundleCode: (json['bundleCode'] ?? '') as String,
      piecesInBundle: json['piecesInBundle'] is num ? (json['piecesInBundle'] as num).toInt() : null,
      lotId: json['lotId'] is num ? (json['lotId'] as num).toInt() : null,
      patternId: json['patternId'] is num ? (json['patternId'] as num).toInt() : null,
      patternNo: json['patternNo'] is num ? (json['patternNo'] as num).toInt() : null,
      lotNumber: json['lotNumber'] as String?,
      sku: json['sku'] as String?,
      fabricType: json['fabricType'] as String?,
      pieceCount: json['pieceCount'] is num ? (json['pieceCount'] as num).toInt() : null,
    );
  }
}

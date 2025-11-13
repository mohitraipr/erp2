class ProductionBundleInfo {
  const ProductionBundleInfo({
    required this.bundleCode,
    required this.bundleId,
    required this.lotNumber,
    required this.sku,
    required this.fabricType,
    this.sizeLabel,
    this.patternNo,
    this.piecesInBundle,
    this.lotId,
    this.patternId,
  });

  final String bundleCode;
  final int bundleId;
  final String lotNumber;
  final String sku;
  final String fabricType;
  final String? sizeLabel;
  final int? patternNo;
  final int? piecesInBundle;
  final int? lotId;
  final int? patternId;

  factory ProductionBundleInfo.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return ProductionBundleInfo(
      bundleCode: (json['bundleCode'] ?? json['bundle_code'] ?? '') as String,
      bundleId: parseInt(json['bundleId'] ?? json['bundle_id'] ?? 0) ?? 0,
      lotNumber: (json['lotNumber'] ?? json['lot_number'] ?? '') as String,
      sku: (json['sku'] ?? '') as String,
      fabricType: (json['fabricType'] ?? json['fabric_type'] ?? '') as String,
      sizeLabel: json['sizeLabel'] as String?,
      patternNo: parseInt(json['patternNo'] ?? json['pattern_no']),
      piecesInBundle:
          parseInt(json['pieceCount'] ?? json['piecesInBundle'] ?? json['pieces']),
      lotId: parseInt(json['lotId'] ?? json['lot_id']),
      patternId: parseInt(json['patternId'] ?? json['pattern_id']),
    );
  }
}

class ProductionFlowEvent {
  const ProductionFlowEvent({
    required this.id,
    required this.stage,
    required this.codeValue,
    this.codeType,
    this.lotNumber,
    this.bundleCode,
    this.sizeLabel,
    this.patternNo,
    this.masterName,
    this.userUsername,
    this.remark,
    this.eventStatus,
    this.createdAt,
    this.updatedAt,
    this.isClosed = false,
  });

  final int id;
  final String stage;
  final String codeValue;
  final String? codeType;
  final String? lotNumber;
  final String? bundleCode;
  final String? sizeLabel;
  final int? patternNo;
  final String? masterName;
  final String? userUsername;
  final String? remark;
  final String? eventStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isClosed;

  factory ProductionFlowEvent.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    int? parseIntNullable(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return ProductionFlowEvent(
      id: parseInt(json['id'] ?? 0),
      stage: (json['stage'] ?? '') as String,
      codeValue: (json['codeValue'] ?? json['code_value'] ?? '') as String,
      codeType: json['codeType'] as String?,
      lotNumber: json['lotNumber'] as String?,
      bundleCode: json['bundleCode'] as String?,
      sizeLabel: json['sizeLabel'] as String?,
      patternNo: parseIntNullable(json['patternNo'] ?? json['pattern_no']),
      masterName: json['masterName'] as String?,
      userUsername: json['userUsername'] as String?,
      remark: json['remark'] as String?,
      eventStatus: json['eventStatus'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      isClosed: json['isClosed'] == true || json['isClosed'] == 1,
    );
  }
}

class ProductionEntryResponse {
  const ProductionEntryResponse({
    required this.stage,
    required this.success,
    required this.data,
  });

  final String stage;
  final bool success;
  final Map<String, dynamic> data;

  factory ProductionEntryResponse.fromJson(Map<String, dynamic> json) {
    return ProductionEntryResponse(
      stage: (json['stage'] ?? '') as String,
      success: json['success'] == true,
      data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

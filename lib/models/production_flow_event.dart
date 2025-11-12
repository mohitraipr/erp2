class ProductionFlowEvent {
  final int id;
  final String stage;
  final String codeType;
  final String codeValue;
  final int? lotId;
  final int? bundleId;
  final int? sizeId;
  final int? pieceId;
  final String? lotNumber;
  final String? bundleCode;
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
    required this.stage,
    required this.codeType,
    required this.codeValue,
    this.lotId,
    this.bundleId,
    this.sizeId,
    this.pieceId,
    this.lotNumber,
    this.bundleCode,
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
    this.closedByUserId,
    this.closedByUserUsername,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductionFlowEvent.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    bool _parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' || normalized == '1';
      }
      return false;
    }

    return ProductionFlowEvent(
      id: _parseInt(json['id']) ?? 0,
      stage: (json['stage'] ?? '').toString(),
      codeType: (json['codeType'] ?? json['code_type'] ?? '').toString(),
      codeValue: (json['codeValue'] ?? json['code_value'] ?? '').toString(),
      lotId: _parseInt(json['lotId'] ?? json['lot_id']),
      bundleId: _parseInt(json['bundleId'] ?? json['bundle_id']),
      sizeId: _parseInt(json['sizeId'] ?? json['size_id']),
      pieceId: _parseInt(json['pieceId'] ?? json['piece_id']),
      lotNumber: json['lotNumber']?.toString() ?? json['lot_number']?.toString(),
      bundleCode:
          json['bundleCode']?.toString() ?? json['bundle_code']?.toString(),
      sizeLabel:
          json['sizeLabel']?.toString() ?? json['size_label']?.toString(),
      pieceCode:
          json['pieceCode']?.toString() ?? json['piece_code']?.toString(),
      patternCount: _parseInt(json['patternCount'] ?? json['pattern_count']),
      bundleCount: _parseInt(json['bundleCount'] ?? json['bundle_count']),
      piecesTotal: _parseInt(json['piecesTotal'] ?? json['pieces_total']),
      userId: _parseInt(json['userId'] ?? json['user_id']),
      userUsername: json['userUsername']?.toString() ??
          json['user_username']?.toString(),
      userRole: json['userRole']?.toString() ?? json['user_role']?.toString(),
      masterId: _parseInt(json['masterId'] ?? json['master_id']),
      masterName:
          json['masterName']?.toString() ?? json['master_name']?.toString(),
      remark: json['remark']?.toString(),
      eventStatus:
          json['eventStatus']?.toString() ?? json['event_status']?.toString(),
      isClosed: _parseBool(json['isClosed'] ?? json['is_closed']),
      closedByStage: json['closedByStage']?.toString() ??
          json['closed_by_stage']?.toString(),
      closedByUserId:
          _parseInt(json['closedByUserId'] ?? json['closed_by_user_id']),
      closedByUserUsername: json['closedByUserUsername']?.toString() ??
          json['closed_by_user_username']?.toString(),
      closedAt: _parseDate(json['closedAt'] ?? json['closed_at']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

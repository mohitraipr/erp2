class ProductionFlowEntry {
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
  final DateTime createdAt;
  final DateTime? updatedAt;

  ProductionFlowEntry({
    required this.id,
    required this.stage,
    required this.codeType,
    required this.codeValue,
    required this.lotId,
    required this.bundleId,
    required this.sizeId,
    required this.pieceId,
    required this.lotNumber,
    required this.bundleCode,
    required this.sizeLabel,
    required this.pieceCode,
    required this.patternCount,
    required this.bundleCount,
    required this.piecesTotal,
    required this.userId,
    required this.userUsername,
    required this.userRole,
    required this.masterId,
    required this.masterName,
    required this.remark,
    required this.eventStatus,
    required this.isClosed,
    required this.closedByStage,
    required this.closedByUserId,
    required this.closedByUserUsername,
    required this.closedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductionFlowEntry.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.toLowerCase();
        return normalized == 'true' || normalized == '1' || normalized == 'yes';
      }
      return false;
    }

    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }

    return ProductionFlowEntry(
      id: parseInt(json['id']) ?? 0,
      stage: (json['stage'] ?? '') as String,
      codeType: (json['codeType'] ?? json['code_type'] ?? '') as String,
      codeValue: (json['codeValue'] ?? json['code_value'] ?? '') as String,
      lotId: parseInt(json['lotId'] ?? json['lot_id']),
      bundleId: parseInt(json['bundleId'] ?? json['bundle_id']),
      sizeId: parseInt(json['sizeId'] ?? json['size_id']),
      pieceId: parseInt(json['pieceId'] ?? json['piece_id']),
      lotNumber: (json['lotNumber'] ?? json['lot_number']) as String?,
      bundleCode: (json['bundleCode'] ?? json['bundle_code']) as String?,
      sizeLabel: (json['sizeLabel'] ?? json['size_label']) as String?,
      pieceCode: (json['pieceCode'] ?? json['piece_code']) as String?,
      patternCount: parseInt(json['patternCount'] ?? json['pattern_count']),
      bundleCount: parseInt(json['bundleCount'] ?? json['bundle_count']),
      piecesTotal: parseInt(json['piecesTotal'] ?? json['pieces_total']),
      userId: parseInt(json['userId'] ?? json['user_id']),
      userUsername: (json['userUsername'] ?? json['user_username']) as String?,
      userRole: (json['userRole'] ?? json['user_role']) as String?,
      masterId: parseInt(json['masterId'] ?? json['master_id']),
      masterName: (json['masterName'] ?? json['master_name']) as String?,
      remark: (json['remark'] ?? '') as String?,
      eventStatus: (json['eventStatus'] ?? json['event_status']) as String?,
      isClosed: parseBool(json['isClosed'] ?? json['is_closed']),
      closedByStage: (json['closedByStage'] ?? json['closed_by_stage']) as String?,
      closedByUserId: parseInt(json['closedByUserId'] ?? json['closed_by_user_id']),
      closedByUserUsername:
          (json['closedByUserUsername'] ?? json['closed_by_user_username']) as String?,
      closedAt: parseDate(json['closedAt'] ?? json['closed_at']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

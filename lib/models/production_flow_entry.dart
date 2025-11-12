class ProductionFlowEntry {
  final int id;
  final String stage;
  final String? codeType;
  final String codeValue;
  final int? lotId;
  final int? bundleId;
  final int? pieceId;
  final String? lotNumber;
  final String? bundleCode;
  final String? pieceCode;
  final String? sizeLabel;
  final String? eventStatus;
  final int? piecesTotal;
  final int? userId;
  final String? userUsername;
  final String? userRole;
  final String? remark;
  final int? masterId;
  final String? masterName;
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
    required this.codeValue,
    this.codeType,
    this.lotId,
    this.bundleId,
    this.pieceId,
    this.lotNumber,
    this.bundleCode,
    this.pieceCode,
    this.sizeLabel,
    this.eventStatus,
    this.piecesTotal,
    this.userId,
    this.userUsername,
    this.userRole,
    this.remark,
    this.masterId,
    this.masterName,
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
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String && value.isNotEmpty) {
        return int.tryParse(value);
      }
      return null;
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == 'yes') return true;
        if (lower == 'false' || lower == 'no') return false;
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed != 0;
      }
      return false;
    }

    return ProductionFlowEntry(
      id: parseInt(json['id']) ?? 0,
      stage: (json['stage'] ?? '').toString(),
      codeType: json['codeType']?.toString() ?? json['code_type']?.toString(),
      codeValue: (json['codeValue'] ?? json['code_value'] ?? '').toString(),
      lotId: parseInt(json['lotId'] ?? json['lot_id']),
      bundleId: parseInt(json['bundleId'] ?? json['bundle_id']),
      pieceId: parseInt(json['pieceId'] ?? json['piece_id']),
      lotNumber: json['lotNumber']?.toString() ?? json['lot_number']?.toString(),
      bundleCode:
          json['bundleCode']?.toString() ?? json['bundle_code']?.toString(),
      pieceCode: json['pieceCode']?.toString() ?? json['piece_code']?.toString(),
      sizeLabel: json['sizeLabel']?.toString() ?? json['size_label']?.toString(),
      eventStatus:
          json['eventStatus']?.toString() ?? json['event_status']?.toString(),
      piecesTotal:
          parseInt(json['piecesTotal'] ?? json['pieces_total']),
      userId: parseInt(json['userId'] ?? json['user_id']),
      userUsername:
          json['userUsername']?.toString() ?? json['user_username']?.toString(),
      userRole: json['userRole']?.toString() ?? json['user_role']?.toString(),
      remark: json['remark']?.toString(),
      masterId: parseInt(json['masterId'] ?? json['master_id']),
      masterName:
          json['masterName']?.toString() ?? json['master_name']?.toString(),
      isClosed: parseBool(json['isClosed'] ?? json['is_closed']),
      closedByStage: json['closedByStage']?.toString() ??
          json['closed_by_stage']?.toString(),
      closedByUserId:
          parseInt(json['closedByUserId'] ?? json['closed_by_user_id']),
      closedByUserUsername: json['closedByUserUsername']?.toString() ??
          json['closed_by_user_username']?.toString(),
      closedAt: parseDate(json['closedAt'] ?? json['closed_at']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

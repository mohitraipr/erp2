class ProductionEntry {
  final int id;
  final String stage;
  final String codeType;
  final String codeValue;
  final String? lotNumber;
  final String? bundleCode;
  final String? sizeLabel;
  final String? pieceCode;
  final int? patternCount;
  final int? bundleCount;
  final int? piecesTotal;
  final String? userUsername;
  final String? userRole;
  final String? masterName;
  final int? masterId;
  final String eventStatus;
  final bool isClosed;
  final String? closedByStage;
  final String? closedByUsername;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? remark;

  const ProductionEntry({
    required this.id,
    required this.stage,
    required this.codeType,
    required this.codeValue,
    this.lotNumber,
    this.bundleCode,
    this.sizeLabel,
    this.pieceCode,
    this.patternCount,
    this.bundleCount,
    this.piecesTotal,
    this.userUsername,
    this.userRole,
    this.masterName,
    this.masterId,
    required this.eventStatus,
    required this.isClosed,
    this.closedByStage,
    this.closedByUsername,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
    this.remark,
  });

  factory ProductionEntry.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String && value.isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        return parsed;
      }
      return null;
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.toLowerCase();
        return normalized == 'true' || normalized == '1';
      }
      return false;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    String? parseString(dynamic value) {
      if (value == null) return null;
      final str = value.toString();
      return str.isEmpty ? null : str;
    }

    return ProductionEntry(
      id: parseInt(json['id']) ?? 0,
      stage: parseString(json['stage']) ?? '',
      codeType: parseString(json['codeType'] ?? json['code_type']) ?? '',
      codeValue: parseString(json['codeValue'] ?? json['code_value']) ?? '',
      lotNumber: parseString(json['lotNumber'] ?? json['lot_number']),
      bundleCode: parseString(json['bundleCode'] ?? json['bundle_code']),
      sizeLabel: parseString(json['sizeLabel'] ?? json['size_label']),
      pieceCode: parseString(json['pieceCode'] ?? json['piece_code']),
      patternCount: parseInt(json['patternCount'] ?? json['pattern_count']),
      bundleCount: parseInt(json['bundleCount'] ?? json['bundle_count']),
      piecesTotal: parseInt(json['piecesTotal'] ?? json['pieces_total']),
      userUsername:
          parseString(json['userUsername'] ?? json['user_username'] ?? json['username']),
      userRole: parseString(json['userRole'] ?? json['user_role']),
      masterName: parseString(json['masterName'] ?? json['master_name']),
      masterId: parseInt(json['masterId'] ?? json['master_id']),
      eventStatus: parseString(json['eventStatus'] ?? json['event_status']) ?? 'open',
      isClosed: parseBool(json['isClosed'] ?? json['is_closed']),
      closedByStage: parseString(json['closedByStage'] ?? json['closed_by_stage']),
      closedByUsername:
          parseString(json['closedByUserUsername'] ?? json['closed_by_user_username']),
      closedAt: parseDate(json['closedAt'] ?? json['closed_at']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
      remark: parseString(json['remark']),
    );
  }
}

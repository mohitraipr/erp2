class MasterRecord {
  final int id;
  final String masterName;
  final String? contactNumber;
  final String? notes;
  final String? creatorRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MasterRecord({
    required this.id,
    required this.masterName,
    this.contactNumber,
    this.notes,
    this.creatorRole,
    this.createdAt,
    this.updatedAt,
  });

  factory MasterRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    int parseId(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      throw ArgumentError('Invalid id value: $value');
    }

    return MasterRecord(
      id: parseId(json['id']),
      masterName: (json['masterName'] ?? json['master_name'] ?? '').toString(),
      contactNumber:
          (json['contactNumber'] ?? json['contact_number'])?.toString(),
      notes: (json['notes'] ?? json['note'] ?? json['remarks'])?.toString(),
      creatorRole:
          (json['creatorRole'] ?? json['creator_role'])?.toString(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

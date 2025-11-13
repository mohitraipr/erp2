class MasterRecord {
  const MasterRecord({
    required this.id,
    required this.masterName,
    required this.contactNumber,
    this.notes,
    this.creatorRole,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String masterName;
  final String contactNumber;
  final String? notes;
  final String? creatorRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MasterRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    return MasterRecord(
      id: parseInt(json['id'] ?? json['masterId'] ?? 0),
      masterName: (json['masterName'] ?? json['name'] ?? '') as String,
      contactNumber: (json['contactNumber'] ?? json['phone'] ?? '') as String,
      notes: json['notes'] as String?,
      creatorRole: (json['creatorRole'] ?? json['role']) as String?,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

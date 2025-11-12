class UserMaster {
  final int id;
  final String masterName;
  final String? contactNumber;
  final String? notes;
  final String? creatorRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserMaster({
    required this.id,
    required this.masterName,
    this.contactNumber,
    this.notes,
    this.creatorRole,
    this.createdAt,
    this.updatedAt,
  });

  factory UserMaster.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.trim().isEmpty) {
        return null;
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return UserMaster(
      id: _parseInt(json['id']) ?? 0,
      masterName: (json['masterName'] ?? json['master_name'] ?? '') as String,
      contactNumber: (json['contactNumber'] ?? json['contact_number']) as String?,
      notes: json['notes'] as String?,
      creatorRole: (json['creatorRole'] ?? json['creator_role']) as String?,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

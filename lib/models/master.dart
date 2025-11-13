class MasterInfo {
  final int id;
  final String masterName;
  final String? contactNumber;
  final String? notes;
  final String? creatorRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MasterInfo({
    required this.id,
    required this.masterName,
    this.contactNumber,
    this.notes,
    this.creatorRole,
    this.createdAt,
    this.updatedAt,
  });

  factory MasterInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return MasterInfo(
      id: (json['id'] as num).toInt(),
      masterName: (json['masterName'] ?? json['name'] ?? '') as String,
      contactNumber: json['contactNumber'] as String? ?? json['phone'] as String?,
      notes: json['notes'] as String?,
      creatorRole: json['creatorRole'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}

class MasterPayload {
  final String name;
  final String? contactNumber;
  final String? notes;

  const MasterPayload({
    required this.name,
    this.contactNumber,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (contactNumber != null && contactNumber!.isNotEmpty)
          'contactNumber': contactNumber,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

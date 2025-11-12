class Master {
  final int id;
  final String name;
  final String? contactNumber;
  final String? notes;
  final String? creatorRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Master({
    required this.id,
    required this.name,
    this.contactNumber,
    this.notes,
    this.creatorRole,
    this.createdAt,
    this.updatedAt,
  });

  factory Master.fromJson(Map<String, dynamic> json) {
    DateTime? _tryParseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final rawId = json['id'] ?? json['masterId'] ?? json['master_id'];
    final id = rawId is num
        ? rawId.toInt()
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    return Master(
      id: id,
      name: (json['masterName'] ?? json['name'] ?? json['master_name'] ?? '')
          .toString(),
      contactNumber: (json['contactNumber'] ?? json['contact_number'])?.toString(),
      notes: json['notes']?.toString(),
      creatorRole:
          (json['creatorRole'] ?? json['creator_role'])?.toString(),
      createdAt: _tryParseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _tryParseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'masterName': name,
        if (contactNumber != null) 'contactNumber': contactNumber,
        if (notes != null) 'notes': notes,
        if (creatorRole != null) 'creatorRole': creatorRole,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}

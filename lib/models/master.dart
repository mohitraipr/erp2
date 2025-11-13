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
    final idValue = json['id'] ?? json['masterId'] ?? json['master_id'];
    final id = idValue is num
        ? idValue.toInt()
        : int.tryParse(idValue?.toString() ?? '') ?? 0;
    final created = json['createdAt'] ?? json['created_at'];
    final updated = json['updatedAt'] ?? json['updated_at'];

    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return Master(
      id: id,
      name: (json['masterName'] ?? json['name'] ?? '').toString(),
      contactNumber: (json['contactNumber'] ?? json['phone'] ?? json['contact_number'])
          ?.toString(),
      notes: (json['notes'] ?? json['remarks'] ?? json['note'])?.toString(),
      creatorRole: (json['creatorRole'] ?? json['role'] ?? json['created_by'])
          ?.toString(),
      createdAt: parseDate(created),
      updatedAt: parseDate(updated),
    );
  }

  Map<String, dynamic> toRequestBody() {
    return {
      'name': name,
      if (contactNumber != null && contactNumber!.isNotEmpty)
        'contactNumber': contactNumber,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}

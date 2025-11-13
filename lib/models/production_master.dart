class ProductionMaster {
  final int id;
  final String name;
  final String? contactNumber;
  final String? notes;
  final String? creatorRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductionMaster({
    required this.id,
    required this.name,
    this.contactNumber,
    this.notes,
    this.creatorRole,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductionMaster.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    String? _string(dynamic value) {
      if (value == null) return null;
      return value.toString();
    }

    int _int(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    return ProductionMaster(
      id: _int(json['id']),
      name: _string(json['masterName'] ?? json['master_name'] ?? json['name']) ?? '',
      contactNumber: _string(json['contactNumber'] ?? json['contact_number']),
      notes: _string(json['notes']),
      creatorRole: _string(json['creatorRole'] ?? json['creator_role']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  @override
  String toString() => 'ProductionMaster(id: $id, name: $name)';
}

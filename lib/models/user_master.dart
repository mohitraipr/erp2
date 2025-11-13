class UserMaster {
  final int id;
  final String name;
  final String? contactNumber;
  final String? notes;

  const UserMaster({
    required this.id,
    required this.name,
    this.contactNumber,
    this.notes,
  });

  factory UserMaster.fromJson(Map<String, dynamic> json) {
    return UserMaster(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.parse('${json['id']}'),
      name: (json['masterName'] ?? json['master_name'] ?? '').toString(),
      contactNumber:
          (json['contactNumber'] ?? json['contact_number'])?.toString(),
      notes: (json['notes'] ?? json['description'] ?? json['remark'])?.toString(),
    );
  }
}

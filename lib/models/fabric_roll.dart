class FabricRoll {
  final String rollNo;
  final String unit;
  final double perRollWeight;
  final String vendorName;

  FabricRoll({
    required this.rollNo,
    required this.unit,
    required this.perRollWeight,
    required this.vendorName,
  });

  factory FabricRoll.fromJson(Map<String, dynamic> json) {
    return FabricRoll(
      rollNo: json['roll_no'] as String,
      unit: json['unit'] as String,
      perRollWeight: (json['per_roll_weight'] as num).toDouble(),
      vendorName: json['vendor_name'] as String,
    );
  }
}

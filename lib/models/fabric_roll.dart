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
    final dynamic rawWeight = json['per_roll_weight'];
    final double parsedWeight;
    if (rawWeight is num) {
      parsedWeight = rawWeight.toDouble();
    } else if (rawWeight is String) {
      parsedWeight = double.tryParse(rawWeight) ?? 0.0;
    } else {
      parsedWeight = 0.0;
    }

    return FabricRoll(
      rollNo: json['roll_no'] as String,
      unit: json['unit'] as String,
      perRollWeight: parsedWeight,
      vendorName: json['vendor_name'] as String,
    );
  }
}

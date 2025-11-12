class BundleInfo {
  final int bundleId;
  final String bundleCode;
  final int piecesInBundle;
  final int lotId;
  final String lotNumber;
  final String? sku;
  final String? fabricType;
  final int pieceCount;

  const BundleInfo({
    required this.bundleId,
    required this.bundleCode,
    required this.piecesInBundle,
    required this.lotId,
    required this.lotNumber,
    this.sku,
    this.fabricType,
    required this.pieceCount,
  });

  factory BundleInfo.fromJson(Map<String, dynamic> json) {
    return BundleInfo(
      bundleId: _readInt(json['bundleId']) ?? _readInt(json['id']) ?? 0,
      bundleCode: (json['bundleCode'] ?? json['bundle_code'] ?? '').toString(),
      piecesInBundle:
          _readInt(json['piecesInBundle']) ?? _readInt(json['pieces_in_bundle']) ?? 0,
      lotId: _readInt(json['lotId']) ?? _readInt(json['lot_id']) ?? 0,
      lotNumber: (json['lotNumber'] ?? json['lot_number'] ?? '').toString(),
      sku: json['sku']?.toString(),
      fabricType: (json['fabricType'] ?? json['fabric_type'])?.toString(),
      pieceCount: _readInt(json['pieceCount']) ?? _readInt(json['pieces']) ?? 0,
    );
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString());
    return parsed;
  }
}

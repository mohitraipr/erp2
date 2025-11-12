class ProductionBundleSummary {
  final int bundleId;
  final String bundleCode;
  final int piecesInBundle;
  final int lotId;
  final String lotNumber;
  final String? sku;
  final String? fabricType;
  final int pieceCount;

  const ProductionBundleSummary({
    required this.bundleId,
    required this.bundleCode,
    required this.piecesInBundle,
    required this.lotId,
    required this.lotNumber,
    required this.sku,
    required this.fabricType,
    required this.pieceCount,
  });

  factory ProductionBundleSummary.fromJson(Map<String, dynamic> json) {
    int _parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    return ProductionBundleSummary(
      bundleId: _parseInt(json['bundleId'] ?? json['id'] ?? json['bundle_id']),
      bundleCode: (json['bundleCode'] ?? json['bundle_code'] ?? '') as String,
      piecesInBundle: _parseInt(json['piecesInBundle'] ?? json['pieces_in_bundle']),
      lotId: _parseInt(json['lotId'] ?? json['lot_id']),
      lotNumber: (json['lotNumber'] ?? json['lot_number'] ?? '') as String,
      sku: json['sku'] as String?,
      fabricType: (json['fabricType'] ?? json['fabric_type']) as String?,
      pieceCount: _parseInt(json['pieceCount'] ?? json['piece_count']),
    );
  }
}

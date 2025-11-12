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
    required this.pieceCount,
    this.sku,
    this.fabricType,
  });

  factory BundleInfo.fromJson(Map<String, dynamic> json) {
    final bundle = json.containsKey('bundle') && json['bundle'] is Map
        ? Map<String, dynamic>.from(json['bundle'] as Map)
        : json;

    int _parseInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '0') ?? 0;
    }

    return BundleInfo(
      bundleId: _parseInt(bundle['bundleId'] ?? bundle['id']),
      bundleCode: (bundle['bundleCode'] ?? bundle['bundle_code'] ?? '')
          .toString(),
      piecesInBundle: _parseInt(
        bundle['piecesInBundle'] ?? bundle['pieces_in_bundle'],
      ),
      lotId: _parseInt(bundle['lotId'] ?? bundle['lot_id']),
      lotNumber: (bundle['lotNumber'] ?? bundle['lot_number'] ?? '')
          .toString(),
      sku: bundle['sku']?.toString(),
      fabricType: bundle['fabricType']?.toString() ??
          bundle['fabric_type']?.toString(),
      pieceCount: _parseInt(bundle['pieceCount'] ?? bundle['pieces'] ?? 0),
    );
  }
}

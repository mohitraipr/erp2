class ProductionLotDetails {
  final int lotId;
  final String lotNumber;
  final int? totalPieces;
  final List<ProductionLotSize> sizes;

  const ProductionLotDetails({
    required this.lotId,
    required this.lotNumber,
    required this.sizes,
    this.totalPieces,
  });

  factory ProductionLotDetails.fromJson(Map<String, dynamic> json) {
    final lotId = _parseInt(json['lotId'] ?? json['lot_id'] ?? json['id']);
    final lotNumber = (json['lotNumber'] ?? json['lot_number'] ?? '').toString();
    final totalPieces = _tryParseInt(json['totalPieces'] ?? json['total_pieces']);

    final sizesJson = json['sizes'];
    final sizes = <ProductionLotSize>[];
    if (sizesJson is Iterable) {
      for (final item in sizesJson) {
        if (item is Map<String, dynamic>) {
          sizes.add(ProductionLotSize.fromJson(item));
        } else if (item is Map) {
          sizes.add(ProductionLotSize.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    return ProductionLotDetails(
      lotId: lotId,
      lotNumber: lotNumber,
      totalPieces: totalPieces,
      sizes: sizes,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class ProductionLotSize {
  final int sizeId;
  final String sizeLabel;
  final int? patternCount;
  final int? bundleCount;
  final int? totalPieces;
  final List<ProductionBundle> bundles;

  const ProductionLotSize({
    required this.sizeId,
    required this.sizeLabel,
    required this.bundles,
    this.patternCount,
    this.bundleCount,
    this.totalPieces,
  });

  factory ProductionLotSize.fromJson(Map<String, dynamic> json) {
    final bundlesJson = json['bundles'];
    final bundles = <ProductionBundle>[];
    if (bundlesJson is Iterable) {
      for (final item in bundlesJson) {
        if (item is Map<String, dynamic>) {
          bundles.add(ProductionBundle.fromJson(item));
        } else if (item is Map) {
          bundles.add(ProductionBundle.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    return ProductionLotSize(
      sizeId: ProductionLotDetails._parseInt(
        json['sizeId'] ?? json['size_id'] ?? json['id'],
      ),
      sizeLabel: (json['sizeLabel'] ?? json['size_label'] ?? '').toString(),
      patternCount: ProductionLotDetails._tryParseInt(
        json['patternCount'] ?? json['pattern_count'],
      ),
      bundleCount: ProductionLotDetails._tryParseInt(
        json['bundleCount'] ?? json['bundle_count'],
      ),
      totalPieces: ProductionLotDetails._tryParseInt(
        json['totalPieces'] ?? json['total_pieces'],
      ),
      bundles: bundles,
    );
  }
}

class ProductionBundle {
  final int bundleId;
  final String bundleCode;
  final int? bundleSequence;
  final int? piecesInBundle;

  const ProductionBundle({
    required this.bundleId,
    required this.bundleCode,
    this.bundleSequence,
    this.piecesInBundle,
  });

  factory ProductionBundle.fromJson(Map<String, dynamic> json) {
    return ProductionBundle(
      bundleId: ProductionLotDetails._parseInt(
        json['bundleId'] ?? json['bundle_id'] ?? json['id'],
      ),
      bundleCode: (json['bundleCode'] ?? json['bundle_code'] ?? '').toString(),
      bundleSequence: ProductionLotDetails._tryParseInt(
        json['bundleSequence'] ?? json['bundle_sequence'],
      ),
      piecesInBundle: ProductionLotDetails._tryParseInt(
        json['piecesInBundle'] ??
            json['pieces_in_bundle'] ??
            json['pieces'],
      ),
    );
  }
}

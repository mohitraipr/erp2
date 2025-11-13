class ApiLotSummary {
  final int id;
  final String lotNumber;
  final String sku;
  final String fabricType;
  final int? bundleSize;
  final int? totalBundles;
  final int? totalPieces;
  final double? totalWeight;
  final DateTime? createdAt;

  ApiLotSummary({
    required this.id,
    required this.lotNumber,
    required this.sku,
    required this.fabricType,
    this.bundleSize,
    this.totalBundles,
    this.totalPieces,
    this.totalWeight,
    this.createdAt,
  });

  factory ApiLotSummary.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final createdValue = json['createdAt'] ?? json['created_at'];
    if (createdValue is String && createdValue.isNotEmpty) {
      createdAt = DateTime.tryParse(createdValue);
    }

    final idValue =
        json['id'] ?? json['lotId'] ?? json['lot_id'] ?? json['lotID'] ?? 0;
    final intId = idValue is num
        ? idValue.toInt()
        : int.tryParse(idValue.toString()) ?? 0;

    return ApiLotSummary(
      id: intId,
      lotNumber:
          (json['lotNumber'] ?? json['lot_number'] ?? json['lotNo'] ?? json['lot_no'] ?? '')
              as String,
      sku: (json['sku'] ?? '') as String,
      fabricType: (json['fabricType'] ?? json['fabric_type'] ?? '') as String,
      bundleSize: _readInt(json['bundleSize'] ?? json['bundle_size']),
      totalBundles: _readInt(json['totalBundles'] ?? json['total_bundles']),
      totalPieces: _readInt(json['totalPieces'] ?? json['total_pieces']),
      totalWeight: _readDouble(json['totalWeight'] ?? json['total_weight']),
      createdAt: createdAt,
    );
  }

  ApiLot toDetail({
    List<ApiLotSize> sizes = const [],
    List<ApiLotBundle> bundles = const [],
    List<ApiLotPiece> pieces = const [],
    List<ApiLotPatternGroup> patterns = const [],
    LotDownloads? downloads,
    String? remark,
  }) {
    return ApiLot(
      id: id,
      lotNumber: lotNumber,
      sku: sku,
      fabricType: fabricType,
      bundleSize: bundleSize,
      totalBundles: totalBundles,
      totalPieces: totalPieces,
      totalWeight: totalWeight,
      createdAt: createdAt,
      sizes: sizes,
      bundles: bundles,
      pieces: pieces,
      patterns: patterns,
      downloads: downloads,
      remark: remark,
    );
  }

  static int? _readInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class ApiLot extends ApiLotSummary {
  final List<ApiLotSize> sizes;
  final List<ApiLotBundle> bundles;
  final List<ApiLotPiece> pieces;
  final LotDownloads? downloads;
  final String? remark;
  final List<ApiLotPatternGroup> patterns;

  ApiLot({
    required super.id,
    required super.lotNumber,
    required super.sku,
    required super.fabricType,
    super.bundleSize,
    super.totalBundles,
    super.totalPieces,
    super.totalWeight,
    super.createdAt,
    this.sizes = const [],
    this.bundles = const [],
    this.pieces = const [],
    this.downloads,
    this.remark,
    this.patterns = const [],
  });

  factory ApiLot.fromJson(Map<String, dynamic> json) {
    final summary = ApiLotSummary.fromJson(json);
    final List<ApiLotSize> sizes = (json['sizes'] as List?)
            ?.whereType<Map>()
            .map((e) => ApiLotSize.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [];
    final List<ApiLotBundle> bundles = (json['bundles'] as List?)
            ?.whereType<Map>()
            .map((e) => ApiLotBundle.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [];
    final List<ApiLotPiece> pieces = (json['pieces'] as List?)
            ?.whereType<Map>()
            .map((e) => ApiLotPiece.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [];
    final List<ApiLotPatternGroup> patterns = (json['patterns'] as List?)
            ?.whereType<Map>()
            .map((e) =>
                ApiLotPatternGroup.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [];

    final downloadsJson = json['downloads'];
    final downloads = downloadsJson is Map<String, dynamic>
        ? LotDownloads.fromJson(downloadsJson)
        : null;

    return summary.toDetail(
      sizes: sizes,
      bundles: bundles,
      pieces: pieces,
      patterns: patterns,
      downloads: downloads,
      remark: json['remark'] as String?,
    );
  }
}

class ApiLotSize {
  final String sizeLabel;
  final int? patternCount;
  final int? totalPieces;
  final int? bundleCount;

  ApiLotSize({
    required this.sizeLabel,
    this.patternCount,
    this.totalPieces,
    this.bundleCount,
  });

  factory ApiLotSize.fromJson(Map<String, dynamic> json) {
    return ApiLotSize(
      sizeLabel: (json['sizeLabel'] ?? json['size_label'] ?? '') as String,
      patternCount: ApiLotSummary._readInt(json['patternCount'] ?? json['pattern_count']),
      totalPieces: ApiLotSummary._readInt(json['totalPieces'] ?? json['total_pieces']),
      bundleCount: ApiLotSummary._readInt(json['bundleCount'] ?? json['bundle_count']),
    );
  }
}

class ApiLotBundle {
  final String bundleCode;
  final String sizeLabel;
  final int? piecesInBundle;
  final int? bundleId;
  final int? patternId;
  final int? patternNo;
  final int? bundleSequence;

  ApiLotBundle({
    required this.bundleCode,
    required this.sizeLabel,
    this.piecesInBundle,
    this.bundleId,
    this.patternId,
    this.patternNo,
    this.bundleSequence,
  });

  factory ApiLotBundle.fromJson(Map<String, dynamic> json) {
    return ApiLotBundle(
      bundleCode: (json['bundleCode'] ?? json['bundle_code'] ?? '') as String,
      sizeLabel: (json['sizeLabel'] ?? json['size_label'] ?? '') as String,
      piecesInBundle: ApiLotSummary._readInt(
        json['pieces'] ?? json['piecesInBundle'] ?? json['pieces_in_bundle'],
      ),
      bundleId: ApiLotSummary._readInt(json['bundleId'] ?? json['bundle_id']),
      patternId:
          ApiLotSummary._readInt(json['patternId'] ?? json['pattern_id']),
      patternNo:
          ApiLotSummary._readInt(json['patternNo'] ?? json['pattern_no']),
      bundleSequence: ApiLotSummary._readInt(
          json['bundleSequence'] ?? json['bundle_sequence']),
    );
  }
}

class ApiLotPiece {
  final String pieceCode;
  final String bundleCode;
  final String sizeLabel;
  final int? patternId;
  final int? patternNo;
  final int? bundleId;

  ApiLotPiece({
    required this.pieceCode,
    required this.bundleCode,
    required this.sizeLabel,
    this.patternId,
    this.patternNo,
    this.bundleId,
  });

  factory ApiLotPiece.fromJson(Map<String, dynamic> json) {
    return ApiLotPiece(
      pieceCode: (json['pieceCode'] ?? json['piece_code'] ?? '') as String,
      bundleCode: (json['bundleCode'] ?? json['bundle_code'] ?? '') as String,
      sizeLabel: (json['sizeLabel'] ?? json['size_label'] ?? '') as String,
      patternId:
          ApiLotSummary._readInt(json['patternId'] ?? json['pattern_id']),
      patternNo:
          ApiLotSummary._readInt(json['patternNo'] ?? json['pattern_no']),
      bundleId: ApiLotSummary._readInt(json['bundleId'] ?? json['bundle_id']),
    );
  }
}

class LotDownloads {
  final String? bundleCodesUrl;
  final String? pieceCodesUrl;

  const LotDownloads({this.bundleCodesUrl, this.pieceCodesUrl});

  factory LotDownloads.fromJson(Map<String, dynamic> json) {
    return LotDownloads(
      bundleCodesUrl: json['bundleCodes'] as String?,
      pieceCodesUrl: json['pieceCodes'] as String?,
    );
  }
}

class ApiLotPatternGroup {
  final int? sizeId;
  final String sizeLabel;
  final List<ApiLotPattern> patterns;

  const ApiLotPatternGroup({
    this.sizeId,
    required this.sizeLabel,
    this.patterns = const [],
  });

  factory ApiLotPatternGroup.fromJson(Map<String, dynamic> json) {
    final sizeId = ApiLotSummary._readInt(json['sizeId'] ?? json['size_id']);
    final sizeLabel =
        (json['sizeLabel'] ?? json['size_label'] ?? '') as String? ?? '';
    final patterns = (json['patterns'] as List?)
            ?.whereType<Map>()
            .map((e) => ApiLotPattern.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <ApiLotPattern>[];

    return ApiLotPatternGroup(
      sizeId: sizeId,
      sizeLabel: sizeLabel,
      patterns: patterns,
    );
  }
}

class ApiLotPattern {
  final int? patternId;
  final int? patternNo;
  final int? piecesTotal;
  final int? bundleCount;
  final List<ApiLotPatternBundle> bundles;

  const ApiLotPattern({
    this.patternId,
    this.patternNo,
    this.piecesTotal,
    this.bundleCount,
    this.bundles = const [],
  });

  factory ApiLotPattern.fromJson(Map<String, dynamic> json) {
    final bundles = (json['bundles'] as List?)
            ?.whereType<Map>()
            .map((e) =>
                ApiLotPatternBundle.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <ApiLotPatternBundle>[];

    return ApiLotPattern(
      patternId:
          ApiLotSummary._readInt(json['patternId'] ?? json['pattern_id']),
      patternNo:
          ApiLotSummary._readInt(json['patternNo'] ?? json['pattern_no']),
      piecesTotal:
          ApiLotSummary._readInt(json['piecesTotal'] ?? json['pieces_total']),
      bundleCount: ApiLotSummary._readInt(
          json['bundleCount'] ?? json['bundle_count']),
      bundles: bundles,
    );
  }
}

class ApiLotPatternBundle {
  final int? bundleId;
  final String? bundleCode;
  final int? piecesInBundle;

  const ApiLotPatternBundle({this.bundleId, this.bundleCode, this.piecesInBundle});

  factory ApiLotPatternBundle.fromJson(Map<String, dynamic> json) {
    return ApiLotPatternBundle(
      bundleId: ApiLotSummary._readInt(json['bundleId'] ?? json['bundle_id']),
      bundleCode: json['bundleCode'] as String?,
      piecesInBundle: ApiLotSummary._readInt(
          json['piecesInBundle'] ?? json['pieces_in_bundle'] ?? json['pieces']),
    );
  }
}

class LotRollUsage {
  final String rollNo;
  final double weightUsed;
  final int layers;

  const LotRollUsage({
    required this.rollNo,
    required this.weightUsed,
    required this.layers,
  });

  Map<String, dynamic> toJson() => {
        'rollNo': rollNo,
        'weightUsed': weightUsed,
        'layers': layers,
      };

  factory LotRollUsage.fromJson(Map<String, dynamic> json) {
    final weight = json['weightUsed'] ?? json['weight_used'] ?? json['weight'];
    final layersValue = json['layers'];
    return LotRollUsage(
      rollNo: (json['rollNo'] ?? json['roll_no'] ?? '') as String,
      weightUsed: weight is num
          ? weight.toDouble()
          : double.tryParse(weight?.toString() ?? '') ?? 0,
      layers: layersValue is num ? layersValue.toInt() : int.tryParse(layersValue?.toString() ?? '0') ?? 0,
    );
  }
}

class LotSizeInfo {
  final int? sizeId;
  final String sizeLabel;
  final int patternCount;
  final int? totalPieces;
  final int? bundleCount;
  final List<LotPatternInfo> patterns;

  const LotSizeInfo({
    this.sizeId,
    required this.sizeLabel,
    required this.patternCount,
    this.totalPieces,
    this.bundleCount,
    this.patterns = const [],
  });

  Map<String, dynamic> toJson() => {
        'sizeLabel': sizeLabel,
        'patternCount': patternCount,
      };

  factory LotSizeInfo.fromJson(Map<String, dynamic> json) {
    return LotSizeInfo(
      sizeId: json['sizeId'] is num ? (json['sizeId'] as num).toInt() : json['id'] as int?,
      sizeLabel: (json['sizeLabel'] ?? json['label'] ?? '') as String,
      patternCount: (json['patternCount'] ?? json['patterns']?.length ?? 0) is num
          ? ((json['patternCount'] ?? json['patterns']?.length ?? 0) as num).toInt()
          : int.tryParse(json['patternCount']?.toString() ?? '0') ?? 0,
      totalPieces: json['totalPieces'] is num ? (json['totalPieces'] as num).toInt() : null,
      bundleCount: json['bundleCount'] is num ? (json['bundleCount'] as num).toInt() : null,
      patterns: (json['patterns'] as List?)
              ?.map((e) => LotPatternInfo.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const [],
    );
  }
}

class LotPatternInfo {
  final int patternId;
  final int patternNo;
  final int? piecesTotal;
  final int? bundleCount;
  final List<LotBundleInfo> bundles;

  const LotPatternInfo({
    required this.patternId,
    required this.patternNo,
    this.piecesTotal,
    this.bundleCount,
    this.bundles = const [],
  });

  factory LotPatternInfo.fromJson(Map<String, dynamic> json) {
    return LotPatternInfo(
      patternId: (json['patternId'] ?? json['id'] ?? 0) is num
          ? ((json['patternId'] ?? json['id']) as num).toInt()
          : int.tryParse(json['patternId']?.toString() ?? '0') ?? 0,
      patternNo: (json['patternNo'] ?? json['pattern_no'] ?? 0) is num
          ? ((json['patternNo'] ?? json['pattern_no']) as num).toInt()
          : int.tryParse(json['patternNo']?.toString() ?? '0') ?? 0,
      piecesTotal: json['piecesTotal'] is num ? (json['piecesTotal'] as num).toInt() : null,
      bundleCount: json['bundleCount'] is num ? (json['bundleCount'] as num).toInt() : null,
      bundles: (json['bundles'] as List?)
              ?.map((e) => LotBundleInfo.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const [],
    );
  }
}

class LotBundleInfo {
  final int? bundleId;
  final String bundleCode;
  final int? bundleSequence;
  final String sizeLabel;
  final int? patternId;
  final int? patternNo;
  final int? pieces;

  const LotBundleInfo({
    this.bundleId,
    required this.bundleCode,
    this.bundleSequence,
    required this.sizeLabel,
    this.patternId,
    this.patternNo,
    this.pieces,
  });

  factory LotBundleInfo.fromJson(Map<String, dynamic> json) {
    final idValue = json['bundleId'] ?? json['id'];
    final seqValue = json['bundleSequence'] ?? json['sequence'];
    final piecesValue = json['pieces'] ?? json['piecesInBundle'];
    return LotBundleInfo(
      bundleId: idValue is num ? idValue.toInt() : int.tryParse(idValue?.toString() ?? ''),
      bundleCode: (json['bundleCode'] ?? json['code'] ?? '') as String,
      bundleSequence: seqValue is num ? seqValue.toInt() : int.tryParse(seqValue?.toString() ?? ''),
      sizeLabel: (json['sizeLabel'] ?? json['size'] ?? '') as String,
      patternId: json['patternId'] is num ? (json['patternId'] as num).toInt() : null,
      patternNo: json['patternNo'] is num ? (json['patternNo'] as num).toInt() : null,
      pieces: piecesValue is num ? piecesValue.toInt() : int.tryParse(piecesValue?.toString() ?? ''),
    );
  }
}

class LotPieceInfo {
  final String pieceCode;
  final String bundleCode;
  final String sizeLabel;
  final int? patternId;
  final int? patternNo;

  const LotPieceInfo({
    required this.pieceCode,
    required this.bundleCode,
    required this.sizeLabel,
    this.patternId,
    this.patternNo,
  });

  factory LotPieceInfo.fromJson(Map<String, dynamic> json) {
    return LotPieceInfo(
      pieceCode: (json['pieceCode'] ?? '') as String,
      bundleCode: (json['bundleCode'] ?? '') as String,
      sizeLabel: (json['sizeLabel'] ?? '') as String,
      patternId: json['patternId'] is num ? (json['patternId'] as num).toInt() : null,
      patternNo: json['patternNo'] is num ? (json['patternNo'] as num).toInt() : null,
    );
  }
}

class LotSummary {
  final int id;
  final String lotNumber;
  final int? cuttingMasterId;
  final String sku;
  final String fabricType;
  final String? remark;
  final int bundleSize;
  final int? totalBundles;
  final int? totalPieces;
  final double? totalWeight;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final LotDownloadLinks downloads;

  const LotSummary({
    required this.id,
    required this.lotNumber,
    this.cuttingMasterId,
    required this.sku,
    required this.fabricType,
    this.remark,
    required this.bundleSize,
    this.totalBundles,
    this.totalPieces,
    this.totalWeight,
    this.createdAt,
    this.updatedAt,
    required this.downloads,
  });

  factory LotSummary.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    DateTime? parseDate(String? value) {
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    return LotSummary(
      id: (json['id'] as num).toInt(),
      lotNumber: (json['lotNumber'] ?? json['lot_number'] ?? '') as String,
      cuttingMasterId: json['cuttingMasterId'] is num ? (json['cuttingMasterId'] as num).toInt() : null,
      sku: (json['sku'] ?? '') as String,
      fabricType: (json['fabricType'] ?? '') as String,
      remark: json['remark'] as String?,
      bundleSize: (json['bundleSize'] as num).toInt(),
      totalBundles: json['totalBundles'] is num ? (json['totalBundles'] as num).toInt() : null,
      totalPieces: json['totalPieces'] is num ? (json['totalPieces'] as num).toInt() : null,
      totalWeight: parseDouble(json['totalWeight']),
      createdAt: parseDate(json['createdAt'] as String?),
      updatedAt: parseDate(json['updatedAt'] as String?),
      downloads: LotDownloadLinks.fromJson(json['downloads'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class LotDownloadLinks {
  final String? bundleCodes;
  final String? pieceCodes;

  const LotDownloadLinks({this.bundleCodes, this.pieceCodes});

  factory LotDownloadLinks.fromJson(Map<String, dynamic> json) => LotDownloadLinks(
        bundleCodes: json['bundleCodes'] as String?,
        pieceCodes: json['pieceCodes'] as String?,
      );
}

class LotDetail {
  final String lotNumber;
  final String sku;
  final String fabricType;
  final int? totalPieces;
  final LotDownloadLinks downloads;
  final List<LotSizeInfo> sizes;
  final List<LotPatternInfo> patterns;
  final List<LotBundleInfo> bundles;
  final List<LotPieceInfo> pieces;

  const LotDetail({
    required this.lotNumber,
    required this.sku,
    required this.fabricType,
    this.totalPieces,
    this.downloads = const LotDownloadLinks(),
    this.sizes = const [],
    this.patterns = const [],
    this.bundles = const [],
    this.pieces = const [],
  });

  factory LotDetail.fromJson(Map<String, dynamic> json) {
    return LotDetail(
      lotNumber: (json['lotNumber'] ?? '') as String,
      sku: (json['sku'] ?? '') as String,
      fabricType: (json['fabricType'] ?? '') as String,
      totalPieces: json['totalPieces'] is num ? (json['totalPieces'] as num).toInt() : null,
      downloads: LotDownloadLinks.fromJson(json['downloads'] as Map<String, dynamic>? ?? const {}),
      sizes: (json['sizes'] as List?)
              ?.map((e) => LotSizeInfo.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const [],
      patterns: (json['patterns'] as List?)
              ?.expand((e) {
                final map = e as Map<String, dynamic>;
                final patterns = (map['patterns'] as List?) ?? const [];
                return patterns.map((p) {
                  final patternJson = <String, dynamic>{...p as Map<String, dynamic>};
                  patternJson['sizeLabel'] = map['sizeLabel'];
                  return LotPatternInfo.fromJson(patternJson);
                });
              }).toList(growable: false) ??
          const [],
      bundles: (json['bundles'] as List?)
              ?.map((e) => LotBundleInfo.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const [],
      pieces: (json['pieces'] as List?)
              ?.map((e) => LotPieceInfo.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const [],
    );
  }
}

class LotCreationRequest {
  final String sku;
  final String fabricType;
  final String? remark;
  final int bundleSize;
  final List<LotSizeInfo> sizes;
  final List<LotRollUsage> rolls;

  const LotCreationRequest({
    required this.sku,
    required this.fabricType,
    this.remark,
    required this.bundleSize,
    required this.sizes,
    required this.rolls,
  });

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'fabricType': fabricType,
      if (remark != null && remark!.isNotEmpty) 'remark': remark,
      'bundleSize': bundleSize,
      'sizes': sizes.map((s) => s.toJson()).toList(),
      'rolls': rolls.map((r) => r.toJson()).toList(),
    };
  }
}

extension LotCreationValidation on LotCreationRequest {
  List<String> validate() {
    final errors = <String>[];
    if (sku.trim().isEmpty) errors.add('SKU is required');
    if (fabricType.trim().isEmpty) errors.add('Fabric type is required');
    if (bundleSize <= 0) errors.add('Bundle size must be positive');
    if (sizes.isEmpty) errors.add('At least one size is required');
    for (final size in sizes) {
      if (size.sizeLabel.trim().isEmpty) {
        errors.add('Size label cannot be empty');
      }
      if (size.patternCount <= 0) {
        errors.add('Pattern count for ${size.sizeLabel} must be positive');
      }
    }
    if (rolls.isEmpty) errors.add('At least one roll selection is required');
    for (final roll in rolls) {
      if (roll.rollNo.trim().isEmpty) errors.add('Roll number cannot be empty');
      if (roll.weightUsed <= 0) errors.add('Weight used for roll ${roll.rollNo} must be greater than 0');
      if (roll.layers <= 0) errors.add('Layers for roll ${roll.rollNo} must be positive');
    }
    return errors;
  }
}

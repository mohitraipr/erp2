class ProductionLotPreview {
  final int lotId;
  final String lotNumber;
  final int? totalPieces;
  final int totalBundles;
  final int assignedBundles;
  final int openBundles;
  final int closedBundles;
  final List<ProductionLotSize> sizes;

  ProductionLotPreview({
    required this.lotId,
    required this.lotNumber,
    required this.totalPieces,
    required this.totalBundles,
    required this.assignedBundles,
    required this.openBundles,
    required this.closedBundles,
    required this.sizes,
  });

  factory ProductionLotPreview.fromJson(Map<String, dynamic> json) {
    int _readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return 0;
    }

    int? _readNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String && value.trim().isNotEmpty) {
        return int.tryParse(value.trim());
      }
      return null;
    }

    final sizesJson = json['sizes'];
    final sizes = sizesJson is Iterable
        ? sizesJson
            .whereType<Map>()
            .map((e) =>
                ProductionLotSize.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <ProductionLotSize>[];

    return ProductionLotPreview(
      lotId: _readInt(json['lotId'] ?? json['lot_id']),
      lotNumber:
          (json['lotNumber'] ?? json['lot_number'] ?? '').toString().trim(),
      totalPieces: _readNullableInt(json['totalPieces'] ?? json['total_pieces']),
      totalBundles: _readInt(json['totalBundles'] ?? json['total_bundles']),
      assignedBundles:
          _readInt(json['assignedBundles'] ?? json['assigned_bundles']),
      openBundles: _readInt(json['openBundles'] ?? json['open_bundles']),
      closedBundles: _readInt(json['closedBundles'] ?? json['closed_bundles']),
      sizes: sizes,
    );
  }
}

class ProductionLotSize {
  final int sizeId;
  final String sizeLabel;
  final int? patternCount;
  final int? totalPieces;
  final int? bundleCount;
  final int totalBundles;
  final int assignedBundles;
  final int openBundles;
  final int closedBundles;
  final List<ProductionLotBundle> bundles;

  ProductionLotSize({
    required this.sizeId,
    required this.sizeLabel,
    required this.patternCount,
    required this.totalPieces,
    required this.bundleCount,
    required this.totalBundles,
    required this.assignedBundles,
    required this.openBundles,
    required this.closedBundles,
    required this.bundles,
  });

  factory ProductionLotSize.fromJson(Map<String, dynamic> json) {
    int _readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return 0;
    }

    int? _readNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String && value.trim().isNotEmpty) {
        return int.tryParse(value.trim());
      }
      return null;
    }

    final bundlesJson = json['bundles'];
    final bundles = bundlesJson is Iterable
        ? bundlesJson
            .whereType<Map>()
            .map((e) =>
                ProductionLotBundle.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <ProductionLotBundle>[];

    return ProductionLotSize(
      sizeId: _readInt(json['sizeId'] ?? json['size_id']),
      sizeLabel:
          (json['sizeLabel'] ?? json['size_label'] ?? '').toString().trim(),
      patternCount:
          _readNullableInt(json['patternCount'] ?? json['pattern_count']),
      totalPieces:
          _readNullableInt(json['totalPieces'] ?? json['total_pieces']),
      bundleCount:
          _readNullableInt(json['bundleCount'] ?? json['bundle_count']),
      totalBundles: _readInt(json['totalBundles'] ?? json['total_bundles']),
      assignedBundles:
          _readInt(json['assignedBundles'] ?? json['assigned_bundles']),
      openBundles: _readInt(json['openBundles'] ?? json['open_bundles']),
      closedBundles: _readInt(json['closedBundles'] ?? json['closed_bundles']),
      bundles: bundles,
    );
  }

  int get pendingBundles => totalBundles - assignedBundles;

  bool get hasAssignments => assignedBundles > 0;
}

class ProductionLotBundle {
  final int bundleId;
  final String bundleCode;
  final int? piecesInBundle;
  final bool assigned;
  final bool isClosed;
  final int? masterId;
  final String? masterName;
  final String? eventStatus;
  final DateTime? createdAt;
  final DateTime? closedAt;

  ProductionLotBundle({
    required this.bundleId,
    required this.bundleCode,
    required this.piecesInBundle,
    required this.assigned,
    required this.isClosed,
    required this.masterId,
    required this.masterName,
    required this.eventStatus,
    required this.createdAt,
    required this.closedAt,
  });

  factory ProductionLotBundle.fromJson(Map<String, dynamic> json) {
    int _readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return 0;
    }

    int? _readNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String && value.trim().isNotEmpty) {
        return int.tryParse(value.trim());
      }
      return null;
    }

    bool _readBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == 'yes') return true;
        if (lower == 'false' || lower == 'no') return false;
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed != 0;
      }
      return false;
    }

    DateTime? _readDate(dynamic value) {
      if (value is DateTime) return value.toLocal();
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    return ProductionLotBundle(
      bundleId: _readInt(json['bundleId'] ?? json['bundle_id']),
      bundleCode:
          (json['bundleCode'] ?? json['bundle_code'] ?? '').toString().trim(),
      piecesInBundle: _readNullableInt(
        json['piecesInBundle'] ?? json['pieces_in_bundle'] ?? json['pieces'],
      ),
      assigned: _readBool(json['assigned']),
      isClosed: _readBool(json['isClosed'] ?? json['closed']),
      masterId: _readNullableInt(json['masterId'] ?? json['master_id']),
      masterName:
          json['masterName']?.toString() ?? json['master_name']?.toString(),
      eventStatus:
          json['eventStatus']?.toString() ?? json['event_status']?.toString(),
      createdAt: _readDate(json['createdAt'] ?? json['created_at']),
      closedAt: _readDate(json['closedAt'] ?? json['closed_at']),
    );
  }
}

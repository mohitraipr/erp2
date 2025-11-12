class ProductionFlowSubmissionResult {
  final String stage;
  final String? lotNumber;
  final String? bundleCode;
  final String? pieceCode;
  final int? pieces;
  final int? piecesRegistered;
  final int? closedBackPocket;
  final int? closedStitching;
  final int? closedJeansAssembly;
  final int? washingInClosed;
  final int? masterId;
  final String? masterName;
  final List<String> rejectedPieces;
  final List<SizeAssignmentSummary> assignments;
  final Map<String, dynamic> rawData;

  const ProductionFlowSubmissionResult({
    required this.stage,
    required this.rawData,
    this.lotNumber,
    this.bundleCode,
    this.pieceCode,
    this.pieces,
    this.piecesRegistered,
    this.closedBackPocket,
    this.closedStitching,
    this.closedJeansAssembly,
    this.washingInClosed,
    this.masterId,
    this.masterName,
    this.rejectedPieces = const [],
    this.assignments = const [],
  });

  factory ProductionFlowSubmissionResult.fromJson(
      String stage, Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};

    List<String> _parseRejected(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    List<SizeAssignmentSummary> _parseAssignments(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => SizeAssignmentSummary.fromJson(
                Map<String, dynamic>.from(item)))
            .toList();
      }
      return const [];
    }

    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return ProductionFlowSubmissionResult(
      stage: stage,
      rawData: data,
      lotNumber:
          data['lotNumber']?.toString() ?? data['lot_number']?.toString(),
      bundleCode:
          data['bundleCode']?.toString() ?? data['bundle_code']?.toString(),
      pieceCode:
          data['pieceCode']?.toString() ?? data['piece_code']?.toString(),
      pieces: _parseInt(data['pieces']),
      piecesRegistered: _parseInt(data['piecesRegistered']),
      closedBackPocket: _parseInt(data['closedBackPocket']),
      closedStitching: _parseInt(data['closedStitching']),
      closedJeansAssembly: _parseInt(data['closedJeansAssembly']),
      washingInClosed: _parseInt(data['washingInClosed']),
      masterId: _parseInt(data['masterId']),
      masterName:
          data['masterName']?.toString() ?? data['master_name']?.toString(),
      rejectedPieces: _parseRejected(
        data['rejectedPieces'] ?? data['rejected_piece_codes'],
      ),
      assignments: _parseAssignments(data['assignments']),
    );
  }
}

class SizeAssignmentSummary {
  final int? sizeId;
  final String? sizeLabel;
  final int? bundles;
  final int? masterId;
  final String? masterName;

  const SizeAssignmentSummary({
    this.sizeId,
    this.sizeLabel,
    this.bundles,
    this.masterId,
    this.masterName,
  });

  factory SizeAssignmentSummary.fromJson(Map<String, dynamic> json) {
    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return SizeAssignmentSummary(
      sizeId: _parseInt(json['sizeId'] ?? json['size_id']),
      sizeLabel:
          json['sizeLabel']?.toString() ?? json['size_label']?.toString(),
      bundles: _parseInt(json['bundles']),
      masterId: _parseInt(json['masterId'] ?? json['master_id']),
      masterName:
          json['masterName']?.toString() ?? json['master_name']?.toString(),
    );
  }
}

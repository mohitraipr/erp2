class ProductionFlowSubmissionResult {
  final bool success;
  final String stage;
  final Map<String, dynamic> data;

  const ProductionFlowSubmissionResult({
    required this.success,
    required this.stage,
    required this.data,
  });

  factory ProductionFlowSubmissionResult.fromJson(Map<String, dynamic> json) {
    final stage = (json['stage'] ?? '') as String;
    final data = <String, dynamic>{};
    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      data.addAll(rawData);
    }
    return ProductionFlowSubmissionResult(
      success: json['success'] == true,
      stage: stage,
      data: data,
    );
  }

  T? value<T>(String key) {
    final v = data[key];
    if (v is T) return v;
    return null;
  }
}

class FilterOptions {
  final List<String> genders;
  final List<String> categories;

  const FilterOptions({
    required this.genders,
    required this.categories,
  });

  factory FilterOptions.fromJson(Map<String, dynamic> json) {
    final genders = (json['genders'] as List?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    final categories = (json['categories'] as List?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    return FilterOptions(
      genders: genders,
      categories: categories,
    );
  }
}

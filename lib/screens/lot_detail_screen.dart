import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_lot.dart';
import '../services/api_client.dart';
import '../utils/download_helper.dart';

class LotDetailScreen extends StatelessWidget {
  const LotDetailScreen({super.key, required this.lot});

  final ApiLot lot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lot ${lot.lotNumber}'),
        actions: [
          IconButton(
            tooltip: 'Download bundles CSV',
            icon: const Icon(Icons.download),
            onPressed: () => _download(context, LotCsvType.bundles),
          ),
          IconButton(
            tooltip: 'Download pieces CSV',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => _download(context, LotCsvType.pieces),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(context),
          const SizedBox(height: 16),
          if (lot.sizes.isNotEmpty) _buildSizesCard(context),
          if (lot.patterns.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPatternsCard(context),
          ],
          if (lot.bundles.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildBundlesCard(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${lot.sku}'),
            Text('Fabric: ${lot.fabricType}'),
            Text('Bundle size: ${lot.bundleSize ?? '-'}'),
            Text('Total bundles: ${lot.totalBundles ?? '-'}'),
            Text('Total pieces: ${lot.totalPieces ?? '-'}'),
            if (lot.remark != null && lot.remark!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Remark: ${lot.remark!}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSizesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sizes',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...lot.sizes.map(
              (size) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(size.sizeLabel),
                subtitle: Text(
                  'Patterns: ${size.patternCount ?? '-'} • Bundles: ${size.bundleCount ?? '-'} • Pieces: ${size.totalPieces ?? '-'}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patterns',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...lot.patterns.map(
              (group) => ExpansionTile(
                title: Text('Size ${group.sizeLabel}'),
                children: group.patterns
                    .map(
                      (pattern) => ListTile(
                        title: Text('Pattern ${pattern.patternNo ?? '-'}'),
                        subtitle: Text(
                            'Bundles: ${pattern.bundleCount ?? '-'} • Pieces: ${pattern.piecesTotal ?? '-'}'),
                        trailing: pattern.bundles.isEmpty
                            ? null
                            : SizedBox(
                                width: 200,
                                child: Wrap(
                                  spacing: 6,
                                  children: pattern.bundles
                                      .map(
                                        (bundle) => Chip(
                                          label: Text(bundle.bundleCode ?? ''),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBundlesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bundles',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...lot.bundles.map(
              (bundle) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(bundle.bundleCode),
                subtitle: Text(
                  'Size: ${bundle.sizeLabel} • Pieces: ${bundle.piecesInBundle ?? '-'} • Pattern ${bundle.patternNo ?? '-'}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context, LotCsvType type) async {
    final api = context.read<ApiClient>();
    try {
      final content = await api.downloadLotCsv(lotId: lot.id, type: type);
      final filename =
          '${lot.lotNumber}_${type == LotCsvType.bundles ? 'bundles' : 'pieces'}.csv';
      final saved = await saveCsvToDevice(filename, content);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? '$filename downloaded.'
                : 'Unable to save $filename on this platform.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

import 'package:flutter/material.dart';

import '../models/api_lot.dart';
import '../providers/data_providers.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';
import '../widgets/async_value_widget.dart';
import '../state/simple_riverpod.dart';

class LotDetailScreen extends ConsumerWidget {
  const LotDetailScreen({
    super.key,
    required this.lotId,
    required this.lotNumber,
    this.canDownload = false,
  });

  final int lotId;
  final String lotNumber;
  final bool canDownload;

  @override
  Widget buildWithRef(BuildContext context, WidgetRef ref) {
    final lotAsync = ref.watch(lotDetailProvider(lotId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Lot $lotNumber'),
        actions: [
          IconButton(
            onPressed: () => ref.refresh(lotDetailProvider(lotId)),
            icon: const Icon(Icons.refresh),
          ),
          if (canDownload)
            PopupMenuButton<LotCsvType>(
              onSelected: (type) => _downloadCsv(context, ref, type),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: LotCsvType.bundles,
                  child: Text('Download bundle codes CSV'),
                ),
                PopupMenuItem(
                  value: LotCsvType.pieces,
                  child: Text('Download piece codes CSV'),
                ),
              ],
            ),
        ],
      ),
      body: AsyncValueWidget<ApiLot>(
        value: lotAsync,
        onRetry: () => ref.refresh(lotDetailProvider(lotId)),
        builder: (lot) {
          return _LotDetailView(lot: lot);
        },
      ),
    );
  }

  Future<void> _downloadCsv(
    BuildContext context,
    WidgetRef ref,
    LotCsvType type,
  ) async {
    final label =
        type == LotCsvType.bundles ? 'bundle codes' : 'piece codes';
    try {
      final saved = await performApiCall(ref, (repo) async {
        final filename = '${lotNumber}_${type.name}.csv';
        final success = await repo.saveCsv(
          lotId: lotId,
          type: type,
          filename: filename,
        );
        if (!success) {
          final csv = await repo.downloadLotCsv(lotId, type);
          return Future.value(csv);
        }
        return null;
      });

      if (saved == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved $label CSV.')),
          );
        }
      } else if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Download not supported'),
            content: SingleChildScrollView(
              child: Text(
                'Automatic download is not available on this platform. '
                'Copy the CSV content below:\n\n$saved',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}

class _LotDetailView extends StatelessWidget {
  const _LotDetailView({required this.lot});

  final ApiLot lot;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lot.lotNumber,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _infoChip('SKU', lot.sku),
                      _infoChip('Fabric', lot.fabricType),
                      if (lot.bundleSize != null)
                        _infoChip('Bundle size', '${lot.bundleSize}'),
                      if (lot.totalPieces != null)
                        _infoChip('Total pieces', '${lot.totalPieces}'),
                      if (lot.totalBundles != null)
                        _infoChip('Bundles', '${lot.totalBundles}'),
                      if (lot.totalWeight != null)
                        _infoChip('Weight', '${lot.totalWeight} kg'),
                    ],
                  ),
                  if (lot.remark != null && lot.remark!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Remark: ${lot.remark}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (lot.sizes.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sizes', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                      },
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFEFF2F7)),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Size', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Patterns', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Pieces', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Bundles', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        ...lot.sizes.map(
                          (size) => TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(size.sizeLabel),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('${size.patternCount ?? '-'}'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('${size.totalPieces ?? '-'}'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('${size.bundleCount ?? '-'}'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (lot.patterns.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                title: const Text('Patterns'),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: lot.patterns.map((group) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${group.sizeLabel} (${group.patterns.length} patterns)',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ...group.patterns.map((pattern) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text('Pattern ${pattern.patternNo}'),
                            subtitle: Text(
                              'Pieces: ${pattern.piecesTotal ?? '-'} · Bundles: ${pattern.bundleCount ?? '-'}',
                            ),
                            isThreeLine: pattern.bundles.isNotEmpty,
                            trailing: Text('#${pattern.patternId}'),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
          if (lot.bundles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                title: Text('Bundles (${lot.bundles.length})'),
                children: lot.bundles.map((bundle) {
                  return ListTile(
                    title: Text(bundle.bundleCode),
                    subtitle: Text('Size ${bundle.sizeLabel}'),
                    trailing: Text('${bundle.piecesInBundle ?? '-'} pcs'),
                  );
                }).toList(),
              ),
            ),
          ],
          if (lot.pieces.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                title: Text('Piece codes (${lot.pieces.length})'),
                children: () {
                  final tiles = lot.pieces.take(50).map((piece) {
                    return ListTile(
                      title: Text(piece.pieceCode),
                      subtitle:
                          Text('Bundle ${piece.bundleCode} · Size ${piece.sizeLabel}'),
                    );
                  }).toList();
                  if (lot.pieces.length > 50) {
                    tiles.add(
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Showing first 50 pieces of ${lot.pieces.length}.'),
                      ),
                    );
                  }
                  return tiles;
                }(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Chip(
      label: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$label\n',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

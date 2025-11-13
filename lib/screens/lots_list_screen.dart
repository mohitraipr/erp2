import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/api_lot.dart';
import '../providers/data_providers.dart';
import '../widgets/async_value_widget.dart';
import 'lot_detail_screen.dart';

class LotsListScreen extends ConsumerWidget {
  const LotsListScreen({
    super.key,
    this.title = 'Lots',
    this.canDownload = false,
  });

  final String title;
  final bool canDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotsAsync = ref.watch(lotsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: () => ref.refresh(lotsProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: AsyncValueWidget<List<ApiLotSummary>>(
        value: lotsAsync,
        onRetry: () => ref.refresh(lotsProvider),
        builder: (lots) {
          if (lots.isEmpty) {
            return const Center(child: Text('No lots available.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final lot = lots[index];
              return _LotTile(lot: lot, canDownload: canDownload);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: lots.length,
          );
        },
      ),
    );
  }
}

class _LotTile extends StatelessWidget {
  const _LotTile({required this.lot, required this.canDownload});

  final ApiLotSummary lot;
  final bool canDownload;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${lot.lotNumber} • ${lot.sku}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fabric: ${lot.fabricType}'),
            if (lot.totalPieces != null)
              Text('Pieces: ${lot.totalPieces} · Bundles: ${lot.totalBundles ?? '-'}'),
            if (lot.createdAt != null)
              Text('Created ${lot.createdAt!.toLocal()}'),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LotDetailScreen(
                lotId: lot.id,
                lotNumber: lot.lotNumber,
                canDownload: canDownload,
              ),
            ),
          );
        },
      ),
    );
  }
}

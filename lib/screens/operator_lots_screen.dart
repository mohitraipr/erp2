import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_lot.dart';
import '../services/api_client.dart';
import 'lot_detail_screen.dart';

class OperatorLotsScreen extends StatefulWidget {
  const OperatorLotsScreen({super.key});

  @override
  State<OperatorLotsScreen> createState() => _OperatorLotsScreenState();
}

class _OperatorLotsScreenState extends State<OperatorLotsScreen> {
  List<ApiLotSummary> _lots = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLots());
  }

  Future<void> _loadLots() async {
    setState(() => _loading = true);
    final api = context.read<ApiClient>();
    try {
      final lots = await api.fetchLots();
      if (!mounted) return;
      setState(() => _lots = lots);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openLot(ApiLotSummary summary) async {
    final api = context.read<ApiClient>();
    try {
      final detail = await api.fetchLotDetail(summary.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LotDetailScreen(lot: detail)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              'No lots available yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadLots, child: const Text('Refresh')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadLots,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _lots.length,
        itemBuilder: (context, index) {
          final lot = _lots[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text('${lot.lotNumber} • ${lot.sku}'),
              subtitle: Text(
                'Fabric: ${lot.fabricType} • Bundles: ${lot.totalBundles ?? '-'} • Pieces: ${lot.totalPieces ?? '-'}',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _openLot(lot),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/lot_models.dart';
import '../../services/api_client.dart';
import '../../services/api_service.dart';
import '../../state/auth_controller.dart';
import '../../utils/ui_helpers.dart';
import '../common/lot_detail_screen.dart';

class LotsOverviewScreen extends StatefulWidget {
  final bool readOnly;

  const LotsOverviewScreen({super.key, this.readOnly = false});

  @override
  State<LotsOverviewScreen> createState() => _LotsOverviewScreenState();
}

class _LotsOverviewScreenState extends State<LotsOverviewScreen> {
  bool _loading = true;
  String? _error;
  List<LotSummary> _lots = const [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    try {
      final lots = await api.fetchLots();
      if (!mounted) return;
      setState(() {
        _lots = lots;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
      }
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search by SKU or lot number',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _buildList(),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(_error!, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }
    final filtered = _lots.where((lot) {
      if (_search.isEmpty) return true;
      return lot.sku.toLowerCase().contains(_search) ||
          lot.lotNumber.toLowerCase().contains(_search);
    }).toList();

    if (filtered.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No lots found.')),
        ],
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final lot = filtered[index];
        return ListTile(
          title: Text(lot.lotNumber),
          subtitle: Text('${lot.sku} • ${lot.fabricType}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (lot.totalPieces != null) Text('${lot.totalPieces} pcs'),
              if (lot.totalBundles != null) Text('${lot.totalBundles} bundles'),
            ],
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LotDetailScreen(lotId: lot.id, summary: lot),
              ),
            );
          },
        );
      },
    );
  }
}

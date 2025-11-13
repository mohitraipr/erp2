import 'package:flutter/material.dart';

import '../models/production_flow.dart';
import '../providers/providers.dart';
import '../services/api_client.dart';
import '../state/simple_riverpod.dart';

class BundleLookupScreen extends ConsumerStatefulWidget {
  const BundleLookupScreen({super.key});

  @override
  ConsumerState<BundleLookupScreen> createState() => _BundleLookupScreenState();
}

class _BundleLookupScreenState extends ConsumerState<BundleLookupScreen> {
  final _codeController = TextEditingController();
  ProductionBundleInfo? _bundle;
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget buildWithRef(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bundle lookup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Bundle code',
                hintText: 'Enter bundle code',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _lookup,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Lookup'),
              ),
            ),
            const SizedBox(height: 24),
            if (_bundle != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bundle ${_bundle!.bundleCode}',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Lot: ${_bundle!.lotNumber}'),
                      Text('SKU: ${_bundle!.sku}'),
                      Text('Fabric: ${_bundle!.fabricType}'),
                      if (_bundle!.sizeLabel != null)
                        Text('Size: ${_bundle!.sizeLabel}'),
                      if (_bundle!.piecesInBundle != null)
                        Text('Pieces: ${_bundle!.piecesInBundle}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _lookup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter bundle code.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _bundle = null;
    });

    try {
      final bundle = await performApiCall(
        ref,
        (repo) => repo.getBundleByCode(code),
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}

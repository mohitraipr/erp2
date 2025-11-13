import 'package:flutter/material.dart';

import '../models/master.dart';
import '../models/production_flow.dart';
import '../providers/data_providers.dart';
import '../providers/providers.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../state/simple_riverpod.dart';

class JeansAssemblyScreen extends ConsumerStatefulWidget {
  const JeansAssemblyScreen({super.key});

  @override
  ConsumerState<JeansAssemblyScreen> createState() =>
      _JeansAssemblyScreenState();
}

class _JeansAssemblyScreenState extends ConsumerState<JeansAssemblyScreen> {
  final _bundleController = TextEditingController();
  final _rejectedController = TextEditingController();
  MasterRecord? _selectedMaster;
  ProductionBundleInfo? _bundleInfo;
  bool _loadingLookup = false;

  @override
  void dispose() {
    _bundleController.dispose();
    _rejectedController.dispose();
    super.dispose();
  }

  @override
  Widget buildWithRef(BuildContext context, WidgetRef ref) {
    final mastersAsync = ref.watch(mastersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jeans assembly'),
        actions: [
          IconButton(
            onPressed: () => ref.refresh(mastersProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _bundleController,
              decoration: const InputDecoration(
                labelText: 'Bundle code',
                hintText: 'Scan or enter bundle code (e.g. AK3b1)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loadingLookup ? null : _lookupBundle,
                  icon: _loadingLookup
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code),
                  label: const Text('Lookup bundle'),
                ),
                const SizedBox(width: 12),
                if (_bundleInfo != null)
                  Chip(
                    label: Text(
                      '${_bundleInfo!.lotNumber} • ${_bundleInfo!.sizeLabel ?? ''}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            mastersAsync.when(
              data: (masters) {
                return DropdownButtonFormField<MasterRecord>(
                  initialValue: _selectedMaster,
                  items: masters
                      .map((master) => DropdownMenuItem(
                            value: master,
                            child: Text(master.masterName),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedMaster = value),
                  decoration: const InputDecoration(
                    labelText: 'Assign to master (optional)',
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text(error.toString()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectedController,
              decoration: const InputDecoration(
                labelText: 'Rejected piece codes',
                hintText: 'Comma or newline separated piece codes',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send),
                label: const Text('Record assembly event'),
              ),
            ),
            const SizedBox(height: 24),
            if (_bundleInfo != null)
              _BundleInfoCard(bundle: _bundleInfo!),
          ],
        ),
      ),
    );
  }

  Future<void> _lookupBundle() async {
    final code = _bundleController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a bundle code.')),
      );
      return;
    }

    setState(() {
      _loadingLookup = true;
    });

    try {
      final bundle = await performApiCall(
        ref,
        (repo) => repo.getBundleByCode(code),
      );
      if (!mounted) return;
      setState(() {
        _bundleInfo = bundle;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingLookup = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final code = _bundleController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a bundle code.')),
      );
      return;
    }

    final rejectedPieces = _rejectedController.text
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    try {
      final response = await performApiCall(
        ref,
        (repo) => repo.submitProductionEntry(
          ProductionAssignmentPayload(
            code: code,
            assignments: const [],
            masterId: _selectedMaster?.id,
            rejectedPieces: rejectedPieces.isEmpty ? null : rejectedPieces,
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bundle ${response.data['bundleCode'] ?? code} recorded at ${response.stage}.',
          ),
        ),
      );
      setState(() {
        _bundleInfo = null;
        _rejectedController.clear();
        _bundleController.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

class _BundleInfoCard extends StatelessWidget {
  const _BundleInfoCard({required this.bundle});

  final ProductionBundleInfo bundle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bundle ${bundle.bundleCode}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Lot: ${bundle.lotNumber} (${bundle.sku})'),
            if (bundle.piecesInBundle != null)
              Text('Pieces: ${bundle.piecesInBundle}'),
            if (bundle.sizeLabel != null)
              Text('Size: ${bundle.sizeLabel}'),
          ],
        ),
      ),
    );
  }
}

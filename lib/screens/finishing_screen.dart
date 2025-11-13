import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/master.dart';
import '../providers/data_providers.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';

class FinishingScreen extends ConsumerStatefulWidget {
  const FinishingScreen({super.key});

  @override
  ConsumerState<FinishingScreen> createState() => _FinishingScreenState();
}

class _FinishingScreenState extends ConsumerState<FinishingScreen> {
  final _bundleController = TextEditingController();
  final _rejectedController = TextEditingController();
  final _remarkController = TextEditingController();
  MasterRecord? _selectedMaster;

  @override
  void dispose() {
    _bundleController.dispose();
    _rejectedController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mastersAsync = ref.watch(mastersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finishing'),
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
                hintText: 'Enter bundle code (e.g. AK3b1)',
              ),
            ),
            const SizedBox(height: 16),
            mastersAsync.when(
              data: (masters) {
                return DropdownButtonFormField<MasterRecord>(
                  value: _selectedMaster,
                  onChanged: (value) => setState(() => _selectedMaster = value),
                  items: masters
                      .map((master) => DropdownMenuItem(
                            value: master,
                            child: Text(master.masterName),
                          ))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Master (optional)',
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
                hintText: 'Comma or newline separated codes',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _remarkController,
              decoration: const InputDecoration(labelText: 'Remark'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete finishing'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final bundleCode = _bundleController.text.trim();
    if (bundleCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter bundle code.')),
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
            code: bundleCode,
            assignments: const [],
            masterId: _selectedMaster?.id,
            rejectedPieces: rejectedPieces.isEmpty ? null : rejectedPieces,
            remark: _remarkController.text.trim().isEmpty
                ? null
                : _remarkController.text.trim(),
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bundle ${response.data['bundleCode'] ?? bundleCode} finished. ${response.data['washingInClosed'] ?? ''}',
          ),
        ),
      );
      _bundleController.clear();
      _rejectedController.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

import 'package:flutter/material.dart';

import '../providers/providers.dart';
import '../services/api_service.dart';
import '../state/simple_riverpod.dart';

class WashingScreen extends ConsumerStatefulWidget {
  const WashingScreen({super.key});

  @override
  ConsumerState<WashingScreen> createState() => _WashingScreenState();
}

class _WashingScreenState extends ConsumerState<WashingScreen> {
  final _lotController = TextEditingController();
  final _remarkController = TextEditingController();

  @override
  void dispose() {
    _lotController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget buildWithRef(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Washing registration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _lotController,
              decoration: const InputDecoration(
                labelText: 'Lot number',
                hintText: 'Enter lot number (e.g. AK3)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _remarkController,
              decoration: const InputDecoration(
                labelText: 'Remark',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send),
                label: const Text('Send to washing'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final lotNumber = _lotController.text.trim();
    if (lotNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter lot number.')),
      );
      return;
    }

    try {
      final response = await performApiCall(
        ref,
        (repo) => repo.submitProductionEntry(
          ProductionAssignmentPayload(
            code: lotNumber,
            assignments: const [],
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
            'Registered ${response.data['piecesRegistered'] ?? '-'} pieces for ${response.data['lotNumber'] ?? lotNumber}.',
          ),
        ),
      );
      _lotController.clear();
      _remarkController.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

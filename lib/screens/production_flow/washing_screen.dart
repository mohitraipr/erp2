import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/production_flow.dart';
import '../../services/api_client.dart';

class WashingScreen extends StatefulWidget {
  const WashingScreen({super.key});

  @override
  State<WashingScreen> createState() => _WashingScreenState();
}

class _WashingScreenState extends State<WashingScreen> {
  final TextEditingController _lotCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  ProductionSubmissionResult? _result;
  bool _loading = false;

  @override
  void dispose() {
    _lotCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _lotCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter lot number.')));
      return;
    }
    setState(() => _loading = true);
    final api = context.read<ApiClient>();
    try {
      final result = await api.submitWashing(
        lotNumber: code,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _result = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Lot registered for washing.')),
      );
      _remarkCtrl.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send lot to washing',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _lotCtrl,
                    decoration: const InputDecoration(labelText: 'Lot number'),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _remarkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Remark (optional)',
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_loading ? 'Submitting…' : 'Submit'),
                  ),
                ],
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            _WashingResultCard(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _WashingResultCard extends StatelessWidget {
  const _WashingResultCard({required this.result});

  final ProductionSubmissionResult result;

  @override
  Widget build(BuildContext context) {
    final lot = result.data['lotNumber'] ?? result.data['lot_number'] ?? '-';
    final pieces = result.data['piecesRegistered'] ?? result.data['pieces_registered'];
    final closed = result.data['closedJeansAssembly'] ?? result.data['closed_jeans_assembly'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lot $lot',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Pieces registered: ${pieces ?? '-'}'),
            Text('Closed jeans assembly: ${closed ?? '-'} events'),
          ],
        ),
      ),
    );
  }
}

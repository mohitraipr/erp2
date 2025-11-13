import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/production_flow.dart';
import '../../services/api_client.dart';

class WashingInScreen extends StatefulWidget {
  const WashingInScreen({super.key});

  @override
  State<WashingInScreen> createState() => _WashingInScreenState();
}

class _WashingInScreenState extends State<WashingInScreen> {
  final TextEditingController _pieceCtrl = TextEditingController();
  final TextEditingController _rejectedCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  ProductionSubmissionResult? _result;
  bool _rejectMode = false;
  bool _loading = false;

  @override
  void dispose() {
    _pieceCtrl.dispose();
    _rejectedCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_rejectMode && _pieceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter piece code.')));
      return;
    }
    if (_rejectMode && _rejectedCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provide rejected piece codes.')),
      );
      return;
    }
    setState(() => _loading = true);
    final api = context.read<ApiClient>();
    try {
      final result = await api.submitWashingIn(
        pieceCode: _rejectMode ? null : _pieceCtrl.text.trim(),
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        rejectedPieces: _rejectMode ? _parseCodes(_rejectedCtrl.text) : const [],
      );
      if (!mounted) return;
      setState(() => _result = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Washing-in recorded.')),
      );
      _pieceCtrl.clear();
      _rejectedCtrl.clear();
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
                    'Washing-in registration',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Scan piece')),
                      ButtonSegment(value: true, label: Text('Mark rejections')),
                    ],
                    selected: {_rejectMode},
                    onSelectionChanged: (values) {
                      setState(() {
                        _rejectMode = values.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!_rejectMode)
                    TextField(
                      controller: _pieceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Piece code',
                        prefixIcon: Icon(Icons.qr_code_scanner),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  if (_rejectMode)
                    TextField(
                      controller: _rejectedCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Rejected piece codes (comma separated)',
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _remarkCtrl,
                    decoration: const InputDecoration(labelText: 'Remark (optional)'),
                    minLines: 1,
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
            _WashingInResultCard(result: _result!),
          ],
        ],
      ),
    );
  }

  List<String> _parseCodes(String raw) {
    return raw
        .split(RegExp(r'[\s,;]+'))
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toList();
  }
}

class _WashingInResultCard extends StatelessWidget {
  const _WashingInResultCard({required this.result});

  final ProductionSubmissionResult result;

  @override
  Widget build(BuildContext context) {
    final lot = result.data['lotNumber'] ?? result.data['lot_number'] ?? '-';
    final piece = result.data['pieceCode'] ?? result.data['piece_code'] ?? '-';
    final rejected = result.data['rejectionInserted'] ?? result.data['rejection_inserted'];
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
            Text('Piece recorded: $piece'),
            Text('New rejections: ${rejected ?? 0}'),
          ],
        ),
      ),
    );
  }
}

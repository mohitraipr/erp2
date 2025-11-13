import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/master.dart';
import '../../models/production_flow.dart';
import '../../services/api_client.dart';

class FinishingScreen extends StatefulWidget {
  const FinishingScreen({super.key});

  @override
  State<FinishingScreen> createState() => _FinishingScreenState();
}

class _FinishingScreenState extends State<FinishingScreen> {
  final TextEditingController _bundleCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  final TextEditingController _rejectedCtrl = TextEditingController();

  List<Master> _masters = [];
  Master? _selectedMaster;
  ProductionSubmissionResult? _result;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMasters());
  }

  @override
  void dispose() {
    _bundleCtrl.dispose();
    _remarkCtrl.dispose();
    _rejectedCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    final api = context.read<ApiClient>();
    try {
      final masters = await api.fetchMasters();
      if (!mounted) return;
      setState(() => _masters = masters);
    } on ApiException {
      // optional failure allowed
    }
  }

  Future<void> _submit() async {
    final code = _bundleCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter bundle code.')));
      return;
    }
    setState(() => _loading = true);
    final api = context.read<ApiClient>();
    try {
      final result = await api.submitFinishing(
        bundleCode: code,
        masterId: _selectedMaster?.id,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        rejectedPieces: _parseCodes(_rejectedCtrl.text),
      );
      if (!mounted) return;
      setState(() => _result = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Bundle finalized.')),
      );
      _remarkCtrl.clear();
      _rejectedCtrl.clear();
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
                    'Finishing scan',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bundleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bundle code',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Master>(
                    value: _selectedMaster,
                    decoration: const InputDecoration(labelText: 'Finishing master'),
                    items: _masters
                        .map(
                          (master) => DropdownMenuItem(
                            value: master,
                            child: Text(master.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedMaster = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _remarkCtrl,
                    decoration: const InputDecoration(labelText: 'Remark (optional)'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rejectedCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rejected piece codes (comma separated)',
                    ),
                    minLines: 2,
                    maxLines: 4,
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
            _FinishingResultCard(result: _result!),
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

class _FinishingResultCard extends StatelessWidget {
  const _FinishingResultCard({required this.result});

  final ProductionSubmissionResult result;

  @override
  Widget build(BuildContext context) {
    final bundle = result.data['bundleCode'] ?? result.data['bundle_code'] ?? '-';
    final pieces = result.data['pieces'] ?? result.data['pieceCount'] ?? '-';
    final closed = result.data['washingInClosed'] ?? result.data['washing_in_closed'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bundle $bundle',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Pieces: $pieces'),
            Text('Washing-in closed: ${closed ?? '-'}'),
          ],
        ),
      ),
    );
  }
}

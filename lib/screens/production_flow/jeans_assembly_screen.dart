import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/master.dart';
import '../../models/production_flow.dart';
import '../../services/api_client.dart';

class JeansAssemblyScreen extends StatefulWidget {
  const JeansAssemblyScreen({super.key});

  @override
  State<JeansAssemblyScreen> createState() => _JeansAssemblyScreenState();
}

class _JeansAssemblyScreenState extends State<JeansAssemblyScreen> {
  final TextEditingController _bundleCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  final TextEditingController _rejectedCtrl = TextEditingController();

  List<Master> _masters = [];
  Master? _selectedMaster;
  ProductionFlowBundleInfo? _bundleInfo;
  bool _loading = false;
  bool _loadingBundle = false;

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
      // ignore optional failure
    }
  }

  Future<void> _lookupBundle() async {
    final code = _bundleCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter bundle code.')));
      return;
    }
    setState(() => _loadingBundle = true);
    final api = context.read<ApiClient>();
    try {
      final info = await api.fetchBundleInfo(code);
      if (!mounted) return;
      setState(() => _bundleInfo = info);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loadingBundle = false);
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
      final result = await api.submitJeansAssembly(
        bundleCode: code,
        masterId: _selectedMaster?.id,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        rejectedPieces: _parseCodes(_rejectedCtrl.text),
      );
      if (!mounted) return;
      setState(() {
        _bundleInfo = result.data.containsKey('bundleCode')
            ? ProductionFlowBundleInfo.fromJson(result.data)
            : _bundleInfo;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Bundle recorded.')),
      );
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
                    'Jeans assembly scan',
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
                    onSubmitted: (_) => _lookupBundle(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Master>(
                    value: _selectedMaster,
                    decoration: const InputDecoration(labelText: 'Assigned master'),
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
                    decoration: const InputDecoration(
                      labelText: 'Remark (optional)',
                    ),
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
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loadingBundle ? null : _lookupBundle,
                        icon: _loadingBundle
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.info_outline),
                        label: const Text('Preview bundle'),
                      ),
                      const SizedBox(width: 12),
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
                ],
              ),
            ),
          ),
          if (_bundleInfo != null) ...[
            const SizedBox(height: 16),
            _BundleInfoCard(info: _bundleInfo!),
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

class _BundleInfoCard extends StatelessWidget {
  const _BundleInfoCard({required this.info});

  final ProductionFlowBundleInfo info;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bundle ${info.bundleCode}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Lot: ${info.lotNumber ?? '-'}'),
            Text('SKU: ${info.sku ?? '-'}'),
            Text('Fabric: ${info.fabricType ?? '-'}'),
            Text('Pieces: ${info.pieceCount ?? info.piecesInBundle ?? '-'}'),
          ],
        ),
      ),
    );
  }
}

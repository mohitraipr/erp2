import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/api_lot.dart';
import '../../models/master.dart';
import '../../models/production_flow.dart';
import '../../services/api_client.dart';

class PatternAssignmentScreen extends StatefulWidget {
  const PatternAssignmentScreen({super.key});

  @override
  State<PatternAssignmentScreen> createState() => _PatternAssignmentScreenState();
}

class _PatternAssignmentScreenState extends State<PatternAssignmentScreen> {
  final TextEditingController _lotCodeCtrl = TextEditingController();
  final List<_AssignmentRow> _rows = [];

  ApiLot? _lot;
  List<Master> _masters = [];
  Master? _defaultMaster;
  bool _loadingLot = false;
  bool _loadingMasters = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMasters());
  }

  @override
  void dispose() {
    _lotCodeCtrl.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() => _loadingMasters = true);
    final api = context.read<ApiClient>();
    try {
      final masters = await api.fetchMasters();
      if (!mounted) return;
      setState(() => _masters = masters);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loadingMasters = false);
    }
  }

  Future<void> _loadLot() async {
    final code = _lotCodeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter lot number.')));
      return;
    }
    setState(() => _loadingLot = true);
    final api = context.read<ApiClient>();
    try {
      final lots = await api.fetchLots();
      final summary = lots.firstWhere(
        (lot) => lot.lotNumber.toLowerCase() == code.toLowerCase(),
        orElse: () => throw ApiException('Lot $code not found.'),
      );
      final detail = await api.fetchLotDetail(summary.id);
      if (!mounted) return;
      setState(() {
        _lot = detail;
        for (final row in _rows) {
          row.dispose();
        }
        _rows
          ..clear()
          ..addAll(_buildRowsFromLot(detail));
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loadingLot = false);
    }
  }

  List<_AssignmentRow> _buildRowsFromLot(ApiLot lot) {
    final rows = <_AssignmentRow>[];
    if (lot.patterns.isNotEmpty) {
      for (final group in lot.patterns) {
        final patterns = group.patterns
            .map((p) => p.patternNo)
            .whereType<int>()
            .toList()
          ..sort();
        if (patterns.isEmpty) continue;
        final row = _AssignmentRow(sizeLabel: group.sizeLabel, patterns: patterns);
        row.patternCtrl.text = patterns.join(', ');
        rows.add(row);
      }
      return rows;
    }
    for (final size in lot.sizes) {
      final count = size.patternCount ?? 0;
      if (count <= 0) continue;
      final patterns = List<int>.generate(count, (index) => index + 1);
      final row = _AssignmentRow(sizeLabel: size.sizeLabel, patterns: patterns);
      row.patternCtrl.text = patterns.join(', ');
      rows.add(row);
    }
    return rows;
  }

  void _addRowForSize(String sizeLabel, List<int> patterns) {
    setState(() {
      final row = _AssignmentRow(sizeLabel: sizeLabel, patterns: patterns);
      row.patternCtrl.text = patterns.join(', ');
      _rows.add(row);
    });
  }

  void _removeRow(_AssignmentRow row) {
    setState(() {
      _rows.remove(row);
      row.dispose();
    });
  }

  List<String> _availableSizeLabels() {
    if (_lot == null) return const [];
    final labels = <String>{};
    for (final size in _lot!.sizes) {
      labels.add(size.sizeLabel);
    }
    for (final group in _lot!.patterns) {
      labels.add(group.sizeLabel);
    }
    final sorted = labels.toList();
    sorted.sort();
    return sorted;
  }

  List<int> _patternsForSize(String sizeLabel) {
    final group = _lot?.patterns.firstWhere(
      (element) => element.sizeLabel == sizeLabel,
      orElse: () => const ApiLotPatternGroup(sizeLabel: '', patterns: []),
    );
    if (group != null && group.patterns.isNotEmpty) {
      final patterns = group.patterns
          .map((pattern) => pattern.patternNo)
          .whereType<int>()
          .toList();
      if (patterns.isNotEmpty) {
        patterns.sort();
        return patterns;
      }
    }
    final size = _lot?.sizes.firstWhere(
      (element) => element.sizeLabel == sizeLabel,
      orElse: () => ApiLotSize(sizeLabel: sizeLabel),
    );
    final count = size?.patternCount ?? 0;
    return count > 0
        ? List<int>.generate(count, (index) => index + 1)
        : const <int>[];
  }

  Future<void> _submit() async {
    if (_lot == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Load a lot first.')));
      return;
    }
    if (_submitting) return;
    final assignments = <ProductionAssignment>[];
    for (final row in _rows) {
      final patternNos = row.parsePatternNumbers();
      if (patternNos.isEmpty) continue;
      final master = row.master ?? _defaultMaster;
      assignments.add(
        ProductionAssignment(
          sizeLabel: row.sizeLabel,
          patternNumbers: patternNos,
          masterId: master?.id,
          masterName: master?.name,
        ),
      );
    }
    if (assignments.isEmpty && _defaultMaster == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a master or specify pattern assignments.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final api = context.read<ApiClient>();
    try {
      final result = await api.submitPatternAssignments(
        lotNumber: _lot!.lotNumber,
        assignments: assignments,
        masterId: assignments.isEmpty ? _defaultMaster?.id : null,
        masterName: assignments.isEmpty ? _defaultMaster?.name : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Assignments submitted successfully.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(context),
          const SizedBox(height: 16),
          if (_lot != null) _buildAssignmentsCard(context),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assign patterns to masters',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lotCodeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Lot number (e.g. AK3)'),
                    onSubmitted: (_) => _loadLot(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadingLot ? null : _loadLot,
                  icon: _loadingLot
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_loadingLot ? 'Loading…' : 'Load lot'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Master>(
              value: _defaultMaster,
              decoration: const InputDecoration(labelText: 'Default master'),
              items: _masters
                  .map(
                    (master) => DropdownMenuItem(
                      value: master,
                      child: Text(master.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _defaultMaster = value),
            ),
            if (_loadingMasters)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_lot != null) ...[
              const SizedBox(height: 16),
              Text('Lot loaded: ${_lot!.lotNumber} • SKU ${_lot!.sku}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assignments',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_lot != null)
                  PopupMenuButton<String>(
                    tooltip: 'Add assignment row',
                    icon: const Icon(Icons.add_circle_outline),
                    onSelected: (label) {
                      final patterns = _patternsForSize(label);
                      _addRowForSize(label, patterns);
                    },
                    itemBuilder: (context) => _availableSizeLabels()
                        .map(
                          (label) => PopupMenuItem(
                            value: label,
                            child: Text('Add row for $label'),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_rows.isEmpty)
              const Text(
                'No rows yet. Use the load button to pull lot details.',
              ),
            for (final row in _rows)
              _AssignmentRowTile(
                row: row,
                masters: _masters,
                onRemove: () => _removeRow(row),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Submitting…' : 'Submit assignments'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentRow {
  _AssignmentRow({required this.sizeLabel, required this.patterns});

  final String sizeLabel;
  final List<int> patterns;
  Master? master;
  final TextEditingController patternCtrl = TextEditingController();

  List<int> parsePatternNumbers() {
    final raw = patternCtrl.text;
    final values = raw
        .split(RegExp(r'[;,\s]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    return values;
  }

  void dispose() {
    patternCtrl.dispose();
  }
}

class _AssignmentRowTile extends StatelessWidget {
  const _AssignmentRowTile({
    required this.row,
    required this.masters,
    required this.onRemove,
  });

  final _AssignmentRow row;
  final List<Master> masters;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Master>(
                    value: row.master,
                    decoration:
                        InputDecoration(labelText: 'Master for size ${row.sizeLabel}'),
                    items: masters
                        .map((master) => DropdownMenuItem(
                              value: master,
                              child: Text(master.name),
                            ))
                        .toList(),
                    onChanged: (value) => row.master = value,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove row',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.patternCtrl,
              decoration: const InputDecoration(
                labelText: 'Pattern numbers (comma separated)',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: row.patterns.map((p) => Chip(label: Text('P$p'))).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

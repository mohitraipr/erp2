import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/master.dart';
import '../../models/lot_models.dart';
import '../../services/api_client.dart';
import '../../services/api_service.dart';
import '../../state/auth_controller.dart';
import '../../utils/ui_helpers.dart';

class PatternAssignmentScreen extends StatefulWidget {
  const PatternAssignmentScreen({super.key});

  @override
  State<PatternAssignmentScreen> createState() => _PatternAssignmentScreenState();
}

class _PatternAssignmentScreenState extends State<PatternAssignmentScreen> {
  final _lotCtrl = TextEditingController();
  final List<_AssignmentRow> _rows = [];
  List<MasterInfo> _masters = const [];
  LotDetail? _lotDetail;
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rows.add(_AssignmentRow());
    _loadMasters();
  }

  @override
  void dispose() {
    _lotCtrl.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    try {
      final masters = await api.fetchMasters();
      if (!mounted) return;
      setState(() {
        _masters = masters;
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _previewLot() async {
    final lotNumber = _lotCtrl.text.trim();
    if (lotNumber.isEmpty) {
      showErrorSnackBar(context, ApiException('Enter a lot number first.'));
      return;
    }
    final api = context.read<ApiService>();
    try {
      final detail = await api.fetchLotByNumber(lotNumber);
      if (!mounted) return;
      setState(() {
        _lotDetail = detail;
      });
    } catch (error) {
      showErrorSnackBar(context, error);
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    }
  }

  Future<void> _submit() async {
    final lotNumber = _lotCtrl.text.trim();
    if (lotNumber.isEmpty) {
      showErrorSnackBar(context, ApiException('Lot number is required.'));
      return;
    }

    final assignments = _rows
        .where((row) => row.sizeCtrl.text.trim().isNotEmpty)
        .map((row) => {
              'sizeLabel': row.sizeCtrl.text.trim(),
              'patternNos': row.patterns,
              if (row.masterId != null) 'masterId': row.masterId,
              if (row.masterId == null && row.masterName?.isNotEmpty == true)
                'masterName': row.masterName,
            })
        .toList();

    if (assignments.isEmpty) {
      showErrorSnackBar(context, ApiException('Add at least one assignment.'));
      return;
    }

    if (assignments.any((assignment) {
      final patterns = assignment['patternNos'] as List<int>;
      return patterns.isEmpty;
    })) {
      showErrorSnackBar(context, ApiException('Pattern numbers cannot be empty.'));
      return;
    }

    setState(() => _submitting = true);
    final api = context.read<ApiService>();
    try {
      final response = await api.submitProductionEntry({
        'code': lotNumber,
        'assignments': assignments,
      });
      if (!mounted) return;
      await showSuccessDialog(
        context,
        title: 'Assignments submitted',
        content: Text(response['message']?.toString() ?? 'Patterns assigned successfully.'),
      );
    } catch (error) {
      showErrorSnackBar(context, error);
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _addRow() {
    setState(() {
      _rows.add(_AssignmentRow());
    });
  }

  void _removeRow(int index) {
    if (_rows.length == 1) return;
    setState(() {
      final row = _rows.removeAt(index);
      row.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pattern Assignments', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            controller: _lotCtrl,
            decoration: InputDecoration(
              labelText: 'Lot Number',
              suffixIcon: IconButton(
                tooltip: 'Load lot details',
                icon: const Icon(Icons.visibility),
                onPressed: _previewLot,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_lotDetail != null) _LotPatternsPreview(detail: _lotDetail!),
          const SizedBox(height: 16),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Row(
                      children: [
                        Expanded(child: Text(_error!)),
                        TextButton(onPressed: _loadMasters, child: const Text('Retry')),
                      ],
                    )
                  : _buildAssignments(),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'Submitting...' : 'Submit Assignments'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignments() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Assignments', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AssignmentRowWidget(
                  index: i,
                  row: _rows[i],
                  masters: _masters,
                  onRemove: _rows.length == 1 ? null : () => _removeRow(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentRow {
  final TextEditingController sizeCtrl = TextEditingController();
  final TextEditingController patternCtrl = TextEditingController();
  int? masterId;
  String? masterName;

  List<int> get patterns => patternCtrl.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) => int.tryParse(e) ?? 0)
      .where((value) => value > 0)
      .toList();

  void dispose() {
    sizeCtrl.dispose();
    patternCtrl.dispose();
  }
}

class _AssignmentRowWidget extends StatelessWidget {
  final int index;
  final _AssignmentRow row;
  final List<MasterInfo> masters;
  final VoidCallback? onRemove;

  const _AssignmentRowWidget({
    required this.index,
    required this.row,
    required this.masters,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: row.sizeCtrl,
            decoration: InputDecoration(labelText: 'Size ${index + 1}'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: row.patternCtrl,
            decoration: const InputDecoration(
              labelText: 'Pattern numbers',
              helperText: 'Comma separated (e.g. 1,2,3)',
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int?>(
            value: row.masterId,
            decoration: const InputDecoration(labelText: 'Master'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Select master')),
              ...masters.map(
                (master) => DropdownMenuItem<int?>(
                  value: master.id,
                  child: Text(master.masterName),
                ),
              ),
            ],
            onChanged: (value) {
              row.masterId = value;
              if (value != null) {
                row.masterName =
                    masters.firstWhere((master) => master.id == value).masterName;
              } else {
                row.masterName = null;
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    );
  }
}

class _LotPatternsPreview extends StatelessWidget {
  final LotDetail detail;

  const _LotPatternsPreview({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lot ${detail.lotNumber} overview',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...detail.sizes.map(
              (size) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${size.sizeLabel} – ${size.patternCount} patterns'),
                subtitle: size.totalPieces != null
                    ? Text('Pieces: ${size.totalPieces}')
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/fabric_roll.dart';
import '../../models/filter_options.dart';
import '../../models/lot_models.dart';
import '../../services/api_client.dart';
import '../../services/api_service.dart';
import '../../state/auth_controller.dart';
import '../../utils/ui_helpers.dart';

class CreateLotScreen extends StatefulWidget {
  const CreateLotScreen({super.key});

  @override
  State<CreateLotScreen> createState() => _CreateLotScreenState();
}

class _CreateLotScreenState extends State<CreateLotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skuCtrl = TextEditingController();
  final _bundleSizeCtrl = TextEditingController(text: '10');
  final _remarkCtrl = TextEditingController();

  late final ApiService _api;

  Map<String, List<FabricRoll>> _fabricRolls = const {};
  FilterOptions? _filters;
  bool _loading = true;
  String? _error;

  String? _selectedFabricType;
  final List<_SizeRow> _sizeRows = [];
  final Map<String, _RollRow> _rollRows = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _loadReferenceData();
    _addSizeRow();
  }

  @override
  void dispose() {
    for (final row in _sizeRows) {
      row.dispose();
    }
    for (final row in _rollRows.values) {
      row.dispose();
    }
    _skuCtrl.dispose();
    _bundleSizeCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReferenceData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.fetchFabricRolls(),
        _api.fetchFilters(),
      ]);
      final rolls = results[0] as Map<String, List<FabricRoll>>;
      final filters = results[1] as FilterOptions;
      setState(() {
        _fabricRolls = rolls;
        _filters = filters;
        _selectedFabricType = rolls.keys.isNotEmpty ? rolls.keys.first : null;
        _resetRollRows();
      });
    } catch (error) {
      setState(() {
        _error = errorMessage(error);
      });
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _resetRollRows() {
    for (final row in _rollRows.values) {
      row.dispose();
    }
    _rollRows.clear();
    final rolls = _selectedFabricType == null
        ? const <FabricRoll>[]
        : _fabricRolls[_selectedFabricType] ?? const <FabricRoll>[];
    for (final roll in rolls) {
      _rollRows[roll.rollNo] = _RollRow(roll);
    }
  }

  void _addSizeRow() {
    setState(() {
      _sizeRows.add(_SizeRow());
    });
  }

  void _removeSizeRow(int index) {
    if (_sizeRows.length == 1) return;
    setState(() {
      final row = _sizeRows.removeAt(index);
      row.dispose();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final bundleSize = int.tryParse(_bundleSizeCtrl.text.trim()) ?? 0;
    if (bundleSize <= 0) {
      showErrorSnackBar(context, ApiException('Bundle size must be positive'));
      return;
    }

    final sizes = _sizeRows
        .map(
          (row) => LotSizeInfo(
            sizeLabel: row.sizeLabel,
            patternCount: row.patternCount,
          ),
        )
        .toList();

    final rolls = _rollRows.values
        .where((row) => row.selected)
        .map(
          (row) => LotRollUsage(
            rollNo: row.roll.rollNo,
            weightUsed: row.weightUsed,
            layers: row.layers,
          ),
        )
        .toList();

    final request = LotCreationRequest(
      sku: _skuCtrl.text.trim(),
      fabricType: _selectedFabricType ?? '',
      remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
      bundleSize: bundleSize,
      sizes: sizes,
      rolls: rolls,
    );

    final errors = request.validate();
    if (errors.isNotEmpty) {
      showErrorSnackBar(context, ApiException(errors.first));
      return;
    }

    setState(() => _submitting = true);
    try {
      final lot = await _api.createLot(request);
      if (!mounted) return;
      await showSuccessDialog(
        context,
        title: 'Lot Created',
        content: _LotSummaryView(lot: lot),
      );
      _formKey.currentState!.reset();
      _skuCtrl.clear();
      _remarkCtrl.clear();
      for (final row in _sizeRows) {
        row.clear();
      }
      for (final row in _rollRows.values) {
        row.clear();
      }
    } catch (error) {
      showErrorSnackBar(context, error);
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadReferenceData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filters = _filters;
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Lot', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 320,
                  child: TextFormField(
                    controller: _skuCtrl,
                    decoration: const InputDecoration(labelText: 'SKU'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'SKU is required' : null,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    controller: _bundleSizeCtrl,
                    decoration: const InputDecoration(labelText: 'Bundle Size'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Enter valid bundle size';
                      }
                      return null;
                    },
                  ),
                ),
                if (filters != null && filters.genders.isNotEmpty)
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      items: filters.genders
                          .map((gender) => DropdownMenuItem(
                                value: gender,
                                child: Text(gender.toUpperCase()),
                              ))
                          .toList(),
                      decoration: const InputDecoration(labelText: 'Gender (optional)'),
                      onChanged: (_) {},
                    ),
                  ),
                if (filters != null && filters.categories.isNotEmpty)
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      items: filters.categories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.toUpperCase()),
                              ))
                          .toList(),
                      decoration: const InputDecoration(labelText: 'Category (optional)'),
                      onChanged: (_) {},
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _remarkCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Remark (optional)'),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedFabricType,
              decoration: const InputDecoration(labelText: 'Fabric Type'),
              items: _fabricRolls.keys
                  .map(
                    (fabric) => DropdownMenuItem(
                      value: fabric,
                      child: Text(fabric),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedFabricType = value;
                  _resetRollRows();
                });
              },
              validator: (value) => value == null || value.isEmpty ? 'Select fabric type' : null,
            ),
            const SizedBox(height: 16),
            _buildRollsSection(),
            const SizedBox(height: 24),
            _buildSizesSection(),
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
                    : const Icon(Icons.save),
                label: Text(_submitting ? 'Submitting...' : 'Create Lot'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRollsSection() {
    final rows = _selectedFabricType == null
        ? const <_RollRow>[]
        : _rollRows.values.toList(growable: false);
    if (rows.isEmpty) {
      return const Text('No rolls available for the selected fabric type.');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Rolls', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...rows.map((row) => _RollRowWidget(row: row)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSizesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sizes & Patterns', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  onPressed: _addSizeRow,
                  icon: const Icon(Icons.add_circle),
                  tooltip: 'Add size',
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _sizeRows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SizeRowWidget(
                  index: i,
                  row: _sizeRows[i],
                  onRemove: _sizeRows.length == 1 ? null : () => _removeSizeRow(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RollRow {
  final FabricRoll roll;
  bool selected = false;
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController layersCtrl = TextEditingController();

  _RollRow(this.roll);

  double get weightUsed => double.tryParse(weightCtrl.text.trim()) ?? 0;
  int get layers => int.tryParse(layersCtrl.text.trim()) ?? 0;

  void clear() {
    selected = false;
    weightCtrl.clear();
    layersCtrl.clear();
  }

  void dispose() {
    weightCtrl.dispose();
    layersCtrl.dispose();
  }
}

class _RollRowWidget extends StatefulWidget {
  final _RollRow row;

  const _RollRowWidget({required this.row});

  @override
  State<_RollRowWidget> createState() => _RollRowWidgetState();
}

class _RollRowWidgetState extends State<_RollRowWidget> {
  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text('Roll ${row.roll.rollNo} (${row.roll.unit}, ${row.roll.perRollWeight} weight)'),
          subtitle: Text('Vendor: ${row.roll.vendorName}'),
          value: row.selected,
          onChanged: (value) {
            setState(() {
              row.selected = value;
            });
          },
        ),
        if (row.selected)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: row.weightCtrl,
                    decoration: const InputDecoration(labelText: 'Weight used'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (!row.selected) return null;
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Enter weight';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: row.layersCtrl,
                    decoration: const InputDecoration(labelText: 'Layers'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (!row.selected) return null;
                      final parsed = int.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Enter layers';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        const Divider(),
      ],
    );
  }
}

class _SizeRow {
  final TextEditingController sizeCtrl = TextEditingController();
  final TextEditingController patternCtrl = TextEditingController();

  String get sizeLabel => sizeCtrl.text.trim();
  int get patternCount => int.tryParse(patternCtrl.text.trim()) ?? 0;

  void clear() {
    sizeCtrl.clear();
    patternCtrl.clear();
  }

  void dispose() {
    sizeCtrl.dispose();
    patternCtrl.dispose();
  }
}

class _SizeRowWidget extends StatelessWidget {
  final int index;
  final _SizeRow row;
  final VoidCallback? onRemove;

  const _SizeRowWidget({
    required this.index,
    required this.row,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: row.sizeCtrl,
            decoration: InputDecoration(
              labelText: 'Size Label ${index + 1}',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter size label'
                : null,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: TextFormField(
            controller: row.patternCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Pattern Count'),
            validator: (value) {
              final parsed = int.tryParse(value ?? '');
              if (parsed == null || parsed <= 0) {
                return 'Enter patterns';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Remove size',
        ),
      ],
    );
  }
}

class _LotSummaryView extends StatelessWidget {
  final LotDetail lot;

  const _LotSummaryView({required this.lot});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Lot Number: ${lot.lotNumber}'),
          Text('SKU: ${lot.sku}'),
          Text('Fabric: ${lot.fabricType}'),
          if (lot.totalPieces != null) Text('Total pieces: ${lot.totalPieces}'),
          const SizedBox(height: 12),
          Text('Sizes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...lot.sizes.map(
            (size) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${size.sizeLabel} – patterns: ${size.patternCount}'
                '${size.totalPieces != null ? ', pieces: ${size.totalPieces}' : ''}',
              ),
            ),
          ),
          if (lot.downloads.bundleCodes != null || lot.downloads.pieceCodes != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text('Downloads', style: Theme.of(context).textTheme.titleMedium),
                if (lot.downloads.bundleCodes != null)
                  TextButton.icon(
                    onPressed: () => _openDownload(context, lot.downloads.bundleCodes!),
                    icon: const Icon(Icons.download),
                    label: const Text('Bundle codes CSV'),
                  ),
                if (lot.downloads.pieceCodes != null)
                  TextButton.icon(
                    onPressed: () => _openDownload(context, lot.downloads.pieceCodes!),
                    icon: const Icon(Icons.download),
                    label: const Text('Piece codes CSV'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openDownload(BuildContext context, String path) async {
    final api = context.read<ApiService>();
    final uri = path.startsWith('http') ? Uri.parse(path) : api.resolveDownloadUrl(path);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showErrorSnackBar(context, ApiException('Could not open download link.'));
    }
  }
}

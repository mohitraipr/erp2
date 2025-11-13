import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/api_lot.dart';
import '../../models/fabric_roll.dart';
import '../../models/filter_options.dart';
import '../../services/api_client.dart';
import '../../utils/download_helper.dart';
import '../lot_detail_screen.dart';

class CuttingManagerScreen extends StatefulWidget {
  const CuttingManagerScreen({super.key});

  @override
  State<CuttingManagerScreen> createState() => _CuttingManagerScreenState();
}

class _CuttingManagerScreenState extends State<CuttingManagerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<FormState> _lotFormKey = GlobalKey<FormState>();
  final TextEditingController _skuCtrl = TextEditingController();
  final TextEditingController _fabricCtrl = TextEditingController();
  final TextEditingController _bundleSizeCtrl = TextEditingController(text: '10');
  final TextEditingController _remarkCtrl = TextEditingController();

  final List<_SizeEntry> _sizes = [];
  final List<_RollEntry> _selectedRolls = [];

  Map<String, List<FabricRoll>> _fabricRolls = {};
  FilterOptions _filters = const FilterOptions(genders: [], categories: []);
  List<ApiLotSummary> _lots = [];
  bool _loadingRolls = false;
  bool _loadingLots = false;
  bool _creatingLot = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _skuCtrl.dispose();
    _fabricCtrl.dispose();
    _bundleSizeCtrl.dispose();
    _remarkCtrl.dispose();
    for (final size in _sizes) {
      size.dispose();
    }
    for (final roll in _selectedRolls) {
      roll.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final api = context.read<ApiClient>();
    setState(() {
      _loadingRolls = true;
      _loadingLots = true;
    });
    try {
      final results = await Future.wait([
        api.fetchFabricRolls(),
        api.fetchFilters(),
        api.fetchLots(),
      ]);
      if (!mounted) return;
      setState(() {
        _fabricRolls = results[0] as Map<String, List<FabricRoll>>;
        _filters = results[1] as FilterOptions;
        _lots = results[2] as List<ApiLotSummary>;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _loadingRolls = false;
          _loadingLots = false;
        });
      }
    }
  }

  Future<void> _refreshLots() async {
    final api = context.read<ApiClient>();
    setState(() => _loadingLots = true);
    try {
      final lots = await api.fetchLots();
      if (!mounted) return;
      setState(() => _lots = lots);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loadingLots = false);
    }
  }

  void _addSize() {
    setState(() => _sizes.add(_SizeEntry()));
  }

  void _addRoll(FabricRoll roll) {
    setState(() => _selectedRolls.add(_RollEntry(roll)));
  }

  void _removeSize(int index) {
    setState(() {
      _sizes.removeAt(index).dispose();
    });
  }

  void _removeRoll(int index) {
    setState(() {
      _selectedRolls.removeAt(index).dispose();
    });
  }

  int get _totalLayers =>
      _selectedRolls.fold(0, (sum, entry) => sum + (entry.layers ?? 0));

  Future<void> _createLot() async {
    if (_creatingLot) return;
    if (!_lotFormKey.currentState!.validate()) return;
    if (_selectedRolls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one fabric roll.')),
      );
      return;
    }
    if (_sizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one size.')),
      );
      return;
    }

    final bundleSize = int.tryParse(_bundleSizeCtrl.text.trim()) ?? 0;
    if (bundleSize <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bundle size must be greater than 0.')),
      );
      return;
    }

    setState(() => _creatingLot = true);
    final api = context.read<ApiClient>();
    try {
      final lot = await api.createLot(
        sku: _skuCtrl.text.trim(),
        fabricType: _fabricCtrl.text.trim(),
        bundleSize: bundleSize,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        sizes: _sizes.map((s) => s.toPayload()).toList(),
        rolls: _selectedRolls.map((r) => r.toPayload()).toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lot ${lot.lotNumber} created successfully.')),
      );
      setState(() {
        _recentLot = lot;
      });
      _resetForm();
      await _refreshLots();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _creatingLot = false);
    }
  }

  void _resetForm() {
    _skuCtrl.clear();
    _fabricCtrl.clear();
    _remarkCtrl.clear();
    _bundleSizeCtrl.text = '10';
    for (final size in _sizes) {
      size.dispose();
    }
    for (final roll in _selectedRolls) {
      roll.dispose();
    }
    _sizes.clear();
    _selectedRolls.clear();
  }

  ApiLot? _recentLot;

  Future<void> _openLotDetail(ApiLotSummary summary) async {
    final api = context.read<ApiClient>();
    try {
      final detail = await api.fetchLotDetail(summary.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LotDetailScreen(lot: detail)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _downloadCsv(ApiLot lot, LotCsvType type) async {
    final api = context.read<ApiClient>();
    try {
      final content = await api.downloadLotCsv(lotId: lot.id, type: type);
      final filename =
          '${lot.lotNumber}_${type == LotCsvType.bundles ? 'bundles' : 'pieces'}.csv';
      final saved = await saveCsvToDevice(filename, content);
      if (!mounted) return;
      if (saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$filename downloaded.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save CSV on this platform.')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: theme.textTheme.titleMedium,
            tabs: const [
              Tab(text: 'Create lot'),
              Tab(text: 'My lots'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCreateLotTab(),
              _buildLotsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateLotTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormCard(theme),
          const SizedBox(height: 24),
          if (_recentLot != null) _buildRecentLotSummary(_recentLot!),
        ],
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme) {
    final fabricTypes = _fabricRolls.keys.toList()..sort();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _lotFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lot information',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _skuCtrl,
                      decoration: const InputDecoration(labelText: 'SKU'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'SKU is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      value: _fabricCtrl.text.isEmpty
                          ? null
                          : _fabricCtrl.text,
                      items: fabricTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      decoration:
                          const InputDecoration(labelText: 'Fabric type'),
                      onChanged: (value) {
                        setState(() {
                          _fabricCtrl.text = value ?? '';
                        });
                      },
                      validator: (value) {
                        if ((value ?? _fabricCtrl.text).trim().isEmpty) {
                          return 'Select fabric type';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextFormField(
                      controller: _bundleSizeCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Bundle size'),
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter bundle size';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _remarkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Remark (optional)',
                ),
                minLines: 2,
                maxLines: 3,
              ),
              if (_filters.genders.isNotEmpty ||
                  _filters.categories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_filters.genders.isNotEmpty)
                      const Text('Genders:'),
                    ..._filters.genders
                        .map((g) => Chip(label: Text(g)))
                        .toList(),
                    if (_filters.categories.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('Categories:'),
                      ),
                    ..._filters.categories
                        .map((c) => Chip(label: Text(c)))
                        .toList(),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              _buildRollPicker(),
              const SizedBox(height: 24),
              _buildSizeList(),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _creatingLot ? null : _createLot,
                  icon: _creatingLot
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(_creatingLot ? 'Creating lot…' : 'Create lot'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRollPicker() {
    final fabricType = _fabricCtrl.text;
    final availableRolls = _fabricRolls[fabricType] ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fabric rolls',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (_loadingRolls)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (fabricType.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final selected = await showDialog<FabricRoll>(
                    context: context,
                    builder: (context) => _RollPickerDialog(
                      rolls: availableRolls,
                    ),
                  );
                  if (selected != null) {
                    _addRoll(selected);
                  }
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add roll'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedRolls.isEmpty)
          const Text('No rolls selected yet. Choose a fabric type first.'),
        if (_selectedRolls.isNotEmpty)
          Column(
            children: [
              for (var i = 0; i < _selectedRolls.length; i++)
                _RollEntryTile(
                  entry: _selectedRolls[i],
                  onRemove: () => _removeRoll(i),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildSizeList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sizes & patterns',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            TextButton.icon(
              onPressed: _addSize,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add size'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_sizes.isEmpty)
          const Text('Add the sizes required for this lot.'),
        if (_sizes.isNotEmpty)
          Column(
            children: [
              for (var i = 0; i < _sizes.length; i++)
                _SizeEntryTile(
                  entry: _sizes[i],
                  totalLayers: _totalLayers,
                  bundleSize: int.tryParse(_bundleSizeCtrl.text.trim()) ?? 0,
                  onRemove: () => _removeSize(i),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildLotsTab() {
    if (_loadingLots) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'No lots yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _refreshLots,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshLots,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _lots.length,
        itemBuilder: (context, index) {
          final lot = _lots[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text('${lot.lotNumber} • ${lot.sku}'),
              subtitle: Text(
                '${lot.fabricType} • Bundles: ${lot.totalBundles ?? '-'} • Pieces: ${lot.totalPieces ?? '-'}',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _openLotDetail(lot),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentLotSummary(ApiLot lot) {
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
                  'Latest lot: ${lot.lotNumber}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _downloadCsv(lot, LotCsvType.bundles),
                      icon: const Icon(Icons.download),
                      label: const Text('Bundles CSV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _downloadCsv(lot, LotCsvType.pieces),
                      icon: const Icon(Icons.download),
                      label: const Text('Pieces CSV'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('SKU: ${lot.sku}'),
            Text('Fabric: ${lot.fabricType}'),
            Text('Total bundles: ${lot.totalBundles ?? '-'}'),
            Text('Total pieces: ${lot.totalPieces ?? '-'}'),
          ],
        ),
      ),
    );
  }
}

class _RollEntry {
  _RollEntry(this.roll);

  final FabricRoll roll;
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController layersCtrl = TextEditingController();

  double? get weightUsed => double.tryParse(weightCtrl.text.trim());
  int? get layers => int.tryParse(layersCtrl.text.trim());

  Map<String, dynamic> toPayload() {
    return {
      'rollNo': roll.rollNo,
      'weightUsed': weightUsed ?? 0,
      'layers': layers ?? 0,
    };
  }

  void dispose() {
    weightCtrl.dispose();
    layersCtrl.dispose();
  }
}

class _SizeEntry {
  final TextEditingController sizeCtrl = TextEditingController();
  final TextEditingController patternCtrl = TextEditingController();

  Map<String, dynamic> toPayload() {
    final patternCount = int.tryParse(patternCtrl.text.trim()) ?? 0;
    return {
      'sizeLabel': sizeCtrl.text.trim(),
      'patternCount': patternCount,
    };
  }

  int? get patternCount => int.tryParse(patternCtrl.text.trim());

  void dispose() {
    sizeCtrl.dispose();
    patternCtrl.dispose();
  }
}

class _RollPickerDialog extends StatelessWidget {
  const _RollPickerDialog({required this.rolls});

  final List<FabricRoll> rolls;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select fabric roll'),
      content: SizedBox(
        width: 420,
        height: 320,
        child: ListView.builder(
          itemCount: rolls.length,
          itemBuilder: (context, index) {
            final roll = rolls[index];
            return ListTile(
              title: Text(roll.rollNo),
              subtitle: Text(
                '${roll.vendorName} • ${roll.perRollWeight.toStringAsFixed(2)} ${roll.unit}',
              ),
              onTap: () => Navigator.of(context).pop(roll),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _RollEntryTile extends StatelessWidget {
  const _RollEntryTile({required this.entry, required this.onRemove});

  final _RollEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.roll.rollNo),
              subtitle: Text(
                '${entry.roll.vendorName} • ${entry.roll.perRollWeight.toStringAsFixed(2)} ${entry.roll.unit}',
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: TextField(
              controller: entry.weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight used',
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextField(
              controller: entry.layersCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Layers',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove roll',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _SizeEntryTile extends StatelessWidget {
  const _SizeEntryTile({
    required this.entry,
    required this.totalLayers,
    required this.bundleSize,
    required this.onRemove,
  });

  final _SizeEntry entry;
  final int totalLayers;
  final int bundleSize;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final totalPieces =
        (entry.patternCount ?? 0) > 0 ? (entry.patternCount ?? 0) * totalLayers : 0;
    final bundleCount = bundleSize > 0
        ? ((totalLayers + bundleSize - 1) ~/ bundleSize) * (entry.patternCount ?? 0)
        : 0;
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
                  child: TextField(
                    controller: entry.sizeCtrl,
                    decoration: const InputDecoration(labelText: 'Size label'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: entry.patternCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Pattern count'),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove size',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              children: [
                Text('Total layers: $totalLayers'),
                Text('Estimated pieces: $totalPieces'),
                Text('Approx. bundles: $bundleCount'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

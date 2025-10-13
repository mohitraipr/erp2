import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/api_lot.dart';
import '../models/fabric_roll.dart';
import '../models/login_response.dart';
import '../services/api_service.dart';
import '../utils/download_helper.dart';
import 'login_page.dart';

class ResponsePage extends StatefulWidget {
  static const routeName = '/response';
  final LoginResponse data;
  final ApiService api;

  const ResponsePage({super.key, required this.data, required this.api});

  @override
  State<ResponsePage> createState() => _ResponsePageState();
}

class RollSelection {
  final FabricRoll roll;
  final TextEditingController weightCtrl = TextEditingController();
  VoidCallback? _listener;

  RollSelection(this.roll);

  double? get weightUsed {
    final value = weightCtrl.text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  void registerListener(VoidCallback listener) {
    _listener = listener;
    weightCtrl.addListener(listener);
  }

  void dispose() {
    if (_listener != null) {
      weightCtrl.removeListener(_listener!);
    }
    weightCtrl.dispose();
  }
}

class SizeEntryData {
  final TextEditingController sizeCtrl = TextEditingController();
  final TextEditingController patternCtrl = TextEditingController();
  final TextEditingController layersCtrl = TextEditingController();
  VoidCallback? _listener;

  void registerListener(VoidCallback listener) {
    _listener = listener;
    sizeCtrl.addListener(listener);
    patternCtrl.addListener(listener);
    layersCtrl.addListener(listener);
  }

  int? get patternCount {
    final raw = patternCtrl.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  int? get layers {
    final raw = layersCtrl.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  int? get totalPieces {
    final p = patternCount;
    final l = layers;
    if (p == null || l == null) return null;
    return p * l;
  }

  int bundleCount(int bundleSize) {
    final total = totalPieces;
    if (total == null || bundleSize <= 0) return 0;
    return (total + bundleSize - 1) ~/ bundleSize;
  }

  Map<String, dynamic> toPayload() {
    return {
      'sizeLabel': sizeCtrl.text.trim(),
      'patternCount': patternCount ?? 0,
      'layers': layers ?? 0,
      'totalPieces': totalPieces ?? 0,
    };
  }

  void clear() {
    sizeCtrl.clear();
    patternCtrl.clear();
    layersCtrl.clear();
  }

  void dispose() {
    if (_listener != null) {
      sizeCtrl.removeListener(_listener!);
      patternCtrl.removeListener(_listener!);
      layersCtrl.removeListener(_listener!);
    }
    sizeCtrl.dispose();
    patternCtrl.dispose();
    layersCtrl.dispose();
  }
}

class _ResponsePageState extends State<ResponsePage> {
  final GlobalKey<FormState> _lotFormKey = GlobalKey<FormState>();
  final TextEditingController _skuCtrl = TextEditingController();
  final TextEditingController _bundleSizeCtrl = TextEditingController(text: '12');
  final TextEditingController _remarkCtrl = TextEditingController();
  TextEditingController? _rollCtrl;

  final List<SizeEntryData> _sizes = [];
  final List<RollSelection> _selectedRolls = [];

  Map<String, List<FabricRoll>> _rollsByType = {};
  List<ApiLotSummary> _myLots = [];
  ApiLot? _recentLot;

  String? _selectedFabric;
  bool _loadingRolls = false;
  bool _loadingLots = false;
  bool _creatingLot = false;
  String? _rollsError;
  String? _lotsError;

  bool get _isCuttingMaster => widget.data.normalizedRole == 'cutting_master';

  int get _bundleSize => int.tryParse(_bundleSizeCtrl.text.trim()) ?? 0;

  int get _totalPieces => _sizes.fold<int>(
        0,
        (sum, item) => sum + (item.totalPieces ?? 0),
      );

  int get _totalBundles => _sizes.fold<int>(
        0,
        (sum, item) => sum + item.bundleCount(_bundleSize),
      );

  double get _totalWeightUsed => _selectedRolls.fold<double>(
        0,
        (sum, item) => sum + (item.weightUsed ?? 0),
      );

  @override
  void initState() {
    super.initState();
    _bundleSizeCtrl.addListener(_onFormChanged);
    _addSizeEntry(notify: false);
    if (_isCuttingMaster) {
      _loadRolls();
      _loadMyLots();
    }
  }

  @override
  void dispose() {
    _skuCtrl.dispose();
    _bundleSizeCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _remarkCtrl.dispose();
    for (final size in _sizes) {
      size.dispose();
    }
    for (final roll in _selectedRolls) {
      roll.dispose();
    }
    widget.api.dispose();
    super.dispose();
  }

  Future<void> _loadRolls() async {
    setState(() {
      _loadingRolls = true;
      _rollsError = null;
    });
    try {
      final data = await widget.api.fetchFabricRolls();
      if (!mounted) return;
      setState(() {
        _rollsByType = data;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _rollsError = e.message);
    } finally {
      if (!mounted) return;
      setState(() => _loadingRolls = false);
    }
  }

  Future<void> _loadMyLots() async {
    setState(() {
      _loadingLots = true;
      _lotsError = null;
    });
    try {
      final lots = await widget.api.fetchMyLots();
      if (!mounted) return;
      setState(() {
        _myLots = lots;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _lotsError = e.message);
    } finally {
      if (!mounted) return;
      setState(() => _loadingLots = false);
    }
  }

  void _addSizeEntry({bool notify = true}) {
    final entry = SizeEntryData();
    entry.registerListener(_onFormChanged);
    if (notify) {
      setState(() => _sizes.add(entry));
    } else {
      _sizes.add(entry);
    }
  }

  void _removeSizeEntry(int index) {
    if (_sizes.length == 1) return;
    final removed = _sizes.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onSelectRoll(FabricRoll roll) {
    if (_selectedRolls.any((element) => element.roll.rollNo == roll.rollNo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Roll ${roll.rollNo} is already selected.')),
      );
      return;
    }
    final selection = RollSelection(roll)..registerListener(_onFormChanged);
    setState(() {
      _selectedRolls.add(selection);
    });
    _rollCtrl?.clear();
    FocusScope.of(context).unfocus();
  }

  void _removeRoll(int index) {
    final removed = _selectedRolls.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _createLot() async {
    if (_creatingLot) return;
    final form = _lotFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_selectedFabric == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a fabric type.')),
      );
      return;
    }

    if (_selectedRolls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one roll to the lot.')),
      );
      return;
    }

    RollSelection? invalidRoll;
    for (final roll in _selectedRolls) {
      if ((roll.weightUsed ?? 0) <= 0) {
        invalidRoll = roll;
        break;
      }
    }
    if (invalidRoll != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter the weight used for roll ${invalidRoll.roll.rollNo}.',
          ),
        ),
      );
      return;
    }

    if (_bundleSize <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bundle size must be a positive number.')),
      );
      return;
    }

    final sizePayload = _sizes.map((e) => e.toPayload()).toList();
    final rollPayload = _selectedRolls
        .map((e) => {
              'rollNo': e.roll.rollNo,
              'weightUsed': e.weightUsed,
            })
        .toList();

    setState(() => _creatingLot = true);
    try {
      final lot = await widget.api.createLot(
        sku: _skuCtrl.text.trim(),
        fabricType: _selectedFabric!,
        bundleSize: _bundleSize,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        sizes: sizePayload,
        rolls: rollPayload,
      );

      if (!mounted) return;

      setState(() {
        _recentLot = lot;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lot ${lot.lotNumber} created successfully.')),
      );

      _resetForm();
      await _loadMyLots();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _creatingLot = false);
      }
    }
  }

  void _resetForm() {
    _skuCtrl.clear();
    _remarkCtrl.clear();
    _bundleSizeCtrl.text = '12';
    _rollSearchCtrl.clear();
    _selectedFabric = null;
    for (final size in _sizes) {
      size.dispose();
    }
    for (final roll in _selectedRolls) {
      roll.dispose();
    }
    _sizes.clear();
    _selectedRolls.clear();
    _addSizeEntry(notify: false);
    setState(() {});
  }

  Future<void> _handleDownload({
    required int lotId,
    required String lotNumber,
    required LotCsvType type,
  }) async {
    try {
      final csv = await widget.api.downloadLotCsv(lotId: lotId, type: type);
      final filename = 'lot-$lotNumber-${type.name}.csv';
      final saved = await saveCsvToDevice(filename, csv);
      if (!mounted) return;
      if (saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download started for $filename.')),
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Download ${type == LotCsvType.bundles ? 'Bundle' : 'Piece'} CSV'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Copy the CSV data below:'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: SingleChildScrollView(
                        child: SelectableText(csv),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: csv));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CSV copied to clipboard.')),
                    );
                  },
                  child: const Text('Copy to clipboard'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _openLotDetail(ApiLotSummary summary) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final detail = await widget.api.fetchLotDetail(summary.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return LotDetailSheet(
            lot: detail,
            onDownload: (type) => _handleDownload(
              lotId: detail.id,
              lotNumber: detail.lotNumber,
              type: type,
            ),
          );
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCuttingMaster) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Aurora Workspace'),
          actions: [
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
        ),
        body: _buildWelcomeCard(context),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aurora Cutting Master'),
          actions: [
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadRolls();
                _loadMyLots();
              },
            ),
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Create lot'),
              Tab(text: 'My lots'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCreateLotTab(context),
            _buildMyLotsTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${widget.data.username}!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You are signed in as ${widget.data.role}. Use the menu to access your tools.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateLotTab(BuildContext context) {
    if (_loadingRolls && _rollsByType.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rollsError != null && _rollsByType.isEmpty) {
      return _ErrorState(
        message: _rollsError!,
        onRetry: _loadRolls,
      );
    }

    final fabricTypes = _rollsByType.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadRolls();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntroCard(context),
            const SizedBox(height: 16),
            Form(
              key: _lotFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LotInfoCard(
                    skuCtrl: _skuCtrl,
                    bundleSizeCtrl: _bundleSizeCtrl,
                    remarkCtrl: _remarkCtrl,
                    fabricTypes: fabricTypes,
                    selectedFabric: _selectedFabric,
                    onFabricChanged: (value) {
                      setState(() {
                        _selectedFabric = value;
                        for (final roll in _selectedRolls) {
                          roll.dispose();
                        }
                        _selectedRolls.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSizesCard(context),
                  const SizedBox(height: 16),
                  _buildRollsCard(context),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      icon: _creatingLot
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.playlist_add_check),
                      label: Text(_creatingLot ? 'Creating lot…' : 'Create lot'),
                      onPressed: _creatingLot ? null : _createLot,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildLotSummaryCard(context),
            if (_recentLot != null) ...[
              const SizedBox(height: 24),
              _RecentLotCard(
                lot: _recentLot!,
                onDownload: (type) => _handleDownload(
                  lotId: _recentLot!.id,
                  lotNumber: _recentLot!.lotNumber,
                  type: type,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${widget.data.username}',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Build your lot by selecting a fabric, choosing rolls, and entering pattern + layer counts. '
              'Bundle codes and piece codes will be generated automatically.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizesCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Size breakdown',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total pieces are automatically calculated using Pattern × Layers.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addSizeEntry(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add size'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sizes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = _sizes[index];
                final pieces = entry.totalPieces;
                final bundles = entry.bundleCount(_bundleSize);
                return _SizeEntryCard(
                  index: index,
                  entry: entry,
                  canRemove: _sizes.length > 1,
                  onRemove: () => _removeSizeEntry(index),
                  pieces: pieces,
                  bundles: bundles,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRollsCard(BuildContext context) {
    final theme = Theme.of(context);
    final rolls = _selectedFabric == null
        ? <FabricRoll>[]
        : _rollsByType[_selectedFabric] ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fabric rolls',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedFabric == null
                  ? 'Choose a fabric type above to search available rolls.'
                  : 'Search rolls for $_selectedFabric and enter the weight used for each roll.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Autocomplete<FabricRoll>(
              optionsBuilder: (value) {
                if (_selectedFabric == null) {
                  return const Iterable<FabricRoll>.empty();
                }
                final query = value.text.toLowerCase();
                if (query.isEmpty) return rolls;
                return rolls.where((roll) => roll.rollNo.toLowerCase().contains(query));
              },
              displayStringForOption: (option) => option.rollNo,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                _rollCtrl = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: _selectedFabric != null,
                  decoration: const InputDecoration(
                    labelText: 'Search roll number',
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(option.rollNo),
                            subtitle: Text(
                              '${option.perRollWeight.toStringAsFixed(2)} ${option.unit} • ${option.vendorName}',
                            ),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              onSelected: _onSelectRoll,
            ),
            const SizedBox(height: 16),
            if (_selectedRolls.isEmpty)
              Text(
                'No rolls selected yet.',
                style: theme.textTheme.bodySmall,
              ),
            if (_selectedRolls.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedRolls.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final selection = _selectedRolls[index];
                  return _RollCard(
                    selection: selection,
                    onRemove: () => _removeRoll(index),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLotSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SummaryTile(
              label: 'Bundle size',
              value: _bundleSize > 0 ? _bundleSize.toString() : '—',
              icon: Icons.all_inbox,
            ),
            _SummaryTile(
              label: 'Total bundles',
              value: _totalBundles.toString(),
              icon: Icons.grid_view,
            ),
            _SummaryTile(
              label: 'Total pieces',
              value: _totalPieces.toString(),
              icon: Icons.view_module,
            ),
            _SummaryTile(
              label: 'Weight used',
              value: _totalWeightUsed.toStringAsFixed(2),
              icon: Icons.scale,
              suffix: 'kg',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyLotsTab(BuildContext context) {
    if (_loadingLots && _myLots.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lotsError != null && _myLots.isEmpty) {
      return _ErrorState(
        message: _lotsError!,
        onRetry: _loadMyLots,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyLots,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _myLots.length + (_loadingLots ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _myLots.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final lot = _myLots[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _LotCard(
              lot: lot,
              onViewDetail: () => _openLotDetail(lot),
              onDownloadBundles: () => _handleDownload(
                lotId: lot.id,
                lotNumber: lot.lotNumber,
                type: LotCsvType.bundles,
              ),
              onDownloadPieces: () => _handleDownload(
                lotId: lot.id,
                lotNumber: lot.lotNumber,
                type: LotCsvType.pieces,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LotInfoCard extends StatelessWidget {
  final TextEditingController skuCtrl;
  final TextEditingController bundleSizeCtrl;
  final TextEditingController remarkCtrl;
  final List<String> fabricTypes;
  final String? selectedFabric;
  final ValueChanged<String?> onFabricChanged;

  const _LotInfoCard({
    required this.skuCtrl,
    required this.bundleSizeCtrl,
    required this.remarkCtrl,
    required this.fabricTypes,
    required this.selectedFabric,
    required this.onFabricChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lot information',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: skuCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'SKU',
                hintText: 'Enter the style or SKU',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'SKU is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedFabric,
              decoration: const InputDecoration(
                labelText: 'Fabric type',
              ),
              items: fabricTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: onFabricChanged,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Select a fabric type.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: bundleSizeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Bundle size',
                hintText: 'Pieces per bundle',
              ),
              validator: (value) {
                final parsed = int.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter a positive number.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: remarkCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeEntryCard extends StatelessWidget {
  final int index;
  final SizeEntryData entry;
  final bool canRemove;
  final VoidCallback onRemove;
  final int? pieces;
  final int bundles;

  const _SizeEntryCard({
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.onRemove,
    required this.pieces,
    required this.bundles,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text('Size ${index + 1}', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (canRemove)
                IconButton(
                  tooltip: 'Remove size',
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: entry.sizeCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Size label',
              hintText: 'e.g. M, 32, 10',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter a size label.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: entry.patternCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pattern count',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: entry.layersCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Layers',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniInfo(label: 'Total pieces', value: pieces?.toString() ?? '—'),
              _MiniInfo(label: 'Bundles', value: bundles > 0 ? bundles.toString() : '—'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RollCard extends StatelessWidget {
  final RollSelection selection;
  final VoidCallback onRemove;

  const _RollCard({required this.selection, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Roll ${selection.roll.rollNo}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Available: ${selection.roll.perRollWeight.toStringAsFixed(2)} ${selection.roll.unit} • Vendor: ${selection.roll.vendorName}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove roll',
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: selection.weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Weight used',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? suffix;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          '$value${suffix != null ? ' $suffix' : ''}',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _LotCard extends StatelessWidget {
  final ApiLotSummary lot;
  final VoidCallback onViewDetail;
  final VoidCallback onDownloadBundles;
  final VoidCallback onDownloadPieces;

  const _LotCard({
    required this.lot,
    required this.onViewDetail,
    required this.onDownloadBundles,
    required this.onDownloadPieces,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Lot ${lot.lotNumber}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Chip(label: Text(lot.fabricType.isEmpty ? 'Fabric' : lot.fabricType)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _InfoRow(icon: Icons.style, label: 'SKU', value: lot.sku),
                _InfoRow(
                  icon: Icons.view_module,
                  label: 'Pieces',
                  value: lot.totalPieces?.toString() ?? '—',
                ),
                _InfoRow(
                  icon: Icons.grid_view,
                  label: 'Bundles',
                  value: lot.totalBundles?.toString() ?? '—',
                ),
                _InfoRow(
                  icon: Icons.scale,
                  label: 'Weight',
                  value: lot.totalWeight?.toStringAsFixed(2) ?? '—',
                  suffix: 'kg',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View details'),
                  onPressed: onViewDetail,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Bundle CSV'),
                  onPressed: onDownloadBundles,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_for_offline),
                  label: const Text('Piece CSV'),
                  onPressed: onDownloadPieces,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentLotCard extends StatelessWidget {
  final ApiLot lot;
  final ValueChanged<LotCsvType> onDownload;

  const _RecentLotCard({required this.lot, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lot ${lot.lotNumber} ready',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bundle and piece codes are generated. You can download them or review the breakdown below.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            _SizeTable(sizes: lot.sizes),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Bundle CSV'),
                  onPressed: () => onDownload(LotCsvType.bundles),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.download_for_offline),
                  label: const Text('Piece CSV'),
                  onPressed: () => onDownload(LotCsvType.pieces),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeTable extends StatelessWidget {
  final List<ApiLotSize> sizes;

  const _SizeTable({required this.sizes});

  @override
  Widget build(BuildContext context) {
    if (sizes.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DataTable(
        headingRowColor: MaterialStateProperty.resolveWith(
          (states) => Theme.of(context).colorScheme.primary.withOpacity(0.08),
        ),
        columns: const [
          DataColumn(label: Text('Size')), 
          DataColumn(label: Text('Pattern')), 
          DataColumn(label: Text('Pieces')), 
          DataColumn(label: Text('Bundles')),
        ],
        rows: sizes
            .map(
              (size) => DataRow(
                cells: [
                  DataCell(Text(size.sizeLabel)),
                  DataCell(Text(size.patternCount?.toString() ?? '—')),
                  DataCell(Text(size.totalPieces?.toString() ?? '—')),
                  DataCell(Text(size.bundleCount?.toString() ?? '—')),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          '$label: $value${suffix != null ? ' $suffix' : ''}',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class LotDetailSheet extends StatelessWidget {
  final ApiLot lot;
  final ValueChanged<LotCsvType> onDownload;

  const LotDetailSheet({super.key, required this.lot, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lot ${lot.lotNumber}',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Chip(label: Text(lot.fabricType)),
                  _InfoRow(icon: Icons.style, label: 'SKU', value: lot.sku),
                  _InfoRow(
                    icon: Icons.grid_view,
                    label: 'Bundles',
                    value: lot.totalBundles?.toString() ?? '—',
                  ),
                  _InfoRow(
                    icon: Icons.view_module,
                    label: 'Pieces',
                    value: lot.totalPieces?.toString() ?? '—',
                  ),
                ],
              ),
              if (lot.remark != null && lot.remark!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Remarks', style: theme.textTheme.titleSmall),
                Text(lot.remark!),
              ],
              const SizedBox(height: 16),
              _SizeTable(sizes: lot.sizes),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Bundle CSV'),
                    onPressed: () => onDownload(LotCsvType.bundles),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.download_for_offline),
                    label: const Text('Piece CSV'),
                    onPressed: () => onDownload(LotCsvType.pieces),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              onPressed: () => onRetry(),
            ),
          ],
        ),
      ),
    );
  }
}

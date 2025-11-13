import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/api_lot.dart';
import '../models/fabric_roll.dart';
import '../models/filter_options.dart';
import '../models/login_response.dart';
import '../services/api_service.dart';
import '../utils/download_helper.dart';
import 'login_page.dart';
import 'production_flow_page.dart';

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
  final TextEditingController layersCtrl = TextEditingController();
  VoidCallback? _listener;

  RollSelection(this.roll);

  double? get weightUsed {
    final value = weightCtrl.text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  int? get layers {
    final value = layersCtrl.text.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  void registerListener(VoidCallback listener) {
    _listener = listener;
    weightCtrl.addListener(listener);
    layersCtrl.addListener(listener);
  }

  void dispose() {
    if (_listener != null) {
      weightCtrl.removeListener(_listener!);
      layersCtrl.removeListener(_listener!);
    }
    weightCtrl.dispose();
    layersCtrl.dispose();
  }
}

class SizeEntryData {
  final TextEditingController sizeCtrl = TextEditingController();
  final TextEditingController patternCtrl = TextEditingController();
  VoidCallback? _listener;

  void registerListener(VoidCallback listener) {
    _listener = listener;
    sizeCtrl.addListener(listener);
    patternCtrl.addListener(listener);
  }

  int? get patternCount {
    final raw = patternCtrl.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  int? totalPieces(int totalLayers) {
    final p = patternCount;
    if (p == null || totalLayers <= 0) return null;
    return p * totalLayers;
  }

  int bundleCount(int bundleSize, int totalLayers) {
    if (bundleSize <= 0) return 0;
    final total = totalPieces(totalLayers);
    if (total == null || total <= 0) return 0;
    return (total + bundleSize - 1) ~/ bundleSize;
  }

  Map<String, dynamic> toPayload() {
    return {
      'sizeLabel': sizeCtrl.text.trim(),
      'patternCount': patternCount ?? 0,
    };
  }

  void clear() {
    sizeCtrl.clear();
    patternCtrl.clear();
  }

  void dispose() {
    if (_listener != null) {
      sizeCtrl.removeListener(_listener!);
      patternCtrl.removeListener(_listener!);
    }
    sizeCtrl.dispose();
    patternCtrl.dispose();
  }
}

const List<String> _alphaSizeOptions = [
  'XS',
  'S',
  'M',
  'L',
  'XL',
  '2XL',
  '3XL',
  '4XL',
  '5XL',
  '6XL',
];

const List<String> _numericSizeOptions = [
  '24',
  '25',
  '26',
  '27',
  '28',
  '29',
  '30',
  '31',
  '32',
  '33',
  '34',
  '35',
  '36',
  '37',
  '38',
  '39',
  '40',
  '41',
  '42',
  '43',
  '44',
  '45',
  '46',
];

const List<String> _allSizeOptions = [
  ..._alphaSizeOptions,
  ..._numericSizeOptions,
];

class _ResponsePageState extends State<ResponsePage> {
  late final String _normalizedRole;
  late final bool _isCuttingMasterRole;
  late final bool _isProductionRole;

  final GlobalKey<FormState> _lotFormKey = GlobalKey<FormState>();
  final TextEditingController _skuCtrl = TextEditingController();
  final TextEditingController _bundleSizeCtrl = TextEditingController(
    text: '25',
  );
  final TextEditingController _remarkCtrl = TextEditingController();
  final TextEditingController _lotSearchCtrl = TextEditingController();
  final TextEditingController _skuCodeCtrl = TextEditingController();
  TextEditingController? _rollCtrl;

  final List<SizeEntryData> _sizes = [];
  final List<RollSelection> _selectedRolls = [];

  Map<String, List<FabricRoll>> _rollsByType = {};
  List<ApiLotSummary> _myLots = [];
  List<ApiLotSummary> _filteredLots = [];
  ApiLot? _recentLot;

  List<String> _genders = [];
  List<String> _categories = [];
  String? _selectedGender;
  String? _selectedCategory;

  String? _selectedFabric;
  bool _loadingRolls = false;
  bool _loadingLots = false;
  bool _loadingFilters = false;
  bool _creatingLot = false;
  String? _rollsError;
  String? _lotsError;
  String? _filtersError;

  bool get _isCuttingMaster => _isCuttingMasterRole;

  int get _bundleSize => int.tryParse(_bundleSizeCtrl.text.trim()) ?? 0;

  int get _totalLayers =>
      _selectedRolls.fold<int>(0, (sum, item) => sum + (item.layers ?? 0));

  int get _totalPieces => _sizes.fold<int>(
    0,
    (sum, item) => sum + (item.totalPieces(_totalLayers) ?? 0),
  );

  int get _totalBundles => _sizes.fold<int>(
    0,
    (sum, item) => sum + item.bundleCount(_bundleSize, _totalLayers),
  );

  double get _totalWeightUsed => _selectedRolls.fold<double>(
    0,
    (sum, item) => sum + (item.weightUsed ?? 0),
  );

  @override
  void initState() {
    super.initState();
    _normalizedRole = widget.data.normalizedRole;
    _isCuttingMasterRole = _determineIsCuttingMaster(_normalizedRole, widget.data.role);
    _isProductionRole = const {
      'back_pocket',
      'stitching_master',
      'jeans_assembly',
      'washing',
      'washing_in',
      'finishing',
    }.contains(_normalizedRole);

    if (_isCuttingMaster) {
      _bundleSizeCtrl.addListener(_onFormChanged);
      _lotSearchCtrl.addListener(_onSearchFieldChanged);
      _skuCodeCtrl.addListener(_updateSkuFromParts);
      _addSizeEntry(notify: false);
      _loadFilters();
      _loadRolls();
      _loadMyLots();
    }
  }

  @override
  void dispose() {
    _skuCodeCtrl
      ..removeListener(_updateSkuFromParts)
      ..dispose();
    _skuCtrl.dispose();
    if (_isCuttingMaster) {
      _bundleSizeCtrl
        ..removeListener(_onFormChanged)
        ..dispose();
      _lotSearchCtrl
        ..removeListener(_onSearchFieldChanged)
        ..dispose();
    } else {
      _bundleSizeCtrl.dispose();
      _lotSearchCtrl.dispose();
    }
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
      if (mounted) {
        setState(() => _loadingRolls = false);
      }
    }
  }

  void _updateSkuFromParts() {
    final gender = _selectedGender?.trim();
    final category = _selectedCategory?.trim();
    final code = _skuCodeCtrl.text.trim();

    final parts = <String>[];
    if (gender != null && gender.isNotEmpty) {
      parts.add(gender.toUpperCase());
    }
    if (category != null && category.isNotEmpty) {
      parts.add(category.toUpperCase());
    }
    if (code.isNotEmpty) {
      parts.add(code.toUpperCase());
    }

    final sku = parts.isEmpty ? '' : 'KTT${parts.join()}';
    if (_skuCtrl.text != sku) {
      _skuCtrl.value = TextEditingValue(
        text: sku,
        selection: TextSelection.collapsed(offset: sku.length),
      );
    }
  }

  Future<void> _loadFilters() async {
    setState(() {
      _loadingFilters = true;
      _filtersError = null;
    });
    try {
      final FilterOptions filters = await widget.api.fetchFilters();
      if (!mounted) return;
      setState(() {
        _genders = filters.genders;
        _categories = filters.categories;
        if (!_genders.contains(_selectedGender)) {
          _selectedGender = null;
        }
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = null;
        }
      });
      _updateSkuFromParts();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _filtersError = e.message;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingFilters = false;
      });
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
        _applyLotFilter(notify: false);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _lotsError = e.message);
    } finally {
      if (mounted) {
        setState(() => _loadingLots = false);
      }
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

  void _onSearchFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _applyLotFilter({bool notify = true}) {
    final query = _lotSearchCtrl.text.trim().toLowerCase();
    List<ApiLotSummary> filtered;
    if (query.isEmpty) {
      filtered = List<ApiLotSummary>.from(_myLots);
    } else {
      filtered = _myLots.where((lot) {
        return lot.lotNumber.toLowerCase().contains(query) ||
            lot.sku.toLowerCase().contains(query) ||
            lot.fabricType.toLowerCase().contains(query);
      }).toList();
    }

    if (notify) {
      setState(() {
        _filteredLots = filtered;
      });
    } else {
      _filteredLots = filtered;
    }
  }

  void _clearLotSearch() {
    if (_lotSearchCtrl.text.isEmpty) return;
    _lotSearchCtrl.clear();
    _applyLotFilter();
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

    for (final roll in _selectedRolls) {
      if ((roll.weightUsed ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter the weight used for roll ${roll.roll.rollNo}.',
            ),
          ),
        );
        return;
      }

      if ((roll.layers ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter the layers cut for roll ${roll.roll.rollNo}.',
            ),
          ),
        );
        return;
      }
    }

    if (_bundleSize <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bundle size must be a positive number.')),
      );
      return;
    }

    final sizePayload = _sizes.map((e) => e.toPayload()).toList();
    final rollPayload = _selectedRolls
        .map(
          (e) => {
            'rollNo': e.roll.rollNo,
            'weightUsed': e.weightUsed,
            'layers': e.layers,
          },
        )
        .toList();

    setState(() => _creatingLot = true);
    try {
      final lot = await widget.api.createLot(
        sku: _skuCtrl.text.trim(),
        fabricType: _selectedFabric!,
        bundleSize: _bundleSize,
        remark: _remarkCtrl.text.trim().isEmpty
            ? null
            : _remarkCtrl.text.trim(),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
              title: Text(
                'Download ${type == LotCsvType.bundles ? 'Bundle' : 'Piece'} CSV',
              ),
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
                      child: SingleChildScrollView(child: SelectableText(csv)),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _logout() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    if (_isProductionRole) {
      return ProductionFlowPage(
        data: widget.data,
        api: widget.api,
        onLogout: _logout,
      );
    }

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
          children: [_buildCreateLotTab(context), _buildMyLotsTab(context)],
        ),
      ),
    );
  }

  bool _determineIsCuttingMaster(String normalizedRole, String rawRole) {
    if (normalizedRole == 'cutting_manager' || normalizedRole == 'cutting_master') {
      return true;
    }
    final lowered = rawRole.toLowerCase();
    return normalizedRole.contains('cutting') || lowered.contains('cutting');
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
      return _ErrorState(message: _rollsError!, onRetry: _loadRolls);
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
                    skuCodeCtrl: _skuCodeCtrl,
                    bundleSizeCtrl: _bundleSizeCtrl,
                    remarkCtrl: _remarkCtrl,
                    fabricTypes: fabricTypes,
                    selectedFabric: _selectedFabric,
                    genders: _genders,
                    categories: _categories,
                    selectedGender: _selectedGender,
                    selectedCategory: _selectedCategory,
                    loadingFilters: _loadingFilters,
                    filtersError: _filtersError,
                    onGenderChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                      _updateSkuFromParts();
                    },
                    onCategoryChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                      _updateSkuFromParts();
                    },
                    onRetryFilters: _loadFilters,
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
                      label: Text(
                        _creatingLot ? 'Creating lot…' : 'Create lot',
                      ),
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
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Build your lot by selecting a fabric, choosing rolls, and entering pattern counts. '
              'Total layers are taken from the selected rolls, and bundle/piece codes are generated automatically.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizesCard(BuildContext context) {
    final theme = Theme.of(context);
    final totalLayers = _totalLayers;
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalLayers > 0
                            ? 'Total pieces are calculated using Pattern × $totalLayers layers from selected rolls.'
                            : 'Add rolls with layers to calculate pieces from Pattern × Layers.',
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
                final pieces = entry.totalPieces(totalLayers);
                final bundles = entry.bundleCount(_bundleSize, totalLayers);
                return _SizeEntryCard(
                  index: index,
                  entry: entry,
                  canRemove: _sizes.length > 1,
                  onRemove: () => _removeSizeEntry(index),
                  pieces: pieces,
                  bundles: bundles,
                  totalLayers: totalLayers,
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedFabric == null
                  ? 'Choose a fabric type above to search available rolls.'
                  : 'Search rolls for $_selectedFabric and enter the weight and layers used for each roll.',
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
                return rolls.where(
                  (roll) => roll.rollNo.toLowerCase().contains(query),
                );
              },
              displayStringForOption: (option) => option.rollNo,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
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
              Text('No rolls selected yet.', style: theme.textTheme.bodySmall),
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
              label: 'Total layers',
              value: _totalLayers.toString(),
              icon: Icons.view_stream,
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

  Widget _buildLotSearchCard(BuildContext context) {
    final theme = Theme.of(context);
    final query = _lotSearchCtrl.text.trim();
    final hasQuery = query.isNotEmpty;
    final results = _filteredLots.length;
    final totalLots = _myLots.length;
    final statusText = hasQuery
        ? (results == 0
              ? 'No lots match "$query".'
              : '$results result${results == 1 ? '' : 's'} match "$query".')
        : 'Viewing $totalLots lot${totalLots == 1 ? '' : 's'}.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search lots',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Find a lot by lot number, SKU, or fabric type.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lotSearchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Search lots',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: hasQuery
                          ? IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: _clearLotSearch,
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _applyLotFilter(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Search'),
                  onPressed: () => _applyLotFilter(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              statusText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
      return _ErrorState(message: _lotsError!, onRetry: _loadMyLots);
    }

    final lots = _filteredLots;
    return RefreshIndicator(
      onRefresh: _loadMyLots,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildLotSearchCard(context),
          const SizedBox(height: 16),
          if (_lotsError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InlineInfoBanner(
                message: _lotsError!,
                onRetry: _loadMyLots,
              ),
            ),
          if (!_loadingLots && lots.isEmpty)
            _EmptyLotsState(
              query: _lotSearchCtrl.text.trim(),
              onClear: _lotSearchCtrl.text.isNotEmpty ? _clearLotSearch : null,
            ),
          for (final lot in lots)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _LotCard(
                lot: lot,
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
            ),
          if (_loadingLots)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class _LotInfoCard extends StatefulWidget {
  final TextEditingController skuCtrl;
  final TextEditingController skuCodeCtrl;
  final TextEditingController bundleSizeCtrl;
  final TextEditingController remarkCtrl;
  final List<String> fabricTypes;
  final String? selectedFabric;
  final List<String> genders;
  final List<String> categories;
  final String? selectedGender;
  final String? selectedCategory;
  final bool loadingFilters;
  final String? filtersError;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onRetryFilters;
  final ValueChanged<String?> onFabricChanged;

  const _LotInfoCard({
    required this.skuCtrl,
    required this.skuCodeCtrl,
    required this.bundleSizeCtrl,
    required this.remarkCtrl,
    required this.fabricTypes,
    required this.selectedFabric,
    required this.genders,
    required this.categories,
    required this.selectedGender,
    required this.selectedCategory,
    required this.loadingFilters,
    required this.filtersError,
    required this.onGenderChanged,
    required this.onCategoryChanged,
    required this.onRetryFilters,
    required this.onFabricChanged,
  });

  @override
  State<_LotInfoCard> createState() => _LotInfoCardState();
}

class _LotInfoCardState extends State<_LotInfoCard> {
  late final TextEditingController _fabricCtrl;
  late final FocusNode _fabricFocus;

  @override
  void initState() {
    super.initState();
    _fabricCtrl = TextEditingController(text: widget.selectedFabric ?? '');
    _fabricFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _LotInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.selectedFabric ?? '') != (oldWidget.selectedFabric ?? '')) {
      final updatedValue = widget.selectedFabric ?? '';
      if (_fabricCtrl.text != updatedValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _fabricCtrl.value = TextEditingValue(
            text: updatedValue,
            selection: TextSelection.collapsed(offset: updatedValue.length),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _fabricCtrl.dispose();
    _fabricFocus.dispose();
    super.dispose();
  }

  Iterable<String> _fabricOptionsBuilder(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.fabricTypes;
    }
    return widget.fabricTypes.where(
      (type) => type.toLowerCase().contains(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genderValue = widget.genders.contains(widget.selectedGender)
        ? widget.selectedGender
        : null;
    final categoryValue = widget.categories.contains(widget.selectedCategory)
        ? widget.selectedCategory
        : null;
    final filtersReady = !widget.loadingFilters && widget.filtersError == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lot information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.loadingFilters) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
            ],
            if (widget.filtersError != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Failed to load filters: ${widget.filtersError}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onRetryFilters,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              value: genderValue,
              items: widget.genders
                  .map(
                    (gender) =>
                        DropdownMenuItem(value: gender, child: Text(gender)),
                  )
                  .toList(),
              onChanged: filtersReady ? widget.onGenderChanged : null,
              decoration: const InputDecoration(
                labelText: 'Gender',
                hintText: 'Select a gender',
              ),
              validator: (value) {
                if (widget.loadingFilters) {
                  return 'Filters are loading.';
                }
                if (widget.filtersError != null) {
                  return 'Filters failed to load.';
                }
                if ((value ?? '').trim().isEmpty) {
                  return 'Select a gender.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: categoryValue,
              items: widget.categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: filtersReady ? widget.onCategoryChanged : null,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'Select a category',
              ),
              validator: (value) {
                if (widget.loadingFilters) {
                  return 'Filters are loading.';
                }
                if (widget.filtersError != null) {
                  return 'Filters failed to load.';
                }
                if ((value ?? '').trim().isEmpty) {
                  return 'Select a category.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.skuCodeCtrl,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'SKU code',
                hintText: 'Enter numeric code',
              ),
              validator: (value) {
                final trimmed = (value ?? '').trim();
                if (trimmed.isEmpty) {
                  return 'Enter a numeric code.';
                }
                if (int.tryParse(trimmed) == null) {
                  return 'Code must be numeric.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.skuCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'SKU',
                hintText: 'SKU is generated from gender, category, and code',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'SKU is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            RawAutocomplete<String>(
              focusNode: _fabricFocus,
              textEditingController: _fabricCtrl,
              optionsBuilder: _fabricOptionsBuilder,
              displayStringForOption: (option) => option,
              onSelected: (option) {
                _fabricCtrl.value = TextEditingValue(
                  text: option,
                  selection: TextSelection.collapsed(offset: option.length),
                );
                widget.onFabricChanged(option);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Fabric type',
                            suffixIcon: value.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear selection',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      widget.onFabricChanged(null);
                                    },
                                  ),
                          ),
                          validator: (text) {
                            final trimmed = text?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return 'Select a fabric type.';
                            }
                            if (!widget.fabricTypes.contains(trimmed)) {
                              return 'Choose a fabric from the list.';
                            }
                            return null;
                          },
                          onChanged: (text) {
                            final trimmed = text.trim();
                            if (trimmed.isEmpty) {
                              if (widget.selectedFabric != null) {
                                widget.onFabricChanged(null);
                              }
                            } else if (widget.selectedFabric != null &&
                                widget.selectedFabric != trimmed) {
                              widget.onFabricChanged(null);
                            }
                          },
                          onFieldSubmitted: (text) {
                            onFieldSubmitted();
                            final trimmed = text.trim();
                            if (widget.fabricTypes.contains(trimmed)) {
                              widget.onFabricChanged(trimmed);
                            }
                          },
                        );
                      },
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      height: 200,
                      width: 320,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.bundleSizeCtrl,
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
              controller: widget.remarkCtrl,
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

class _SizeEntryCard extends StatefulWidget {
  final int index;
  final SizeEntryData entry;
  final bool canRemove;
  final VoidCallback onRemove;
  final int? pieces;
  final int bundles;
  final int totalLayers;

  const _SizeEntryCard({
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.onRemove,
    required this.pieces,
    required this.bundles,
    required this.totalLayers,
  });

  @override
  State<_SizeEntryCard> createState() => _SizeEntryCardState();
}

class _SizeEntryCardState extends State<_SizeEntryCard> {
  final GlobalKey<FormFieldState<String>> _sizeFieldKey =
      GlobalKey<FormFieldState<String>>();
  late final FocusNode _sizeFocus;

  @override
  void initState() {
    super.initState();
    _sizeFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _SizeEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.sizeCtrl.text != widget.entry.sizeCtrl.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _sizeFieldKey.currentState?.didChange(widget.entry.sizeCtrl.text);
        }
      });
    }
  }

  @override
  void dispose() {
    _sizeFocus.dispose();
    super.dispose();
  }

  Iterable<String> _sizeOptionsBuilder(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _allSizeOptions;
    }
    return _allSizeOptions.where(
      (option) => option.toLowerCase().contains(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Size ${widget.index + 1}',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              if (widget.canRemove)
                IconButton(
                  tooltip: 'Remove size',
                  icon: const Icon(Icons.close),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          FormField<String>(
            key: _sizeFieldKey,
            initialValue: widget.entry.sizeCtrl.text,
            validator: (_) {
              if (widget.entry.sizeCtrl.text.trim().isEmpty) {
                return 'Enter a size label.';
              }
              return null;
            },
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RawAutocomplete<String>(
                    focusNode: _sizeFocus,
                    textEditingController: widget.entry.sizeCtrl,
                    optionsBuilder: _sizeOptionsBuilder,
                    displayStringForOption: (option) => option,
                    onSelected: (option) {
                      widget.entry.sizeCtrl.text = option;
                      state.didChange(option);
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Size label',
                              hintText: 'e.g. M, 32, 10',
                              errorText: state.errorText,
                            ),
                            onChanged: state.didChange,
                          );
                        },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: SizedBox(
                            height: 200,
                            width: 240,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.entry.patternCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Pattern count'),
            validator: (value) {
              final parsed = int.tryParse(value ?? '');
              if (parsed == null || parsed <= 0) {
                return 'Required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.totalLayers > 0
                  ? 'Using ${widget.totalLayers} total layers from selected rolls.'
                  : 'Add rolls to specify total layers for this lot.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniInfo(
                label: 'Total pieces',
                value: widget.pieces?.toString() ?? '—',
              ),
              _MiniInfo(
                label: 'Bundles',
                value: widget.bundles > 0 ? widget.bundles.toString() : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaxWeightInputFormatter extends TextInputFormatter {
  _MaxWeightInputFormatter(this.maxValue);

  final double maxValue;
  static final RegExp _validPattern = RegExp(r'^[0-9]*[.]?[0-9]*$');

  String _format(double value) {
    var text = value.toStringAsFixed(2);
    if (text.contains('.')) {
      text = text.replaceAll(RegExp(r'0+$'), '');
      text = text.replaceAll(RegExp(r'[.]$'), '');
    }
    return text;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    if (!_validPattern.hasMatch(text)) {
      return oldValue;
    }

    final parsed = double.tryParse(text);
    if (parsed == null) {
      return newValue;
    }

    if (parsed > maxValue) {
      final capped = _format(maxValue);
      return TextEditingValue(
        text: capped,
        selection: TextSelection.collapsed(offset: capped.length),
      );
    }

    return newValue;
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
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
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
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: selection.weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    _MaxWeightInputFormatter(selection.roll.perRollWeight),
                  ],
                  decoration: const InputDecoration(labelText: 'Weight used'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: selection.layersCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Layers cut'),
                ),
              ),
            ],
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
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          '$value${suffix != null ? ' $suffix' : ''}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _InlineInfoBanner extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _InlineInfoBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          TextButton(onPressed: () => onRetry(), child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyLotsState extends StatelessWidget {
  final String query;
  final VoidCallback? onClear;

  const _EmptyLotsState({required this.query, this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = query.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No matching lots' : 'No lots yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try refining your search or clear the filter to see all lots.'
                  : 'Lots that you create will appear here with quick download actions.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasQuery && onClear != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear search'),
                onPressed: onClear,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  final ApiLotSummary lot;
  final VoidCallback onDownloadBundles;
  final VoidCallback onDownloadPieces;

  const _LotCard({
    required this.lot,
    required this.onDownloadBundles,
    required this.onDownloadPieces,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = lot.createdAt;
    String? createdLabel;
    if (createdAt != null) {
      final local = createdAt.toLocal();
      final twoDigits = (int value) => value.toString().padLeft(2, '0');
      createdLabel =
          '${local.day.toString().padLeft(2, '0')}-${twoDigits(local.month)}-${local.year} • ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
    }
    final fabricLabel = lot.fabricType.isEmpty ? 'Fabric' : lot.fabricType;
    final weightLabel = lot.totalWeight != null
        ? lot.totalWeight!.toStringAsFixed(2)
        : null;
    final bundleSizeLabel = lot.bundleSize != null && lot.bundleSize! > 0
        ? lot.bundleSize.toString()
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lot ${lot.lotNumber}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (createdLabel != null)
                  Text(
                    createdLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(width: 12),
                Chip(label: Text(fabricLabel)),
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
                if (bundleSizeLabel != null)
                  _InfoRow(
                    icon: Icons.all_inbox,
                    label: 'Bundle size',
                    value: bundleSizeLabel,
                  ),
                if (weightLabel != null)
                  _InfoRow(
                    icon: Icons.scale,
                    label: 'Weight',
                    value: weightLabel,
                    suffix: 'kg',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _MiniInfo(
                      label: 'Total bundles',
                      value: (lot.totalBundles ?? 0).toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniInfo(
                      label: 'Pieces ready',
                      value: (lot.totalPieces ?? 0).toString(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
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
        headingRowColor: WidgetStateProperty.resolveWith(
          (states) =>
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
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
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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

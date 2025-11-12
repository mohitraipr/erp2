import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/api_lot.dart';
import '../models/fabric_roll.dart';
import '../models/filter_options.dart';
import '../models/login_response.dart';
import '../models/master_record.dart';
import '../models/production_flow_entry.dart';
import '../models/production_lot_preview.dart';
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
  static const Set<String> _masterCreatorRoles = {
    'back_pocket',
    'jeans_assembly',
    'stitching_master',
  };

  static const Map<String, String> _productionRoleStage = {
    'back_pocket': 'back_pocket',
    'stitching_master': 'stitching_master',
    'jeans_assembly': 'jeans_assembly',
    'washing': 'washing',
    'washing_in': 'washing_in',
    'finishing': 'finishing',
  };

  static const Set<String> _stagesRequiringMaster = {
    'back_pocket',
    'stitching_master',
    'jeans_assembly',
    'finishing',
  };

  static const Map<String, String> _stageCodeLabels = {
    'back_pocket': 'Lot number',
    'stitching_master': 'Lot number',
    'jeans_assembly': 'Bundle code',
    'washing': 'Lot number',
    'washing_in': 'Piece code',
    'finishing': 'Bundle code',
  };

  static const Set<String> _bundleStages = {
    'jeans_assembly',
    'finishing',
  };

  static const Set<String> _stagesWithRejections = {
    'jeans_assembly',
    'washing_in',
  };

  final GlobalKey<FormState> _lotFormKey = GlobalKey<FormState>();
  final TextEditingController _skuCtrl = TextEditingController();
  final TextEditingController _bundleSizeCtrl = TextEditingController(
    text: '25',
  );
  final TextEditingController _remarkCtrl = TextEditingController();
  final TextEditingController _lotSearchCtrl = TextEditingController();
  final TextEditingController _skuCodeCtrl = TextEditingController();
  TextEditingController? _rollCtrl;

  final GlobalKey<FormState> _masterFormKey = GlobalKey<FormState>();
  final TextEditingController _masterNameCtrl = TextEditingController();
  final TextEditingController _masterContactCtrl = TextEditingController();
  final TextEditingController _masterNotesCtrl = TextEditingController();

  final TextEditingController _productionCodeCtrl = TextEditingController();
  final TextEditingController _productionRemarkCtrl = TextEditingController();
  final TextEditingController _rejectedPiecesCtrl = TextEditingController();

  final List<SizeEntryData> _sizes = [];
  final List<RollSelection> _selectedRolls = [];
  int? _lotBulkMasterId;

  Map<String, List<FabricRoll>> _rollsByType = {};
  List<ApiLotSummary> _myLots = [];
  List<ApiLotSummary> _filteredLots = [];
  ApiLot? _recentLot;

  List<MasterRecord> _masters = [];
  bool _loadingMasters = false;
  bool _creatingMaster = false;
  String? _mastersError;

  List<ProductionFlowEntry> _productionEntries = [];
  bool _loadingProductionEntries = false;
  bool _submittingProduction = false;
  String? _productionEntriesError;
  Map<String, dynamic>? _lastProductionResult;
  Map<String, dynamic>? _bundleDetails;
  bool _loadingBundleDetails = false;
  String? _bundleError;
  int? _selectedMasterId;
  ProductionLotPreview? _lotPreview;
  bool _loadingLotPreview = false;
  String? _lotPreviewError;
  final Map<int, int?> _lotSizeMasters = {};

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

  bool get _isCuttingMaster {
    final normalizedRole = _normalizedRole;
    if (normalizedRole == 'cutting_manager') {
      return true;
    }

    final rawRole = widget.data.role.toLowerCase();
    return normalizedRole.contains('cutting') || rawRole.contains('cutting');
  }

  String get _normalizedRole => widget.data.normalizedRole;

  bool get _canManageMasters => _masterCreatorRoles.contains(_normalizedRole);

  String? get _productionStage => _productionRoleStage[_normalizedRole];

  bool get _isProductionStageUser => _productionStage != null;

  bool get _stageRequiresMaster {
    final stage = _productionStage;
    if (stage == null) return false;
    return _stagesRequiringMaster.contains(stage);
  }

  String get _productionCodeLabel {
    final stage = _productionStage;
    if (stage == null) return 'Code';
    return _stageCodeLabels[stage] ?? 'Code';
  }

  bool get _stageRequiresBundle {
    final stage = _productionStage;
    if (stage == null) return false;
    return _bundleStages.contains(stage);
  }

  bool get _stageAllowsRejections {
    final stage = _productionStage;
    if (stage == null) return false;
    return _stagesWithRejections.contains(stage);
  }

  bool get _isLotAssignmentStage {
    final stage = _productionStage;
    return stage == 'back_pocket' || stage == 'stitching_master';
  }

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
    _bundleSizeCtrl.addListener(_onFormChanged);
    _lotSearchCtrl.addListener(_onSearchFieldChanged);
    _skuCodeCtrl.addListener(_updateSkuFromParts);
    _addSizeEntry(notify: false);
    _loadFilters();
    if (_canManageMasters || _stageRequiresMaster) {
      _loadMasters();
    }
    if (_isProductionStageUser) {
      _loadProductionEntries();
    }
    if (_isCuttingMaster) {
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
    _bundleSizeCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _remarkCtrl.dispose();
    _lotSearchCtrl
      ..removeListener(_onSearchFieldChanged)
      ..dispose();
    _masterNameCtrl.dispose();
    _masterContactCtrl.dispose();
    _masterNotesCtrl.dispose();
    _productionCodeCtrl.dispose();
    _productionRemarkCtrl.dispose();
    _rejectedPiecesCtrl.dispose();
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

  Future<void> _loadMasters() async {
    setState(() {
      _loadingMasters = true;
      _mastersError = null;
    });
    try {
      final masters = await widget.api.fetchMasters();
      if (!mounted) return;
      setState(() {
        _masters = masters;
        if (_stageRequiresMaster) {
          if (_selectedMasterId != null &&
              !_masters.any((master) => master.id == _selectedMasterId)) {
            _selectedMasterId = null;
          }
          if (!_isLotAssignmentStage &&
              _selectedMasterId == null &&
              _masters.isNotEmpty) {
            _selectedMasterId = _masters.first.id;
          }
        }
        if (_lotBulkMasterId != null &&
            !_masters.any((master) => master.id == _lotBulkMasterId)) {
          _lotBulkMasterId = null;
        }
        if (_isLotAssignmentStage &&
            _lotBulkMasterId == null &&
            _masters.length == 1) {
          _lotBulkMasterId = _masters.first.id;
        }
        if (_lotSizeMasters.isNotEmpty) {
          final validIds = _masters.map((master) => master.id).toSet();
          final updated = <int, int?>{};
          _lotSizeMasters.forEach((sizeId, masterId) {
            if (masterId != null && !validIds.contains(masterId)) {
              updated[sizeId] = null;
            } else {
              updated[sizeId] = masterId;
            }
          });
          _lotSizeMasters
            ..clear()
            ..addAll(updated);
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _mastersError = e.message);
    } finally {
      if (mounted) {
        setState(() => _loadingMasters = false);
      }
    }
  }

  Future<void> _createMasterRecord() async {
    if (_creatingMaster) return;
    final form = _masterFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final name = _masterNameCtrl.text.trim();
    final contact = _masterContactCtrl.text.trim();
    final notes = _masterNotesCtrl.text.trim();

    setState(() => _creatingMaster = true);
    try {
      final master = await widget.api.createMaster(
        masterName: name,
        contactNumber: contact.isEmpty ? null : contact,
        notes: notes.isEmpty ? null : notes,
      );

      if (!mounted) return;
      setState(() {
        _masters.insert(0, master);
        _mastersError = null;
        if (_stageRequiresMaster) {
          _selectedMasterId = master.id;
        }
      });
      _masterNameCtrl.clear();
      _masterContactCtrl.clear();
      _masterNotesCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Master ${master.masterName} created.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _creatingMaster = false);
      }
    }
  }

  Future<void> _loadProductionEntries() async {
    final stage = _productionStage;
    if (stage == null) return;
    setState(() {
      _loadingProductionEntries = true;
      _productionEntriesError = null;
    });
    try {
      final entries = await widget.api.fetchProductionFlowEntries(
        stage: stage,
        limit: 1000,
      );
      if (!mounted) return;
      setState(() {
        _productionEntries = entries;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _productionEntriesError = e.message);
    } finally {
      if (mounted) {
        setState(() => _loadingProductionEntries = false);
      }
    }
  }

  List<String> _parseRejectedPiecesInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }

    final tokens = trimmed
        .split(RegExp('[\\s,]+'))
        .map((token) => token.trim().toUpperCase())
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return const <String>[];
    }

    final seen = <String>{};
    final result = <String>[];
    for (final token in tokens) {
      if (seen.add(token)) {
        result.add(token);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _buildLotAssignmentPayload() {
    final preview = _lotPreview;
    if (preview == null) return const [];
    if (preview.sizes.isEmpty) return const [];

    final sizeById = <int, ProductionLotSize>{
      for (final size in preview.sizes) size.sizeId: size,
    };

    final payload = <Map<String, dynamic>>[];
    _lotSizeMasters.forEach((sizeId, masterId) {
      final size = sizeById[sizeId];
      if (size == null) {
        return;
      }
      if (size.pendingBundles <= 0) {
        return;
      }
      if (masterId == null) {
        return;
      }
      payload.add({
        'sizeId': size.sizeId,
        'sizeLabel': size.sizeLabel,
        'masterId': masterId,
      });
    });

    return payload;
  }

  bool get _hasLotAssignmentSelection {
    final preview = _lotPreview;
    if (preview == null) return false;
    final pendingSizes = preview.sizes
        .where((size) => size.pendingBundles > 0)
        .toList(growable: false);
    if (pendingSizes.isEmpty) {
      return false;
    }
    for (final size in pendingSizes) {
      final masterId = _lotSizeMasters[size.sizeId];
      if (masterId == null) {
        return false;
      }
    }
    return true;
  }

  void _clearLotPreviewState() {
    _lotPreview = null;
    _lotPreviewError = null;
    _lotSizeMasters.clear();
  }

  void _applyMasterToAllPendingMasters() {
    final masterId = _lotBulkMasterId;
    final preview = _lotPreview;
    if (masterId == null || preview == null) {
      return;
    }
    setState(() {
      for (final size in preview.sizes) {
        if (size.pendingBundles > 0) {
          _lotSizeMasters[size.sizeId] = masterId;
        }
      }
    });
  }

  Future<void> _submitProductionEntry() async {
    if (_submittingProduction) return;
    final stage = _productionStage;
    if (stage == null) return;

    final code = _productionCodeCtrl.text.trim().toUpperCase();
    final remark = _productionRemarkCtrl.text.trim();
    final rejectedPieces = _stageAllowsRejections
        ? _parseRejectedPiecesInput(_rejectedPiecesCtrl.text)
        : const <String>[];

    List<Map<String, dynamic>>? assignments;
    int? masterId = _selectedMasterId;

    if (_stageRequiresMaster) {
      if (_isLotAssignmentStage) {
        if (code.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a lot number before submitting.')),
          );
          return;
        }
        final preview = _lotPreview;
        if (preview == null || preview.lotNumber.toUpperCase() != code) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Load the lot details and assign masters before submitting.')),
          );
          return;
        }
        final payload = _buildLotAssignmentPayload();
        if (payload.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select a master for at least one pending size.')),
          );
          return;
        }
        assignments = payload;
        masterId = null;
      } else {
        if (_selectedMasterId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select a master before submitting.')),
          );
          return;
        }
      }
    }

    if (code.isEmpty && rejectedPieces.isEmpty) {
      final label = _productionCodeLabel.toLowerCase();
      final message = _stageAllowsRejections
          ? 'Enter a $label or at least one rejected piece code.'
          : 'Please enter a $label.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    setState(() => _submittingProduction = true);
    try {
      final result = await widget.api.submitProductionFlowEntry(
        code: code,
        remark: remark.isEmpty ? null : remark,
        masterId: masterId,
        assignments: assignments,
        rejectedPieces: rejectedPieces.isEmpty ? null : rejectedPieces,
      );

      if (!mounted) return;

      FocusScope.of(context).unfocus();

      setState(() {
        _lastProductionResult = result;
        _bundleDetails = null;
        _bundleError = null;
        if (_isLotAssignmentStage) {
          _clearLotPreviewState();
        }
      });
      _productionCodeCtrl.clear();
      _productionRemarkCtrl.clear();
      _rejectedPiecesCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Entry submitted for $stage.')),
      );

      await _loadProductionEntries();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _submittingProduction = false);
      }
    }
  }

  Future<void> _lookupBundleDetails() async {
    if (!_stageRequiresBundle) return;
    final code = _productionCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a bundle code to look up.')),
      );
      return;
    }

    setState(() {
      _loadingBundleDetails = true;
      _bundleError = null;
    });
    try {
      final bundle = await widget.api.fetchBundleSummary(code);
      if (!mounted) return;
      setState(() {
        _bundleDetails = bundle;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _bundleError = e.message;
        _bundleDetails = null;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingBundleDetails = false);
      }
    }
  }

  Future<void> _loadLotPreview({bool refresh = false}) async {
    if (!_isLotAssignmentStage) {
      return;
    }

    final code = _productionCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a lot number to continue.')),
      );
      return;
    }

    if (!refresh &&
        _lotPreview != null &&
        _lotPreview!.lotNumber.toUpperCase() == code) {
      return;
    }

    setState(() {
      _loadingLotPreview = true;
      if (!refresh) {
        _lotPreviewError = null;
      }
    });

    try {
      final preview = await widget.api.fetchProductionLotPreview(code);
      if (!mounted) return;
      setState(() {
        final previousSelections = Map<int, int?>.from(_lotSizeMasters);
        _lotPreview = preview;
        _lotPreviewError = null;
        _lotSizeMasters.clear();
        final validMasterIds = _masters.map((m) => m.id).toSet();
        final defaultMasterId = _lotBulkMasterId ??
            (previousSelections.isEmpty && _masters.length == 1
                ? _masters.first.id
                : null);
        for (final size in preview.sizes) {
          if (size.pendingBundles <= 0) {
            continue;
          }
          final previous = previousSelections[size.sizeId];
          if (previous != null && validMasterIds.contains(previous)) {
            _lotSizeMasters[size.sizeId] = previous;
          } else if (defaultMasterId != null) {
            _lotSizeMasters[size.sizeId] = defaultMasterId;
          } else {
            _lotSizeMasters[size.sizeId] = null;
          }
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _lotPreviewError = e.message;
        _lotPreview = null;
        _lotSizeMasters.clear();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingLotPreview = false);
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
    if (_isCuttingMaster) {
      return _buildCuttingMasterWorkspace(context);
    }

    if (_isProductionStageUser) {
      return _buildProductionWorkspace(context);
    }

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

  Widget _buildCuttingMasterWorkspace(BuildContext context) {
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

  Widget _buildProductionWorkspace(BuildContext context) {
    final tabLabels = <String>['Production flow', 'Reports'];
    final tabViews = <Widget>[
      _buildProductionFlowTab(context),
      _buildProductionReportTab(context),
    ];
    if (_canManageMasters) {
      tabLabels.add('Masters');
      tabViews.add(_buildMastersTab(context));
    }

    final actions = <Widget>[
      IconButton(
        tooltip: 'Reload',
        icon: const Icon(Icons.refresh),
        onPressed: () {
          _loadProductionEntries();
          if (_isLotAssignmentStage && _lotPreview != null) {
            _loadLotPreview(refresh: true);
          }
          if (_canManageMasters || _stageRequiresMaster) {
            _loadMasters();
          }
        },
      ),
      IconButton(
        tooltip: 'Logout',
        icon: const Icon(Icons.logout),
        onPressed: _logout,
      ),
    ];

    if (tabLabels.length == 1) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Aurora Production'),
          actions: actions,
        ),
        body: tabViews.first,
      );
    }

    return DefaultTabController(
      length: tabLabels.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aurora Production'),
          actions: actions,
          bottom: TabBar(
            tabs: [for (final label in tabLabels) Tab(text: label)],
          ),
        ),
        body: TabBarView(children: tabViews),
      ),
    );
  }

  Widget _buildProductionFlowTab(BuildContext context) {
    final stage = _productionStage;
    if (stage == null) {
      return const Center(child: Text('No production stage assigned.'));
    }

    final children = <Widget>[
      _buildProductionIntroCard(context, stage),
      const SizedBox(height: 16),
      _buildProductionFormCard(context, stage),
    ];

    if (_lastProductionResult != null) {
      children.addAll([
        const SizedBox(height: 16),
        _buildProductionResultCard(context),
      ]);
    }

    if (_isLotAssignmentStage) {
      children.addAll([
        const SizedBox(height: 16),
        _buildLotPreviewCard(context),
      ]);
    }

    children.add(const SizedBox(height: 32));

    return RefreshIndicator(
      onRefresh: () async {
        if (_isLotAssignmentStage && _lotPreview != null) {
          await _loadLotPreview(refresh: true);
        }
        if (_stageRequiresMaster) {
          await _loadMasters();
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: children,
      ),
    );
  }

  Widget _buildProductionReportTab(BuildContext context) {
    if (_loadingProductionEntries && _productionEntries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_productionEntriesError != null && _productionEntries.isEmpty) {
      return _ErrorState(
        message: _productionEntriesError!,
        onRetry: _loadProductionEntries,
      );
    }

    final stage = _productionStage;
    if (stage == null) {
      return const Center(child: Text('No production stage assigned.'));
    }

    final theme = Theme.of(context);
    final totalEntries = _productionEntries.length;
    final totalOpen = _productionEntries.where((entry) => !entry.isClosed).length;
    final totalClosed = totalEntries - totalOpen;

    final summary = <String, dynamic>{
      'Entries': totalEntries,
      'Open': totalOpen,
      'Closed': totalClosed,
    };

    final List<Widget> groups = [];
    if (_productionEntries.isEmpty) {
      groups.add(
        Text(
          'No submissions yet for ${_prettyStageName(stage)}.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    } else if (_stageRequiresMaster) {
      final grouped = <String, List<ProductionFlowEntry>>{};
      for (final entry in _productionEntries) {
        final label = (entry.masterName != null && entry.masterName!.trim().isNotEmpty)
            ? entry.masterName!.trim()
            : 'Unassigned';
        grouped.putIfAbsent(label, () => []).add(entry);
      }

      final sorted = grouped.entries.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
      for (final entry in sorted) {
        final masterName = entry.key;
        final items = entry.value;
        final open = items.where((item) => !item.isClosed).length;
        final closed = items.length - open;
        groups.add(
          ExpansionTile(
            title: Text(masterName),
            subtitle: Text('Open: $open • Closed: $closed • Total: ${items.length}'),
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) =>
                    _buildProductionEntryTile(context, items[index]),
                separatorBuilder: (_, __) => const Divider(height: 20),
                itemCount: items.length,
              ),
            ],
          ),
        );
      }
    } else {
      final grouped = <String, List<ProductionFlowEntry>>{};
      for (final entry in _productionEntries) {
        final label = (entry.lotNumber != null && entry.lotNumber!.trim().isNotEmpty)
            ? entry.lotNumber!.trim()
            : 'Lot not set';
        grouped.putIfAbsent(label, () => []).add(entry);
      }

      final sorted = grouped.entries.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
      for (final entry in sorted) {
        final lotLabel = entry.key;
        final items = entry.value;
        final open = items.where((item) => !item.isClosed).length;
        final closed = items.length - open;
        groups.add(
          ExpansionTile(
            title: Text(lotLabel),
            subtitle: Text('Open: $open • Closed: $closed • Total: ${items.length}'),
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) =>
                    _buildProductionEntryTile(context, items[index]),
                separatorBuilder: (_, __) => const Divider(height: 20),
                itemCount: items.length,
              ),
            ],
          ),
        );
      }
    }

    final summaryCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${_prettyStageName(stage)} report',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Download CSV'),
                  onPressed:
                      _productionEntries.isEmpty ? null : _downloadProductionReportCsv,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _buildDataChips(summary),
            ),
          ],
        ),
      ),
    );

    return RefreshIndicator(
      onRefresh: () async {
        await _loadProductionEntries();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          summaryCard,
          const SizedBox(height: 16),
          ...groups,
          const SizedBox(height: 16),
          _buildProductionEntriesCard(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProductionIntroCard(BuildContext context, String stage) {
    final theme = Theme.of(context);
    final stageName = _prettyStageName(stage);
    final instruction = _stageInstruction(stage);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stageName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              instruction,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionFormCard(BuildContext context, String stage) {
    final theme = Theme.of(context);
    final requiresMaster = _stageRequiresMaster;
    bool canSubmit = !_submittingProduction;
    if (requiresMaster) {
      if (_isLotAssignmentStage) {
        canSubmit = canSubmit &&
            _masters.isNotEmpty &&
            _lotPreview != null &&
            _hasLotAssignmentSelection;
      } else {
        canSubmit = canSubmit &&
            _selectedMasterId != null &&
            _masters.isNotEmpty;
      }
    }
    final showLotLoader = _isLotAssignmentStage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submit ${_productionCodeLabel.toLowerCase()}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _productionCodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: _productionCodeLabel,
                prefixIcon: const Icon(Icons.qr_code_2),
                helperText: 'Stage: ${_prettyStageName(stage)}',
              ),
              onSubmitted: (_) => _submitProductionEntry(),
            ),
            if (requiresMaster && !_isLotAssignmentStage) ...[
              const SizedBox(height: 12),
              _buildMasterSelectionField(theme),
            ],
            if (requiresMaster && _isLotAssignmentStage) ...[
              const SizedBox(height: 12),
              Text(
                'Load the lot to assign masters per size below.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_stageAllowsRejections) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _rejectedPiecesCtrl,
                textCapitalization: TextCapitalization.characters,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Rejected piece codes (optional)',
                  alignLabelWithHint: true,
                  helperText:
                      'Separate multiple codes with commas or new lines.',
                  prefixIcon: Icon(Icons.report_problem_outlined),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _productionRemarkCtrl,
              maxLines: 2,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Remark (optional)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  icon: _submittingProduction
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_add_check),
                  label: Text(
                    _submittingProduction ? 'Submitting…' : 'Submit entry',
                  ),
                  onPressed: canSubmit ? _submitProductionEntry : null,
                ),
                if (showLotLoader) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: _loadingLotPreview
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.assignment_ind_outlined),
                    label: const Text('Load lot details'),
                    onPressed: _loadingLotPreview ? null : () => _loadLotPreview(),
                  ),
                ] else if (_stageRequiresBundle) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: _loadingBundleDetails
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Lookup bundle'),
                    onPressed:
                        _loadingBundleDetails ? null : _lookupBundleDetails,
                  ),
                ],
              ],
            ),
            if (_lotPreviewError != null && showLotLoader) ...[
              const SizedBox(height: 12),
              Text(
                _lotPreviewError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (_bundleError != null && _stageRequiresBundle) ...[
              const SizedBox(height: 12),
              Text(
                _bundleError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (_bundleDetails != null && _stageRequiresBundle) ...[
              const SizedBox(height: 12),
              _buildBundleSummary(theme, _bundleDetails!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMasterSelectionField(ThemeData theme) {
    if (_loadingMasters && _masters.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<Widget> errorWidgets = [];
    if (_mastersError != null) {
      errorWidgets.addAll([
        Text(
          _mastersError!,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          onPressed: _loadMasters,
        ),
      ]);
    }

    if (_masters.isEmpty) {
      if (errorWidgets.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errorWidgets,
        );
      }
      final text = _canManageMasters
          ? 'Create a master from the Masters tab before submitting.'
          : 'No masters found. Contact your supervisor to set up masters for your account.';
      return Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final dropdown = DropdownButtonFormField<int>(
      value: _selectedMasterId,
      items: [
        for (final master in _masters)
          DropdownMenuItem<int>(
            value: master.id,
            child: Text(master.masterName),
          ),
      ],
      decoration: const InputDecoration(
        labelText: 'Select master',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      onChanged: _loadingMasters
          ? null
          : (value) {
              if (!mounted) return;
              setState(() => _selectedMasterId = value);
            },
    );

    if (errorWidgets.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...errorWidgets,
          const SizedBox(height: 12),
          dropdown,
        ],
      );
    }

    return dropdown;
  }

  Widget _buildBundleSummary(ThemeData theme, Map<String, dynamic> bundle) {
    final details = <String, dynamic>{
      'Lot number': bundle['lotNumber'] ?? bundle['lot_number'],
      'Bundle code': bundle['bundleCode'] ?? bundle['bundle_code'],
      'Pieces in bundle': bundle['piecesInBundle'] ?? bundle['pieces_in_bundle'],
      'Piece records': bundle['pieceCount'] ?? bundle['piece_count'],
      'Fabric': bundle['fabricType'] ?? bundle['fabric_type'],
      'SKU': bundle['sku'],
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bundle details',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _buildDataChips(details),
          ),
        ],
      ),
    );
  }

  Widget _buildLotPreviewCard(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingLotPreview && _lotPreview == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(height: 12),
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading lot details…'),
            ],
          ),
        ),
      );
    }

    final preview = _lotPreview;
    if (preview == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lot assignment overview',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a lot number and choose “Load lot details” to review sizes and assign masters.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final summary = <String, dynamic>{
      'Lot number': preview.lotNumber,
      if (preview.totalPieces != null) 'Total pieces': preview.totalPieces,
      'Total bundles': preview.totalBundles,
      'Assigned bundles': preview.assignedBundles,
      'Open bundles': preview.openBundles,
      'Closed bundles': preview.closedBundles,
    };

    final pendingSizes =
        preview.sizes.where((size) => size.pendingBundles > 0).toList();
    final missingAssignments = pendingSizes
        .where((size) => _lotSizeMasters[size.sizeId] == null)
        .length;
    final canBulkAssign = pendingSizes.isNotEmpty && _masters.isNotEmpty;

    Widget? bulkAssignControls;
    if (canBulkAssign) {
      bulkAssignControls = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _lotBulkMasterId,
                  decoration: const InputDecoration(
                    labelText: 'Assign master to all pending sizes',
                    prefixIcon: Icon(Icons.group_add_outlined),
                  ),
                  items: [
                    for (final master in _masters)
                      DropdownMenuItem<int>(
                        value: master.id,
                        child: Text(master.masterName),
                      ),
                  ],
                  onChanged: _loadingMasters
                      ? null
                      : (value) {
                          if (!mounted) return;
                          setState(() {
                            _lotBulkMasterId = value;
                          });
                        },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Apply to all'),
                onPressed: (_lotBulkMasterId != null && !_loadingMasters)
                    ? _applyMasterToAllPendingMasters
                    : null,
              ),
            ],
          ),
          if (_lotBulkMasterId == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Choose a master to quickly assign every pending size.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lot assignment overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _buildDataChips(summary),
            ),
            if (pendingSizes.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'All bundles for this lot are already submitted.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              if (bulkAssignControls != null) ...[
                bulkAssignControls,
                const SizedBox(height: 16),
              ],
              for (final size in preview.sizes) ...[
                _buildLotSizeTile(theme, size),
                const SizedBox(height: 12),
              ],
              if (missingAssignments > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Assign a master to each pending size to enable submission.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLotSizeTile(ThemeData theme, ProductionLotSize size) {
    final canAssign = size.pendingBundles > 0;
    final selectedMasterId = _lotSizeMasters[size.sizeId];
    final assignedNames = <String>{};
    for (final bundle in size.bundles) {
      if (!bundle.assigned) continue;
      final master = bundle.masterName?.trim();
      if (master != null && master.isNotEmpty) {
        assignedNames.add(master);
      }
    }

    final chips = <String, dynamic>{
      if (size.patternCount != null) 'Patterns': size.patternCount,
      'Bundles': size.totalBundles,
      'Pending': size.pendingBundles,
      'Assigned': size.assignedBundles,
      'Open': size.openBundles,
      'Closed': size.closedBundles,
      if (size.totalPieces != null) 'Pieces': size.totalPieces,
    };

    Widget? assignmentControl;
    if (canAssign) {
      if (_masters.isEmpty && !_loadingMasters) {
        assignmentControl = Text(
          'No masters available. Create or refresh the master list first.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        );
      } else {
        assignmentControl = Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: selectedMasterId,
                items: [
                  for (final master in _masters)
                    DropdownMenuItem<int>(
                      value: master.id,
                      child: Text(master.masterName),
                    ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Assign master',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                onChanged: _loadingMasters
                    ? null
                    : (value) {
                        if (!mounted) return;
                        setState(() {
                          _lotSizeMasters[size.sizeId] = value;
                        });
                      },
              ),
            ),
            if (selectedMasterId != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  if (!mounted) return;
                  setState(() {
                    _lotSizeMasters[size.sizeId] = null;
                  });
                },
                child: const Text('Clear'),
              ),
            ],
          ],
        );
      }
    }

    final assignedSummary = size.assignedBundles == 0
        ? 'Not yet assigned.'
        : 'Assigned bundles: ${size.assignedBundles} '
            '(${size.openBundles} open, ${size.closedBundles} closed)';

    final masterSummary = assignedNames.isEmpty
        ? null
        : 'Masters: ${assignedNames.join(', ')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Size ${size.sizeLabel.isEmpty ? '—' : size.sizeLabel}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _buildDataChips(chips),
          ),
          const SizedBox(height: 12),
          Text(
            assignedSummary,
            style: theme.textTheme.bodyMedium,
          ),
          if (masterSummary != null) ...[
            const SizedBox(height: 6),
            Text(
              masterSummary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (assignmentControl != null) ...[
            const SizedBox(height: 12),
            assignmentControl,
            if (selectedMasterId == null && canAssign && _masters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Select a master before submitting this lot.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ] else if (!canAssign) ...[
            const SizedBox(height: 12),
            Text(
              'All bundles for this size have been submitted.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductionResultCard(BuildContext context) {
    final result = _lastProductionResult;
    if (result == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final stageLabel = _prettyStageName(
      (result['stage'] ?? _productionStage ?? '').toString(),
    );
    final message = result['message']?.toString();
    final bool success = result['success'] == true ||
        (result['status'] == 200 || result['status'] == 201);
    Map<String, dynamic>? data;
    if (result['data'] is Map) {
      data = Map<String, dynamic>.from(result['data'] as Map);
    }

    return Card(
      color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Latest submission',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text(success ? 'Success' : 'Completed'),
                  backgroundColor:
                      theme.colorScheme.onSecondaryContainer.withOpacity(0.08),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Stage: $stageLabel',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            if (message != null && message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
            if (data != null && data.isNotEmpty)
              ...[const SizedBox(height: 12), ..._buildResultDetailWidgets(theme, data)],
          ],
        ),
      ),
    );
  }

  Widget _buildProductionEntriesCard(BuildContext context) {
    if (_loadingProductionEntries && _productionEntries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_productionEntriesError != null && _productionEntries.isEmpty) {
      return _ErrorState(
        message: _productionEntriesError!,
        onRetry: _loadProductionEntries,
      );
    }

    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent entries',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingProductionEntries && _productionEntries.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_productionEntries.isEmpty)
              Text(
                'No submissions yet for ${_productionStage != null && _productionStage!.isNotEmpty ? _prettyStageName(_productionStage!) : 'this stage'}.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final entry = _productionEntries[index];
                  return _buildProductionEntryTile(context, entry);
                },
                separatorBuilder: (_, __) => const Divider(height: 20),
                itemCount: _productionEntries.length,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionEntryTile(
    BuildContext context,
    ProductionFlowEntry entry,
  ) {
    final theme = Theme.of(context);
    final detailParts = <String>[];
    if (entry.lotNumber != null && entry.lotNumber!.isNotEmpty) {
      detailParts.add('Lot ${entry.lotNumber}');
    }
    if (entry.sizeLabel != null && entry.sizeLabel!.isNotEmpty) {
      detailParts.add('Size ${entry.sizeLabel}');
    }
    if (entry.bundleCode != null && entry.bundleCode!.isNotEmpty) {
      detailParts.add('Bundle ${entry.bundleCode}');
    }
    if (entry.pieceCode != null && entry.pieceCode!.isNotEmpty) {
      detailParts.add('Piece ${entry.pieceCode}');
    }
    final detailText = detailParts.join(' • ');

    final userParts = <String>[];
    if (entry.userUsername != null && entry.userUsername!.isNotEmpty) {
      userParts.add(entry.userUsername!);
    }
    if (entry.userRole != null && entry.userRole!.isNotEmpty) {
      userParts.add(entry.userRole!);
    }
    final userText = userParts.isEmpty ? 'Unknown user' : userParts.join(' • ');
    final timestamp = _formatDateTime(entry.createdAt);
    final remark = entry.remark?.trim();

    final statusChip = Chip(
      label: Text(entry.isClosed ? 'Closed' : 'Open'),
      backgroundColor: entry.isClosed
          ? theme.colorScheme.primary.withOpacity(0.12)
          : theme.colorScheme.secondaryContainer.withOpacity(0.6),
    );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
        child: Text(
          entry.stage.isNotEmpty ? entry.stage[0].toUpperCase() : '?',
          style: theme.textTheme.titleMedium,
        ),
      ),
      title: Text(
        entry.codeValue,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detailText.isNotEmpty)
            Text(
              detailText,
              style: theme.textTheme.bodyMedium,
            ),
          Text(
            '$userText • $timestamp',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (remark != null && remark.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Note: $remark',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              statusChip,
              if (entry.piecesTotal != null)
                Chip(label: Text('${entry.piecesTotal} pcs')),
            ],
          ),
        ],
      ),
      trailing: entry.createdAt != null
          ? Text(
              _formatTime(entry.createdAt!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }

  Future<void> _downloadProductionReportCsv() async {
    if (_productionEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to download.')),
      );
      return;
    }

    final stage = _productionStage ?? 'stage';
    final buffer = StringBuffer();
    buffer.writeln(
        'Group,Code,Lot,Size,Bundle,Piece,Status,Closed,Master,Created At,Closed At,User');

    for (final entry in _productionEntries) {
      final group = _stageRequiresMaster
          ? (entry.masterName?.trim().isNotEmpty == true
              ? entry.masterName!.trim()
              : 'Unassigned')
          : (entry.lotNumber?.trim().isNotEmpty == true
              ? entry.lotNumber!.trim()
              : 'Lot not set');
      final row = [
        group,
        entry.codeValue,
        entry.lotNumber ?? '',
        entry.sizeLabel ?? '',
        entry.bundleCode ?? '',
        entry.pieceCode ?? '',
        entry.eventStatus ?? (entry.isClosed ? 'closed' : 'open'),
        entry.isClosed ? 'Yes' : 'No',
        entry.masterName ?? '',
        entry.createdAt != null ? _formatDateTime(entry.createdAt!) : '',
        entry.closedAt != null ? _formatDateTime(entry.closedAt!) : '',
        entry.userUsername ?? '',
      ].map(_csvEscape).join(',');
      buffer.writeln(row);
    }

    final filename =
        'production-${stage.replaceAll(' ', '-').toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}.csv';
    final saved = await saveCsvToDevice(filename, buffer.toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'Report downloaded as $filename.'
            : 'CSV ready. Copy from clipboard if automatic download is unavailable.'),
      ),
    );
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  Widget _buildMastersTab(BuildContext context) {
    Widget listSection;
    if (_loadingMasters && _masters.isEmpty) {
      listSection = const Center(child: CircularProgressIndicator());
    } else if (_mastersError != null && _masters.isEmpty) {
      listSection = _ErrorState(
        message: _mastersError!,
        onRetry: _loadMasters,
      );
    } else {
      listSection = _buildMastersListCard(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadMasters();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildMastersFormCard(context),
          const SizedBox(height: 16),
          listSection,
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMastersFormCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _masterFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create master',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _masterNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Master name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter master name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _masterContactCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _masterNotesCtrl,
                maxLines: 2,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: _creatingMaster
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt),
                  label: Text(
                    _creatingMaster ? 'Saving…' : 'Save master',
                  ),
                  onPressed: _creatingMaster ? null : _createMasterRecord,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMastersListCard(BuildContext context) {
    final theme = Theme.of(context);
    if (_masters.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No masters created yet. Use the form above to add your first master.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your masters',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final master = _masters[index];
                final roleLabel = master.creatorRole != null
                    ? _prettyStageName(master.creatorRole!.toLowerCase())
                    : null;
                final createdLabel = _formatDateTime(master.createdAt);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(
                    master.masterName,
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (master.contactNumber != null &&
                          master.contactNumber!.isNotEmpty)
                        Text(master.contactNumber!),
                      if (master.notes != null && master.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(master.notes!),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Created $createdLabel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: roleLabel != null && roleLabel.isNotEmpty
                      ? Chip(label: Text(roleLabel))
                      : null,
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemCount: _masters.length,
            ),
          ],
        ),
      ),
    );
  }

  String _prettyStageName(String stage) {
    if (stage.isEmpty) return '';
    final parts = stage.split(RegExp(r'[_\s]+')).where((part) => part.isNotEmpty);
    return parts
        .map((part) => part.substring(0, 1).toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _stageInstruction(String stage) {
    switch (stage) {
      case 'back_pocket':
        return 'Enter the lot number once all sizes are ready so every bundle moves to back pocket.';
      case 'stitching_master':
        return 'Submit the lot number after stitching is complete to release every bundle to the next stage.';
      case 'jeans_assembly':
        return 'Submit the bundle code after both back pocket and stitching teams finish, or log any rejected piece codes.';
      case 'washing':
        return 'Enter the lot number to register all pieces leaving jeans assembly for washing.';
      case 'washing_in':
        return 'Scan the piece code when it returns from washing, or record rejects that cannot continue.';
      case 'finishing':
        return 'Submit the bundle code after confirming every piece has passed washing in.';
      default:
        return 'Submit the production code assigned to your station to update the flow.';
    }
  }

  List<Widget> _buildResultDetailWidgets(
    ThemeData theme,
    Map<String, dynamic> data,
  ) {
    final remaining = <String, dynamic>{};
    data.forEach((key, value) {
      if (value != null) {
        remaining[key.toString()] = value;
      }
    });

    dynamic assignments = remaining.remove('assignments');
    assignments ??= remaining.remove('sizeAssignments');
    assignments ??= remaining.remove('assignmentSummary');
    if (assignments is Map) {
      assignments = assignments.values;
    }

    dynamic rejected = remaining.remove('rejectedPieces');
    rejected ??= remaining.remove('rejected_piece_codes');
    rejected ??= remaining.remove('rejectPieces');
    if (rejected is Map) {
      rejected = rejected.values;
    }

    final widgets = <Widget>[];

    if (remaining.isNotEmpty) {
      widgets.add(
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: _buildDataChips(remaining),
        ),
      );
    }

    final assignmentLabels = <String>[];
    if (assignments is Iterable) {
      for (final item in assignments) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item as Map);
          final sizeLabel =
              (map['sizeLabel'] ?? map['size_label'] ?? '').toString().trim();
          final sizeId = map['sizeId'] ?? map['size_id'];
          final bundlesRaw = map['bundles'] ??
              map['bundleCount'] ??
              map['bundle_count'];
          final masterName =
              (map['masterName'] ?? map['master_name'] ?? '').toString().trim();

          final parts = <String>[];
          if (sizeLabel.isNotEmpty) {
            parts.add(sizeLabel);
          } else if (sizeId != null) {
            parts.add('Size $sizeId');
          }

          if (bundlesRaw != null) {
            final bundleText = bundlesRaw.toString();
            if (bundleText.isNotEmpty) {
              final parsed = int.tryParse(bundleText);
              final bundleLabel = parsed == 1
                  ? '1 bundle'
                  : '$bundleText bundles';
              parts.add(bundleLabel);
            }
          }

          if (masterName.isNotEmpty) {
            parts.add('Master $masterName');
          }

          if (parts.isNotEmpty) {
            assignmentLabels.add(parts.join(' • '));
          }
        } else if (item != null) {
          final value = item.toString().trim();
          if (value.isNotEmpty) {
            assignmentLabels.add(value);
          }
        }
      }
    }

    if (assignmentLabels.isNotEmpty) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 12));
      }
      widgets.add(
        Text(
          'Assignments',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final label in assignmentLabels) Chip(label: Text(label)),
          ],
        ),
      );
    }

    final rejectedLabels = <String>[];
    if (rejected is Iterable) {
      final seen = <String>{};
      for (final item in rejected) {
        if (item == null) continue;
        final value = item.toString().trim();
        if (value.isEmpty) continue;
        final normalized = value.toUpperCase();
        if (seen.add(normalized)) {
          rejectedLabels.add(normalized);
        }
      }
    }

    if (rejectedLabels.isNotEmpty) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 12));
      }
      widgets.add(
        Text(
          'Rejected pieces',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final code in rejectedLabels) Chip(label: Text(code)),
          ],
        ),
      );
    }

    if (widgets.isEmpty) {
      widgets.add(
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: _buildDataChips(data),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildDataChips(Map<String, dynamic> data) {
    final chips = <Widget>[];
    data.forEach((key, value) {
      if (value == null) return;
      final formatted = _formatDataValue(value);
      if (formatted.isEmpty) return;
      chips.add(Chip(label: Text('${_humanizeKey(key)}: $formatted')));
    });
    if (chips.isEmpty) {
      chips.add(const Chip(label: Text('No details provided')));
    }
    return chips;
  }

  String _formatDataValue(dynamic value) {
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num) {
      if (value is double && value.toStringAsFixed(1).endsWith('.0')) {
        return value.toStringAsFixed(0);
      }
      return value.toString();
    }
    return value.toString();
  }

  String _humanizeKey(String key) {
    if (key.isEmpty) return '';
    final parts = key.split(RegExp(r'[_\s]+')).where((part) => part.isNotEmpty);
    return parts
        .map((part) => part.substring(0, 1).toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month $year • $hour:$minute';
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

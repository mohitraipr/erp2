import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/login_response.dart';
import '../models/production_flow.dart';
import '../models/production_lot.dart';
import '../models/production_master.dart';
import '../services/api_service.dart';

class ProductionFlowPage extends StatefulWidget {
  final LoginResponse data;
  final ApiService api;
  final VoidCallback onLogout;

  const ProductionFlowPage({
    super.key,
    required this.data,
    required this.api,
    required this.onLogout,
  });

  @override
  State<ProductionFlowPage> createState() => _ProductionFlowPageState();
}

enum ProductionStage {
  backPocket(
    role: 'back_pocket',
    displayName: 'Back pocket',
    codeLabel: 'Lot number',
    codeHint: 'Enter the lot number to load sizes and bundles',
    description:
        'Assign bundles from a cutting lot to your masters. Load the lot to view '
        'size-wise bundles and make sure every bundle has a master before submitting.',
    requiresMaster: true,
    requiresLotDetails: true,
    allowsRejection: false,
  ),
  stitchingMaster(
    role: 'stitching_master',
    displayName: 'Stitching master',
    codeLabel: 'Lot number',
    codeHint: 'Enter the lot number to distribute bundles to masters',
    description:
        'Distribute bundles to stitching masters. Each bundle must be assigned to '
        'a master before you submit the lot.',
    requiresMaster: true,
    requiresLotDetails: true,
    allowsRejection: false,
  ),
  jeansAssembly(
    role: 'jeans_assembly',
    displayName: 'Jeans assembly',
    codeLabel: 'Bundle code',
    codeHint: 'Scan or enter the bundle code to close stitching stages',
    description:
        'Record bundle movement from stitching to jeans assembly. Submit bundle '
        'codes to close stitching stages and optionally record rejected piece codes.',
    requiresMaster: false,
    requiresLotDetails: false,
    allowsRejection: true,
  ),
  washing(
    role: 'washing',
    displayName: 'Washing',
    codeLabel: 'Lot number',
    codeHint: 'Enter the lot number to close open jeans assembly pieces',
    description:
        'Close jeans assembly pieces for washing. Submit the lot number as many '
        'times as required until all pieces are moved to washing.',
    requiresMaster: false,
    requiresLotDetails: false,
    allowsRejection: false,
  ),
  washingIn(
    role: 'washing_in',
    displayName: 'Washing in',
    codeLabel: 'Piece code',
    codeHint: 'Scan piece codes as they enter washing in',
    description:
        'Record pieces as they enter washing in. You can also reject pieces to '
        'mark them as failed after washing.',
    requiresMaster: false,
    requiresLotDetails: false,
    allowsRejection: true,
  ),
  finishing(
    role: 'finishing',
    displayName: 'Finishing',
    codeLabel: 'Bundle code',
    codeHint: 'Enter bundle code once all washing in pieces are complete',
    description:
        'Close bundles after washing in is completed. Use this form to submit '
        'bundle codes and optionally register rejected pieces.',
    requiresMaster: false,
    requiresLotDetails: false,
    allowsRejection: true,
  );

  const ProductionStage({
    required this.role,
    required this.displayName,
    required this.codeLabel,
    required this.codeHint,
    required this.description,
    required this.requiresMaster,
    required this.requiresLotDetails,
    required this.allowsRejection,
  });

  final String role;
  final String displayName;
  final String codeLabel;
  final String codeHint;
  final String description;
  final bool requiresMaster;
  final bool requiresLotDetails;
  final bool allowsRejection;

  static ProductionStage? fromRole(String normalizedRole) {
    for (final stage in ProductionStage.values) {
      if (stage.role == normalizedRole) {
        return stage;
      }
    }
    return null;
  }

  String get submitLabel => switch (this) {
        ProductionStage.backPocket => 'Submit assignments',
        ProductionStage.stitchingMaster => 'Submit assignments',
        ProductionStage.jeansAssembly => 'Submit entry',
        ProductionStage.washing => 'Submit lot',
        ProductionStage.washingIn => 'Submit entry',
        ProductionStage.finishing => 'Submit entry',
      };

}

class _AssignmentKey {
  final int sizeId;
  final int masterId;

  const _AssignmentKey(this.sizeId, this.masterId);

  @override
  bool operator ==(Object other) {
    return other is _AssignmentKey &&
        other.sizeId == sizeId &&
        other.masterId == masterId;
  }

  @override
  int get hashCode => Object.hash(sizeId, masterId);
}

class _ProductionFlowPageState extends State<ProductionFlowPage> {
  late final ProductionStage? _stage =
      ProductionStage.fromRole(widget.data.normalizedRole);

  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  final TextEditingController _rejectionsCtrl = TextEditingController();

  bool _loadingMasters = false;
  bool _loadingLot = false;
  bool _submitting = false;
  bool _loadingHistory = false;

  String? _masterError;
  String? _lotError;
  String? _submitError;
  String? _historyError;
  String? _historyLotFilter;

  List<ProductionMaster> _masters = [];
  ProductionLotDetails? _lot;
  ProductionFlowSubmissionResult? _result;
  List<ProductionFlowEntry> _history = [];

  final Map<int, int?> _bundleAssignments = <int, int?>{};

  @override
  void initState() {
    super.initState();
    if (_stage?.requiresMaster ?? false) {
      _loadMasters();
    }
    Future.microtask(_loadHistory);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _remarkCtrl.dispose();
    _rejectionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() {
      _loadingMasters = true;
      _masterError = null;
    });
    try {
      final masters = await widget.api.fetchProductionMasters();
      masters.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _masters = masters;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _masterError = e.message);
    } finally {
      if (mounted) {
        setState(() => _loadingMasters = false);
      }
    }
  }

  Future<void> _loadLot({String? lotNumber}) async {
    final stage = _stage;
    if (stage == null || !stage.requiresLotDetails) return;

    final input = (lotNumber ?? _codeCtrl.text).trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a lot number to continue.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loadingLot = true;
      _lotError = null;
      _lot = null;
      _bundleAssignments.clear();
      _result = null;
    });

    try {
      final lot = await widget.api.fetchProductionLot(input);
      if (!mounted) return;

      if (lot.sizes.isEmpty) {
        setState(() {
          _lotError = 'No sizes were generated for lot ${lot.lotNumber}.';
          _lot = null;
        });
        return;
      }

      final hasBundles = lot.sizes.any((size) => size.bundles.isNotEmpty);
      if (!hasBundles) {
        setState(() {
          _lotError = 'No bundles were found for lot ${lot.lotNumber}.';
          _lot = null;
        });
        return;
      }

      setState(() {
        _lot = lot;
        _codeCtrl.text = lot.lotNumber;
        _bundleAssignments.clear();
        for (final size in lot.sizes) {
          for (final bundle in size.bundles) {
            _bundleAssignments[bundle.bundleId] = null;
          }
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _lotError = e.message;
        _lot = null;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingLot = false);
      }
    }
  }

  Future<void> _reloadCurrentLot() async {
    final lot = _lot;
    if (lot == null) return;
    await _loadLot(lotNumber: lot.lotNumber);
  }

  Future<void> _loadHistory() async {
    final stage = _stage;
    if (stage == null) return;

    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      final entries = await widget.api.fetchProductionFlowEntries(stage: stage.role);
      if (!mounted) return;

      final lots = LinkedHashSet<String>.from(
        entries.where((e) => (e.lotNumber ?? '').isNotEmpty).map((e) => e.lotNumber!),
      );

      setState(() {
        _history = entries;
        if (_historyLotFilter != null && !lots.contains(_historyLotFilter)) {
          _historyLotFilter = null;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.message;
        _history = const [];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  void _applyMasterToSize(int sizeId, int? masterId) {
    final lot = _lot;
    if (lot == null) return;
    for (final size in lot.sizes) {
      if (size.sizeId != sizeId) continue;
      for (final bundle in size.bundles) {
        _bundleAssignments[bundle.bundleId] = masterId;
      }
      break;
    }
    setState(() {});
  }

  ProductionMaster? _findMaster(int? masterId) {
    if (masterId == null) return null;
    for (final master in _masters) {
      if (master.id == masterId) {
        return master;
      }
    }
    return null;
  }

  int get _unassignedBundlesCount =>
      _bundleAssignments.values.where((value) => value == null).length;

  bool get _allBundlesAssigned =>
      _bundleAssignments.isNotEmpty && _unassignedBundlesCount == 0;

  List<Map<String, dynamic>> _buildAssignmentPayload() {
    final lot = _lot;
    if (lot == null) return const <Map<String, dynamic>>[];

    final Map<_AssignmentKey, List<int>> grouped = {};

    for (final size in lot.sizes) {
      for (final bundle in size.bundles) {
        final masterId = _bundleAssignments[bundle.bundleId];
        if (masterId == null) continue;
        final key = _AssignmentKey(size.sizeId, masterId);
        grouped.putIfAbsent(key, () => <int>[]).add(bundle.bundleId);
      }
    }

    final assignments = <Map<String, dynamic>>[];
    grouped.forEach((key, bundleIds) {
      final master = _findMaster(key.masterId);
      assignments.add({
        'sizeId': key.sizeId,
        'masterId': key.masterId,
        if (master != null && master.name.isNotEmpty) 'masterName': master.name,
        'bundles': bundleIds.map((id) => {'bundleId': id}).toList(),
      });
    });

    return assignments;
  }

  List<String> _parseRejectedPieces() {
    final raw = _rejectionsCtrl.text.trim();
    if (raw.isEmpty) {
      return const <String>[];
    }

    final parts = raw.split(RegExp(r'[\s,;]+'));
    final codes = <String>{};
    for (final part in parts) {
      final value = part.trim().toUpperCase();
      if (value.isNotEmpty) {
        codes.add(value);
      }
    }
    return codes.toList();
  }

  bool _codeRequired(List<String> rejections) {
    final stage = _stage;
    if (stage == null) return false;
    if (!stage.allowsRejection) {
      return true;
    }
    return rejections.isEmpty;
  }

  Future<void> _submit() async {
    final stage = _stage;
    if (stage == null) return;

    final rejections =
        stage.allowsRejection ? _parseRejectedPieces() : const <String>[];
    final code = _codeCtrl.text.trim();

    if (stage.requiresLotDetails) {
      final lot = _lot;
      if (lot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Load a lot before submitting.')),
        );
        return;
      }

      if (_bundleAssignments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No bundles available to assign.')),
        );
        return;
      }

      if (!_allBundlesAssigned) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Assign masters to all bundles. ${_unassignedBundlesCount} bundle(s) left.',
            ),
          ),
        );
        return;
      }

      FocusScope.of(context).unfocus();
      setState(() {
        _submitting = true;
        _submitError = null;
        _result = null;
      });

      try {
        final assignments = _buildAssignmentPayload();
        final remark = _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim();
        final result = await widget.api.submitProductionFlowEntry(
          code: lot.lotNumber,
          remark: remark,
          assignments: assignments,
        );

        if (!mounted) return;

        setState(() {
          _result = result;
          _lot = null;
          _bundleAssignments.clear();
          _remarkCtrl.clear();
          _rejectionsCtrl.clear();
          _codeCtrl.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${stage.displayName} submission recorded.')),
        );
        _loadHistory();
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _submitError = e.message);
      } finally {
        if (mounted) {
          setState(() => _submitting = false);
        }
      }
      return;
    }

    if (_codeRequired(rejections) && code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a ${stage.codeLabel.toLowerCase()} to continue.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _submitError = null;
      _result = null;
    });

    try {
      final remark = _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim();
      final result = await widget.api.submitProductionFlowEntry(
        code: code.isEmpty ? null : code,
        remark: remark,
        rejectedPieces: rejections.isEmpty ? null : rejections,
      );

      if (!mounted) return;

      setState(() {
        _result = result;
        _remarkCtrl.clear();
        _rejectionsCtrl.clear();
        if (rejections.isNotEmpty) {
          _codeCtrl.clear();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${stage.displayName} submission recorded.')),
      );
      _loadHistory();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitError = e.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;
    if (stage == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Production flow'),
          actions: [
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: widget.onLogout,
            ),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Your role does not have production tools assigned yet.'),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Production • ${stage.displayName}'),
          actions: [
            if (stage.requiresMaster)
              IconButton(
                tooltip: 'Refresh masters',
                icon: const Icon(Icons.groups_outlined),
                onPressed: _loadingMasters ? null : _loadMasters,
              ),
            if (stage.requiresLotDetails)
              IconButton(
                tooltip: 'Reload lot',
                icon: const Icon(Icons.refresh),
                onPressed: _loadingLot ? null : _reloadCurrentLot,
              ),
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: widget.onLogout,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Submit'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            stage.requiresLotDetails
                ? _buildLotAssignmentView(context, stage)
                : _buildSimpleStageView(context, stage),
            _buildHistoryTab(stage),
          ],
        ),
      ),
    );
  }

  Widget _buildStageIntroCard(ProductionStage stage) {
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
              stage.description,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLotAssignmentView(BuildContext context, ProductionStage stage) {
    final lot = _lot;
    final masters = _masters;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        if (stage.requiresMaster) {
          await _loadMasters();
        }
        await _reloadCurrentLot();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildStageIntroCard(stage),
          const SizedBox(height: 16),
          _buildLotCodeCard(stage),
          if (_masterError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _InfoBanner(
                icon: Icons.warning_amber_rounded,
                color: theme.colorScheme.errorContainer,
                textColor: theme.colorScheme.onErrorContainer,
                message: _masterError!,
              ),
            ),
          if (_loadingMasters && masters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loadingMasters && masters.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _InfoBanner(
                icon: Icons.info_outline,
                message: 'No masters found. Use the masters menu to create them.',
              ),
            ),
          if (masters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final master in masters)
                    Chip(
                      avatar: const Icon(Icons.person_outline),
                      label: Text(master.name),
                    ),
                ],
              ),
            ),
          if (lot != null) ...[
            const SizedBox(height: 16),
            _buildLotSummaryCard(lot, theme),
            const SizedBox(height: 16),
            if (_bundleAssignments.isNotEmpty)
              _InfoBanner(
                icon: _allBundlesAssigned
                    ? Icons.check_circle_outline
                    : Icons.assignment_late_outlined,
                message: _allBundlesAssigned
                    ? 'All bundles are assigned to masters.'
                    : 'Assigned ${_bundleAssignments.length - _unassignedBundlesCount} of ${_bundleAssignments.length} bundles.',
                color: _allBundlesAssigned
                    ? theme.colorScheme.secondaryContainer
                    : theme.colorScheme.surfaceVariant,
              ),
            const SizedBox(height: 12),
            for (final size in lot.sizes)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildSizeCard(size, masters),
              ),
          ],
          const SizedBox(height: 16),
          _buildRemarkField(),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_submitting ? 'Submitting…' : stage.submitLabel),
            onPressed: _submitting ? null : _submit,
          ),
          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _InfoBanner(
                icon: Icons.error_outline,
                color: theme.colorScheme.errorContainer,
                textColor: theme.colorScheme.onErrorContainer,
                message: _submitError!,
              ),
            ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _buildResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleStageView(BuildContext context, ProductionStage stage) {
    final theme = Theme.of(context);
    final allowsRejection = stage.allowsRejection;

    return RefreshIndicator(
      onRefresh: () async {
        // Simple stages only need to clear the status when refreshed.
        setState(() {
          _submitError = null;
          _result = null;
        });
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildStageIntroCard(stage),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _codeCtrl,
                    enabled: !_submitting,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: stage.codeLabel,
                      hintText: stage.codeHint,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (allowsRejection) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _rejectionsCtrl,
                      enabled: !_submitting,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Rejected piece codes',
                        hintText: 'Separate codes with spaces, commas, or new lines',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildRemarkField(),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_submitting ? 'Submitting…' : stage.submitLabel),
                    onPressed: _submitting ? null : _submit,
                  ),
                  if (_submitError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _InfoBanner(
                        icon: Icons.error_outline,
                        color: theme.colorScheme.errorContainer,
                        textColor: theme.colorScheme.onErrorContainer,
                        message: _submitError!,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _buildResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildLotCodeCard(ProductionStage stage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _codeCtrl,
              enabled: !_loadingLot && !_submitting,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: stage.codeLabel,
                hintText: stage.codeHint,
              ),
              onSubmitted: (_) => _loadLot(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  icon: _loadingLot
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_loadingLot ? 'Loading…' : 'Load lot details'),
                  onPressed: _loadingLot ? null : () => _loadLot(),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: (_codeCtrl.text.isEmpty && _lot == null)
                      ? null
                      : () {
                          setState(() {
                            _codeCtrl.clear();
                            _lot = null;
                            _lotError = null;
                            _bundleAssignments.clear();
                            _result = null;
                          });
                        },
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (_lotError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _InfoBanner(
                  icon: Icons.error_outline,
                  message: _lotError!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLotSummaryCard(ProductionLotDetails lot, ThemeData theme) {
    final totalBundles = lot.sizes.fold<int>(
      0,
      (sum, size) => sum + size.bundles.length,
    );
    final piecesInfo = lot.totalPieces != null ? ' • Pieces: ${lot.totalPieces}' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lot ${lot.lotNumber}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sizes: ${lot.sizes.length} • Bundles: $totalBundles$piecesInfo',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(ProductionStage stage) {
    final theme = Theme.of(context);
    final lots = LinkedHashSet<String>.from(
      _history.where((e) => (e.lotNumber ?? '').isNotEmpty).map((e) => e.lotNumber!),
    );
    final filteredEntries = _historyLotFilter == null
        ? _history
        : _history.where((entry) => entry.lotNumber == _historyLotFilter).toList();

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildStageIntroCard(stage),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Entries recorded for ${stage.displayName.toLowerCase()} stage.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (lots.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All lots'),
                          selected: _historyLotFilter == null,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _historyLotFilter = null);
                            }
                          },
                        ),
                        for (final lot in lots)
                          ChoiceChip(
                            label: Text(lot),
                            selected: _historyLotFilter == lot,
                            onSelected: (selected) {
                              setState(() {
                                _historyLotFilter = selected ? lot : null;
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                  if (_historyError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _InfoBanner(
                        icon: Icons.error_outline,
                        color: theme.colorScheme.errorContainer,
                        textColor: theme.colorScheme.onErrorContainer,
                        message: _historyError!,
                      ),
                    ),
                  if (_loadingHistory && _history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (!_loadingHistory && _historyError == null && filteredEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _InfoBanner(
                        icon: Icons.history,
                        message: _historyLotFilter == null
                            ? 'No entries recorded yet. Submissions will appear here.'
                            : 'No entries found for lot $_historyLotFilter.',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in filteredEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildHistoryEntryCard(entry),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryEntryCard(ProductionFlowEntry entry) {
    final theme = Theme.of(context);
    final stageLabel = _formatStageLabel(entry.stage);
    final statusLabel = entry.eventStatus?.isNotEmpty == true
        ? entry.eventStatus!
        : entry.isClosed
            ? 'Closed'
            : 'Open';
    final chips = <Widget>[];
    if (entry.lotNumber != null && entry.lotNumber!.isNotEmpty) {
      chips.add(_HistoryChip(label: 'Lot ${entry.lotNumber}'));
    }
    if (entry.bundleCode != null && entry.bundleCode!.isNotEmpty) {
      chips.add(_HistoryChip(label: 'Bundle ${entry.bundleCode}'));
    }
    if (entry.pieceCode != null && entry.pieceCode!.isNotEmpty) {
      chips.add(_HistoryChip(label: 'Piece ${entry.pieceCode}'));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconForCodeType(entry.codeType), color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.codeValue.isNotEmpty ? entry.codeValue : entry.codeType.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$stageLabel • ${_formatCodeType(entry.codeType)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  avatar: Icon(
                    entry.isClosed ? Icons.check_circle_outline : Icons.timelapse,
                    size: 18,
                  ),
                ),
              ],
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Created: ${_formatDateTime(entry.createdAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Closed: ${_formatDateTime(entry.closedAt)}',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForCodeType(String codeType) {
    switch (codeType.toLowerCase()) {
      case 'bundle':
        return Icons.inventory_2_outlined;
      case 'piece':
        return Icons.qr_code_2;
      case 'lot':
        return Icons.widgets_outlined;
      default:
        return Icons.receipt_long;
    }
  }

  String _formatStageLabel(String stage) {
    return stage
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _formatCodeType(String codeType) {
    if (codeType.isEmpty) return 'Code';
    return codeType[0].toUpperCase() + codeType.substring(1).toLowerCase();
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '—';
    }
    final local = value.toLocal();
    final date = '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final time = '${hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} $period';
    return '$date • $time';
  }

  Widget _buildSizeCard(ProductionLotSize size, List<ProductionMaster> masters) {
    final theme = Theme.of(context);
    final assignedCount = size.bundles
        .where((bundle) => _bundleAssignments[bundle.bundleId] != null)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Size ${size.sizeLabel}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bundles: ${size.bundles.length}'
                      '${size.patternCount != null ? ' • Patterns: ${size.patternCount}' : ''}'
                      '${size.totalPieces != null ? ' • Pieces: ${size.totalPieces}' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                Text(
                  '$assignedCount assigned',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: assignedCount == size.bundles.length
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: null,
                hint: const Text('Assign master to all bundles'),
                onChanged: (value) => _applyMasterToSize(size.sizeId, value),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Clear assignments'),
                  ),
                  for (final master in masters)
                    DropdownMenuItem<int?>(
                      value: master.id,
                      child: Text(master.name),
                    ),
                ],
              ),
            ),
            const Divider(height: 24),
            for (final bundle in size.bundles)
              Column(
                children: [
                  _buildBundleRow(bundle, masters),
                  if (bundle != size.bundles.last) const Divider(height: 16),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBundleRow(ProductionBundle bundle, List<ProductionMaster> masters) {
    final theme = Theme.of(context);
    final selectedId = _bundleAssignments[bundle.bundleId];
    final master = _findMaster(selectedId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bundle.bundleCode,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pattern ${bundle.bundleSequence ?? '-'}'
                '${bundle.piecesInBundle != null ? ' • ${bundle.piecesInBundle} pcs' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int?>(
            value: selectedId,
            decoration: const InputDecoration(
              labelText: 'Master',
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Unassigned'),
              ),
              for (final m in masters)
                DropdownMenuItem<int?>(
                  value: m.id,
                  child: Text(m.name),
                ),
            ],
            onChanged: masters.isEmpty
                ? null
                : (value) {
                    setState(() {
                      _bundleAssignments[bundle.bundleId] = value;
                    });
                  },
          ),
        ),
        if (master != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }

  Widget _buildRemarkField() {
    return TextField(
      controller: _remarkCtrl,
      enabled: !_submitting && !_loadingLot,
      decoration: const InputDecoration(
        labelText: 'Remark (optional)',
        hintText: 'Add context or notes for this submission',
      ),
    );
  }

  Widget _buildResultCard() {
    final theme = Theme.of(context);
    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Submission successful',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              result.prettyPrinted(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;
  final Color? textColor;

  const _InfoBanner({
    required this.icon,
    required this.message,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.surfaceVariant;
    final effectiveTextColor = textColor ?? theme.colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: effectiveTextColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: effectiveTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  final String label;

  const _HistoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

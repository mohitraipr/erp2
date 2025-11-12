import 'package:flutter/material.dart';

import '../../models/bundle_info.dart';
import '../../models/login_response.dart';
import '../../models/master.dart';
import '../../models/production_flow_event.dart';
import '../../models/production_flow_response.dart';
import '../../models/production_stage.dart';
import '../../services/api_service.dart';

class ProductionFlowTab extends StatefulWidget {
  final LoginResponse user;
  final ApiService api;

  const ProductionFlowTab({super.key, required this.user, required this.api});

  @override
  State<ProductionFlowTab> createState() => _ProductionFlowTabState();
}

class _ProductionFlowTabState extends State<ProductionFlowTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  final TextEditingController _rejectedCtrl = TextEditingController();

  ProductionStage? _stage;
  List<Master> _masters = [];
  Master? _selectedMaster;
  bool _mastersLoading = false;
  String? _mastersError;

  bool _submitting = false;
  String? _submitError;
  ProductionFlowSubmissionResult? _result;

  bool _historyLoading = false;
  String? _historyError;
  List<ProductionFlowEvent> _history = const [];

  bool _bundleLoading = false;
  String? _bundleError;
  BundleInfo? _bundleInfo;

  final List<_AssignmentRow> _assignments = [];
  final List<String> _rejectedPieces = [];

  @override
  void initState() {
    super.initState();
    _stage = ProductionStage.fromRole(widget.user.role);
    if (_stage != null) {
      if (_stage!.requiresMaster) {
        _loadMasters();
      }
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _remarkCtrl.dispose();
    _rejectedCtrl.dispose();
    for (final row in _assignments) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() {
      _mastersLoading = true;
      _mastersError = null;
    });
    try {
      final masters = await widget.api.fetchMasters();
      if (!mounted) return;
      setState(() {
        _masters = [...masters]..sort((a, b) => a.name.compareTo(b.name));
        if (_selectedMaster != null) {
          final index =
              _masters.indexWhere((master) => master.id == _selectedMaster!.id);
          if (index >= 0) {
            _selectedMaster = _masters[index];
          }
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _mastersError = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _mastersLoading = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    if (_stage == null) return;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final map = await widget.api
          .fetchProductionFlowEntries(stage: _stage!.apiName, limit: 50);
      if (!mounted) return;
      setState(() {
        _history = map[_stage!.apiName] ?? const [];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _historyLoading = false;
        });
      }
    }
  }

  void _addAssignmentRow() {
    setState(() {
      _assignments.add(_AssignmentRow());
    });
  }

  void _removeAssignmentRow(_AssignmentRow row) {
    setState(() {
      _assignments.remove(row);
      row.dispose();
    });
  }

  void _addRejectedPiece() {
    final code = _rejectedCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    if (_rejectedPieces.contains(code)) {
      _rejectedCtrl.clear();
      return;
    }
    setState(() {
      _rejectedPieces.add(code);
      _rejectedCtrl.clear();
    });
  }

  void _removeRejectedPiece(String code) {
    setState(() {
      _rejectedPieces.remove(code);
    });
  }

  Future<void> _lookupBundle() async {
    if (_stage == null || !_stage!.usesBundleCode) return;
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() {
        _bundleInfo = null;
        _bundleError = 'Enter a bundle code to look up details.';
      });
      return;
    }

    setState(() {
      _bundleLoading = true;
      _bundleError = null;
    });

    try {
      final info = await widget.api.fetchBundleDetails(code);
      if (!mounted) return;
      setState(() {
        _bundleInfo = info;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _bundleError = e.message;
        _bundleInfo = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _bundleLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_stage == null || _submitting) return;

    final stage = _stage!;
    final code = _codeCtrl.text.trim();
    final remark = _remarkCtrl.text.trim();

    if (!stage.supportsRejectedPieces && code.isEmpty) {
      setState(() => _submitError = '${stage.codeLabel} is required.');
      return;
    }

    if (stage.supportsRejectedPieces && code.isEmpty && _rejectedPieces.isEmpty) {
      setState(() =>
          _submitError = '${stage.codeLabel} or rejected pieces must be provided.');
      return;
    }

    final selectedMaster = _selectedMaster;
    final hasOverrideMaster = _assignments.any((row) => row.master != null);

    if (stage.requiresMaster && selectedMaster == null && !hasOverrideMaster) {
      setState(() => _submitError = 'Please select a master before submitting.');
      return;
    }

    final assignmentPayload = <Map<String, dynamic>>[];
    for (final row in _assignments) {
      final label = row.sizeCtrl.text.trim();
      if (label.isEmpty) continue;
      final payload = <String, dynamic>{'sizeLabel': label};
      if (row.master != null) {
        payload['masterId'] = row.master!.id;
      }
      assignmentPayload.add(payload);
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final result = await widget.api.submitProductionFlowEntry(
        stage: stage,
        code: code,
        remark: remark,
        masterId: selectedMaster?.id,
        assignments: assignmentPayload,
        rejectedPieces: _rejectedPieces,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _codeCtrl.clear();
        _remarkCtrl.clear();
        _bundleInfo = null;
        _bundleError = null;
        _rejectedPieces.clear();
      });
      await _loadHistory();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      if (_stage?.requiresMaster ?? false) _loadMasters(),
      _loadHistory(),
    ]);
  }

  Future<void> _showCreateMasterDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? error;

    final master = await showDialog<Master?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add master'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Master name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Contact number (optional)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Notes (optional)'),
                      maxLines: 3,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      setStateDialog(() {
                        error = 'Name is required.';
                      });
                      return;
                    }
                    try {
                      final created = await widget.api.createMaster(
                        name: name,
                        contactNumber: phoneCtrl.text.trim().isEmpty
                            ? null
                            : phoneCtrl.text.trim(),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop(created);
                    } on ApiException catch (e) {
                      setStateDialog(() {
                        error = e.message;
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    if (master != null) {
      setState(() {
        final updatedMasters = List<Master>.from(_masters);
        final index = updatedMasters.indexWhere((m) => m.id == master.id);
        if (index >= 0) {
          updatedMasters[index] = master;
        } else {
          updatedMasters.add(master);
        }
        updatedMasters.sort((a, b) => a.name.compareTo(b.name));
        _masters = updatedMasters;
        _selectedMaster = master;
      });
    }

    nameCtrl.dispose();
    phoneCtrl.dispose();
    notesCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;

    if (stage == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Your role does not match any production stage yet. '
            'Please contact your administrator for access.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildStageHeader(stage),
          const SizedBox(height: 16),
          _buildFormCard(stage),
          if (stage.usesBundleCode)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildBundleCard(),
            ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildResultCard(stage, _result!),
            ),
          const SizedBox(height: 16),
          _buildHistoryCard(stage),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStageHeader(ProductionStage stage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stage.displayName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Submit production updates for ${stage.displayName.toLowerCase()} stage. '
              'Use the form below to record bundle or piece progress, '
              'close previous stages, and optionally add remarks.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.badge_outlined, widget.user.username),
                _buildInfoChip(Icons.workspaces, widget.user.role),
                _buildInfoChip(Icons.qr_code_2, stage.codeLabel),
                if (stage.requiresMaster)
                  _buildInfoChip(Icons.engineering, 'Master required'),
                if (stage.supportsRejectedPieces)
                  _buildInfoChip(Icons.report, 'Can reject pieces'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(ProductionStage stage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record update',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: stage.codeLabel,
                  prefixIcon: const Icon(Icons.qr_code_2_outlined),
                  suffixIcon: stage.usesBundleCode
                      ? IconButton(
                          tooltip: 'Lookup bundle details',
                          onPressed: _bundleLoading ? null : _lookupBundle,
                          icon: _bundleLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                        )
                      : null,
                ),
                onFieldSubmitted: (_) {
                  if (stage.usesBundleCode) {
                    _lookupBundle();
                  }
                },
              ),
              if (stage.requiresMaster) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Master?>(
                        value: _selectedMaster,
                        decoration: const InputDecoration(
                          labelText: 'Select master',
                          prefixIcon: Icon(Icons.engineering_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<Master?>(
                            value: null,
                            child: Text('Select master'),
                          ),
                          ..._masters.map(
                            (master) => DropdownMenuItem<Master?>(
                              value: master,
                              child: Text(master.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedMaster = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        IconButton(
                          tooltip: 'Refresh masters',
                          onPressed: _mastersLoading ? null : _loadMasters,
                          icon: _mastersLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                        ),
                        IconButton(
                          tooltip: 'Add master',
                          onPressed: _showCreateMasterDialog,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_mastersError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _mastersError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('Per-size master overrides (optional)'),
                  subtitle: const Text(
                      'Add size labels with different masters if required.'),
                  children: [
                    if (_assignments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No overrides added yet.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ),
                    for (final row in _assignments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.sizeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Size label',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<Master?>(
                                value: row.master,
                                decoration: const InputDecoration(
                                  labelText: 'Master',
                                ),
                                items: _masters
                                    .map(
                                      (master) => DropdownMenuItem<Master?>(
                                        value: master,
                                        child: Text(master.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    row.master = value;
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: () => _removeAssignmentRow(row),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addAssignmentRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Add size override'),
                      ),
                    ),
                  ],
                ),
              ],
              if (stage.supportsRejectedPieces) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rejectedCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Rejected piece code',
                    prefixIcon: const Icon(Icons.report_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addRejectedPiece,
                    ),
                  ),
                  onFieldSubmitted: (_) => _addRejectedPiece(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _rejectedPieces
                      .map(
                        (code) => Chip(
                          label: Text(code),
                          onDeleted: () => _removeRejectedPiece(code),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _remarkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Remark (optional)',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
                maxLines: 2,
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _submitError!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_submitting ? 'Submitting…' : 'Submit update'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBundleCard() {
    if (_bundleLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: const [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Fetching bundle details…'),
            ],
          ),
        ),
      );
    }

    if (_bundleError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _bundleError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    if (_bundleInfo == null) {
      return const SizedBox.shrink();
    }

    final info = _bundleInfo!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bundle ${info.bundleCode}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildInfoChip(Icons.inventory_2_outlined,
                    '${info.piecesInBundle} pieces planned'),
                _buildInfoChip(Icons.confirmation_number_outlined,
                    'Lot ${info.lotNumber}'),
                if (info.sku != null && info.sku!.isNotEmpty)
                  _buildInfoChip(Icons.style_outlined, 'SKU ${info.sku}'),
                if (info.fabricType != null && info.fabricType!.isNotEmpty)
                  _buildInfoChip(
                      Icons.texture, 'Fabric ${info.fabricType!.toUpperCase()}'),
              ],
            ),
            const SizedBox(height: 12),
            Text('Recorded pieces: ${info.pieceCount}'),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
      ProductionStage stage, ProductionFlowSubmissionResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Submission successful',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (result.lotNumber != null)
                  _buildInfoChip(Icons.confirmation_number_outlined,
                      'Lot ${result.lotNumber}'),
                if (result.bundleCode != null)
                  _buildInfoChip(
                      Icons.inventory_2_outlined, 'Bundle ${result.bundleCode}'),
                if (result.pieceCode != null)
                  _buildInfoChip(Icons.qr_code, 'Piece ${result.pieceCode}'),
                if (result.pieces != null)
                  _buildInfoChip(Icons.format_list_numbered,
                      '${result.pieces} pieces'),
                if (result.masterName != null)
                  _buildInfoChip(Icons.engineering, result.masterName!),
              ],
            ),
            if (result.assignments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Size assignments',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Column(
                children: result.assignments
                    .map(
                      (assignment) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(assignment.sizeLabel ?? 'Size'),
                        subtitle: Text(
                          '${assignment.bundles ?? 0} bundles · '
                          '${assignment.masterName ?? 'Master not set'}',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (result.rejectedPieces.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Rejected pieces',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.rejectedPieces
                    .map((code) => Chip(label: Text(code)))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Event log updates',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            _buildClosureRow('Closed back pocket bundles', result.closedBackPocket),
            _buildClosureRow('Closed stitching bundles', result.closedStitching),
            _buildClosureRow('Closed jeans assembly bundles', result.closedJeansAssembly),
            _buildClosureRow('Closed washing in bundles', result.washingInClosed),
          ],
        ),
      ),
    );
  }

  Widget _buildClosureRow(String label, int? value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(value > 0 ? Icons.task_alt : Icons.info_outline,
              size: 18,
              color: value > 0
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: $value'),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ProductionStage stage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recent activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh history',
                  onPressed: _historyLoading ? null : _loadHistory,
                  icon: _historyLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_historyError != null)
              Text(
                _historyError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_historyLoading)
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_history.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text('No submissions yet. Be the first to update!'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                separatorBuilder: (_, __) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final event = _history[index];
                  return _HistoryTile(event: event);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _AssignmentRow {
  final TextEditingController sizeCtrl = TextEditingController();
  Master? master;

  void dispose() {
    sizeCtrl.dispose();
  }
}

class _HistoryTile extends StatelessWidget {
  final ProductionFlowEvent event;

  const _HistoryTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              event.codeValue,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            Text(
              event.createdAt?.toLocal().toString().split('.').first ?? '',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (event.bundleCode != null && event.bundleCode!.isNotEmpty)
              Chip(label: Text('Bundle ${event.bundleCode}')),
            if (event.pieceCode != null && event.pieceCode!.isNotEmpty)
              Chip(label: Text('Piece ${event.pieceCode}')),
            if (event.lotNumber != null && event.lotNumber!.isNotEmpty)
              Chip(label: Text('Lot ${event.lotNumber}')),
            if (event.masterName != null && event.masterName!.isNotEmpty)
              Chip(label: Text(event.masterName!)),
            Chip(label: Text(event.eventStatus ?? 'open')),
          ],
        ),
        if (event.remark != null && event.remark!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            event.remark!,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[700]),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'Recorded by ${event.userUsername ?? 'Unknown'}${event.isClosed ? ' · Closed' : ''}',
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/bundle_info.dart';
import '../models/login_response.dart';
import '../models/production_entry.dart';
import '../services/api_service.dart';
import 'login_page.dart';

const Map<String, String> _roleStageMap = {
  'back_pocket': 'back_pocket',
  'stitching_master': 'stitching_master',
  'jeans_assembly': 'jeans_assembly',
  'washing': 'washing',
  'washing_in': 'washing_in',
  'finishing': 'finishing',
};

class StageConfig {
  final String stage;
  final String title;
  final String description;
  final String codeLabel;
  final String codeHint;
  final bool codeOptional;
  final bool requiresMaster;
  final bool enableAssignments;
  final bool enableBundleLookup;
  final bool enableRejectedPieces;
  final List<String> tips;

  const StageConfig({
    required this.stage,
    required this.title,
    required this.description,
    required this.codeLabel,
    required this.codeHint,
    this.codeOptional = false,
    this.requiresMaster = false,
    this.enableAssignments = false,
    this.enableBundleLookup = false,
    this.enableRejectedPieces = false,
    this.tips = const [],
  });

  String get stageDisplayName => title;
  bool get uppercaseCode => true;

  static StageConfig? forRole(String normalizedRole) {
    final stage = _roleStageMap[normalizedRole] ?? normalizedRole;
    return StageConfig.forStage(stage);
  }

  static StageConfig? forStage(String stage) {
    switch (stage) {
      case 'back_pocket':
        return const StageConfig(
          stage: 'back_pocket',
          title: 'Back Pocket',
          description:
              'Register lots coming into the back pocket line. The system creates bundle events for every size in the lot.',
          codeLabel: 'Lot number',
          codeHint: 'Example: LOT-24-001',
          requiresMaster: true,
          enableAssignments: true,
          tips: [
            'Scan or type the lot number exactly as printed on the card.',
            'Select a master once to apply to every size, or assign masters per size below.',
            'Leave the size table empty to automatically assign every size in the lot.',
          ],
        );
      case 'stitching_master':
        return const StageConfig(
          stage: 'stitching_master',
          title: 'Stitching Master',
          description:
              'Distribute lots to stitching masters. You can keep the assignment simple or control masters per size.',
          codeLabel: 'Lot number',
          codeHint: 'Example: LOT-24-001',
          requiresMaster: true,
          enableAssignments: true,
          tips: [
            'Lot code is mandatory. Verify it before submitting.',
            'Provide a default master or set different masters for specific sizes.',
            'Automatic bundle creation happens for every size in the lot.',
          ],
        );
      case 'jeans_assembly':
        return const StageConfig(
          stage: 'jeans_assembly',
          title: 'Jeans Assembly',
          description:
              'Record bundles entering jeans assembly and optionally mark rejected piece codes at the same time.',
          codeLabel: 'Bundle code',
          codeHint: 'Example: BND-001-01',
          requiresMaster: true,
          enableBundleLookup: true,
          enableRejectedPieces: true,
          codeOptional: true,
          tips: [
            'Scan the bundle code before closing the prior stages.',
            'Add rejected piece codes if you are sending pieces back for rework.',
            'You must choose a jeans assembly master or supervisor.',
          ],
        );
      case 'washing':
        return const StageConfig(
          stage: 'washing',
          title: 'Washing',
          description:
              'Start the washing cycle for all open jeans assembly bundles within a lot. This closes jeans assembly automatically.',
          codeLabel: 'Lot number',
          codeHint: 'Example: LOT-24-001',
          tips: [
            'Only lots with open jeans assembly bundles can be moved to washing.',
            'Submitting the lot pulls every open piece from jeans assembly and closes it.',
          ],
        );
      case 'washing_in':
        return const StageConfig(
          stage: 'washing_in',
          title: 'Washing In',
          description:
              'Receive washed pieces back into the plant. Log the returning piece or mark rejected pieces that failed inspection.',
          codeLabel: 'Piece code',
          codeHint: 'Example: PC-000123',
          enableRejectedPieces: true,
          codeOptional: true,
          tips: [
            'Either scan an individual piece code or list the rejected pieces below.',
            'Pieces must have an open washing record before you can close them here.',
          ],
        );
      case 'finishing':
        return const StageConfig(
          stage: 'finishing',
          title: 'Finishing',
          description:
              'Close bundles leaving the finishing line. Every piece in the bundle must have passed washing in.',
          codeLabel: 'Bundle code',
          codeHint: 'Example: BND-001-01',
          requiresMaster: true,
          enableBundleLookup: true,
          tips: [
            'Verify that every piece in the bundle is recorded in washing in.',
            'Assign the finishing master or QC lead before submitting.',
          ],
        );
      default:
        return null;
    }
  }
}

class ResponsePage extends StatefulWidget {
  static const routeName = '/response';
  final LoginResponse data;
  final ApiService api;

  const ResponsePage({super.key, required this.data, required this.api});

  @override
  State<ResponsePage> createState() => _ResponsePageState();
}

class _ResponsePageState extends State<ResponsePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  final TextEditingController _masterIdCtrl = TextEditingController();
  final TextEditingController _masterNameCtrl = TextEditingController();
  final TextEditingController _rejectionCtrl = TextEditingController();

  final List<String> _rejectedPieces = [];
  final List<SizeAssignmentForm> _assignments = [];

  bool _submitting = false;
  bool _loadingEntries = false;
  bool _lookupLoading = false;

  String? _entriesError;
  String? _lookupError;

  BundleInfo? _bundleInfo;
  Map<String, dynamic>? _submissionResponse;
  List<ProductionEntry> _entries = [];

  StageConfig? get _config => StageConfig.forRole(widget.data.normalizedRole);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }
  @override
  void dispose() {
    _codeCtrl.dispose();
    _remarkCtrl.dispose();
    _masterIdCtrl.dispose();
    _masterNameCtrl.dispose();
    _rejectionCtrl.dispose();
    for (final assignment in _assignments) {
      assignment.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHistory({bool silent = false}) async {
    final config = _config;
    if (config == null) return;
    if (!silent) {
      setState(() {
        _loadingEntries = true;
        _entriesError = null;
      });
    }

    try {
      final results = await widget.api.fetchProductionFlowEntries(
        stage: config.stage,
      );
      if (!mounted) return;
      setState(() {
        _entries = results;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _entriesError = e.message;
      });
    } finally {
      if (!mounted || silent) return;
      setState(() {
        _loadingEntries = false;
      });
    }
  }

  Future<void> _refreshHistory() async {
    await _loadHistory(silent: true);
  }

  int? _parseInt(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _lookupBundle() async {
    final config = _config;
    if (config == null || !config.enableBundleLookup) return;
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() {
        _lookupError = 'Enter a bundle code to lookup details.';
        _bundleInfo = null;
      });
      return;
    }

    setState(() {
      _lookupLoading = true;
      _lookupError = null;
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
        _lookupError = e.message;
        _bundleInfo = null;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _lookupLoading = false;
      });
    }
  }

  void _addRejectedPieces(String value) {
    final tokens = value
        .split(RegExp(r'[\s,;]+'))
        .map((token) => token.trim().toUpperCase())
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return;

    setState(() {
      for (final token in tokens) {
        if (!_rejectedPieces.contains(token)) {
          _rejectedPieces.add(token);
        }
      }
      _rejectionCtrl.clear();
    });
    _formKey.currentState?.validate();
  }

  void _removeRejectedPiece(String code) {
    setState(() {
      _rejectedPieces.remove(code);
    });
    _formKey.currentState?.validate();
  }

  void _addAssignment() {
    setState(() {
      _assignments.add(SizeAssignmentForm());
    });
  }

  void _removeAssignment(SizeAssignmentForm form) {
    setState(() {
      _assignments.remove(form);
    });
    form.dispose();
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Chip _statusChip(ProductionEntry entry) {
    Color baseColor;
    switch (entry.eventStatus.toLowerCase()) {
      case 'closed':
        baseColor = Colors.green;
        break;
      case 'rejected':
        baseColor = Colors.redAccent;
        break;
      default:
        baseColor = Colors.blueAccent;
    }
    final label = entry.eventStatus.isEmpty
        ? (entry.isClosed ? 'Closed' : 'Open')
        : entry.eventStatus;
    return Chip(
      label: Text(label),
      backgroundColor: baseColor.withOpacity(0.12),
      labelStyle: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Future<void> _submit() async {
    final config = _config;
    if (config == null) return;
    if (_submitting) return;

    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    final hasCode = _codeCtrl.text.trim().isNotEmpty;
    if (!hasCode && _rejectedPieces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provide a code or rejected pieces before submitting.')),
      );
      return;
    }

    for (final assignment in _assignments) {
      if (assignment.hasIncompleteSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each size assignment must include a size label or ID.')),
        );
        return;
      }
    }

    final globalMasterId = _parseInt(_masterIdCtrl);
    final globalMasterName = _masterNameCtrl.text.trim();

    if (config.requiresMaster) {
      final globalProvided =
          (globalMasterId != null && globalMasterId > 0) || globalMasterName.isNotEmpty;
      final assignmentsWithSize =
          _assignments.where((form) => form.hasSize).toList(growable: false);
      final assignmentsHaveMaster = assignmentsWithSize.every((form) => form.hasMaster);

      if (!globalProvided && !assignmentsHaveMaster) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Select a master or assign masters per size before submitting.'),
          ),
        );
        return;
      }
    }

    final codeRaw = _codeCtrl.text.trim();
    final code = config.uppercaseCode ? codeRaw.toUpperCase() : codeRaw;
    final remark = _remarkCtrl.text.trim();

    final assignmentsPayload = _assignments
        .map((assignment) => assignment.toPayload())
        .where((payload) => payload.containsKey('sizeId') ||
            ((payload['sizeLabel'] as String?)?.isNotEmpty ?? false))
        .toList();

    final payload = <String, dynamic>{
      if (hasCode) 'code': code,
      if (remark.isNotEmpty) 'remark': remark,
      if (config.requiresMaster)
        ...{
          if (globalMasterId != null && globalMasterId > 0) 'masterId': globalMasterId,
          if (globalMasterName.isNotEmpty) 'masterName': globalMasterName,
        },
      if (assignmentsPayload.isNotEmpty) 'assignments': assignmentsPayload,
      if (config.enableRejectedPieces && _rejectedPieces.isNotEmpty)
        'rejectedPieces': _rejectedPieces,
    };

    setState(() {
      _submitting = true;
    });

    FocusScope.of(context).unfocus();

    try {
      final response = await widget.api.submitProductionFlowEntry(payload);
      if (!mounted) return;
      setState(() {
        _submissionResponse = response;
        _bundleInfo = config.enableBundleLookup ? _bundleInfo : null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry submitted successfully.')),
      );

      _codeCtrl.clear();
      _remarkCtrl.clear();
      _masterIdCtrl.clear();
      _masterNameCtrl.clear();
      _rejectionCtrl.clear();
      setState(() {
        _rejectedPieces.clear();
        for (final assignment in _assignments) {
          assignment.dispose();
        }
        _assignments.clear();
      });

      await _loadHistory(silent: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
    }
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Production flow'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: _logout,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_rounded, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'Your role (${widget.data.role}) does not map to a production flow stage.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please contact your administrator to grant access to one of the production stages.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${config.stageDisplayName} stage'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: _logout,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Submit entry'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSubmitTab(config),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitTab(StageConfig config) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.stageDisplayName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    config.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (config.tips.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Tips', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: config.tips
                          .map(
                            (tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• '),
                                  Expanded(child: Text(tip)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submit production entry',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codeCtrl,
                    decoration: InputDecoration(
                      labelText: config.codeLabel,
                      hintText: config.codeHint,
                      prefixIcon: const Icon(Icons.qr_code_scanner_outlined),
                      suffixIcon: config.enableBundleLookup
                          ? IconButton(
                              icon: _lookupLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.search),
                              tooltip: 'Lookup bundle details',
                              onPressed: _lookupLoading ? null : _lookupBundle,
                            )
                          : null,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty && (!config.codeOptional || _rejectedPieces.isEmpty)) {
                        return '${config.codeLabel} is required.';
                      }
                      return null;
                    },
                  ),
                  if (config.enableBundleLookup) ...[
                    const SizedBox(height: 12),
                    if (_lookupError != null)
                      Text(
                        _lookupError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    if (_bundleInfo != null) _buildBundleInfoCard(_bundleInfo!),
                  ],
                  if (config.requiresMaster) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Default master (optional per size)',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _masterIdCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Master ID',
                              hintText: 'Numeric ID',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _masterNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Master name',
                              hintText: 'Name as saved in portal',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (config.enableAssignments) ...[
                    const SizedBox(height: 24),
                    _buildAssignmentsSection(theme, config),
                  ],
                  if (config.enableRejectedPieces) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Rejected piece codes',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Optional – add piece codes that are rejected at this stage. Use comma or space separated values.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _rejectionCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Add rejected piece code',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _addRejectedPieces(_rejectionCtrl.text),
                        ),
                      ),
                      onSubmitted: _addRejectedPieces,
                    ),
                    const SizedBox(height: 12),
                    if (_rejectedPieces.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                        ),
                        child: const Text('No rejected pieces added.'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _rejectedPieces
                            .map(
                              (code) => Chip(
                                label: Text(code),
                                deleteIcon: const Icon(Icons.close),
                                onDeleted: () => _removeRejectedPiece(code),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _remarkCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Remark (optional)',
                      hintText: 'Add notes for the next stage or QC team',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(_submitting ? 'Submitting…' : 'Submit entry'),
                      ),
                      onPressed: _submitting ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_submissionResponse != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latest submission response',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        const JsonEncoder.withIndent('  ').convert(_submissionResponse),
                        style: const TextStyle(fontFamily: 'SourceCodePro', fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBundleInfoCard(BundleInfo info) {
    final theme = Theme.of(context);
    final entries = <MapEntry<String, String?>>[
      MapEntry('Bundle code', info.bundleCode),
      MapEntry('Lot number', info.lotNumber),
      MapEntry('Pieces in bundle', info.piecesInBundle.toString()),
      MapEntry('Lot ID', info.lotId.toString()),
      MapEntry('Pieces recorded', info.pieceCount.toString()),
      MapEntry('SKU', info.sku),
      MapEntry('Fabric', info.fabricType),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bundle lookup',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: entries
                .where((entry) => entry.value != null && entry.value!.isNotEmpty)
                .map(
                  (entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.key,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        entry.value!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsSection(ThemeData theme, StageConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Size assignments',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Optional – add specific sizes if you want to direct bundles to different masters.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (_assignments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            ),
            child: const Text(
              'No specific sizes added. The system will assign every size in the lot to the selected master.',
            ),
          )
        else
          Column(
            children: _assignments
                .map(
                  (form) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SizeAssignmentCard(
                      form: form,
                      showMasterFields: config.requiresMaster,
                      onRemove: () => _removeAssignment(form),
                    ),
                  ),
                )
                .toList(),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add size assignment'),
            onPressed: _addAssignment,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final theme = Theme.of(context);
    final hasError = _entriesError != null && _entries.isEmpty;

    final children = <Widget>[];

    if (_loadingEntries && _entries.isEmpty && !hasError) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (hasError) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _entriesError!,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                onPressed: () => _loadHistory(),
              ),
            ],
          ),
        ),
      );
    } else if (_entries.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
              SizedBox(height: 12),
              Text('No entries recorded yet.'),
              SizedBox(height: 4),
              Text(
                'Submit an entry to see it listed here.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    } else {
      children.addAll(
        _entries.map((entry) {
          final subtitle = <String>[
            'Type: ${entry.codeType}',
            if (entry.lotNumber != null) 'Lot: ${entry.lotNumber}',
            if (entry.bundleCode != null) 'Bundle: ${entry.bundleCode}',
            if (entry.pieceCode != null) 'Piece: ${entry.pieceCode}',
            if (entry.masterName != null) 'Master: ${entry.masterName}',
          ].join(' • ');

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(entry.codeValue.isEmpty ? '—' : entry.codeValue),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtitle),
                    const SizedBox(height: 6),
                    Text(
                      'Created: ${_formatDateTime(entry.createdAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (entry.isClosed)
                      Text(
                        'Closed: ${_formatDateTime(entry.closedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (entry.remark != null && entry.remark!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          entry.remark!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              trailing: _statusChip(entry),
            ),
          );
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshHistory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}
}

class SizeAssignmentForm {
  final TextEditingController sizeIdCtrl = TextEditingController();
  final TextEditingController sizeLabelCtrl = TextEditingController();
  final TextEditingController masterIdCtrl = TextEditingController();
  final TextEditingController masterNameCtrl = TextEditingController();

  bool get hasSize {
    if (sizeLabelCtrl.text.trim().isNotEmpty) return true;
    return int.tryParse(sizeIdCtrl.text.trim()) != null;
  }

  bool get hasMaster {
    return masterIdCtrl.text.trim().isNotEmpty || masterNameCtrl.text.trim().isNotEmpty;
  }

  bool get hasIncompleteSize {
    final anyInput = sizeLabelCtrl.text.trim().isNotEmpty ||
        sizeIdCtrl.text.trim().isNotEmpty ||
        masterIdCtrl.text.trim().isNotEmpty ||
        masterNameCtrl.text.trim().isNotEmpty;
    return anyInput && !hasSize;
  }

  Map<String, dynamic> toPayload() {
    final result = <String, dynamic>{};
    final sizeId = int.tryParse(sizeIdCtrl.text.trim());
    final sizeLabel = sizeLabelCtrl.text.trim().toUpperCase();
    final masterId = int.tryParse(masterIdCtrl.text.trim());
    final masterName = masterNameCtrl.text.trim();

    if (sizeId != null && sizeId > 0) {
      result['sizeId'] = sizeId;
    }
    if (sizeLabel.isNotEmpty) {
      result['sizeLabel'] = sizeLabel;
    }
    if (masterId != null && masterId > 0) {
      result['masterId'] = masterId;
    }
    if (masterName.isNotEmpty) {
      result['masterName'] = masterName;
    }
    return result;
  }

  void dispose() {
    sizeIdCtrl.dispose();
    sizeLabelCtrl.dispose();
    masterIdCtrl.dispose();
    masterNameCtrl.dispose();
  }
}

class _SizeAssignmentCard extends StatelessWidget {
  final SizeAssignmentForm form;
  final bool showMasterFields;
  final VoidCallback onRemove;

  const _SizeAssignmentCard({
    required this.form,
    required this.showMasterFields,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: form.sizeIdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Size ID',
                    hintText: 'Numeric size ID',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: form.sizeLabelCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Size label',
                    hintText: 'e.g. 32 or M',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                ),
              ),
            ],
          ),
          if (showMasterFields) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: form.masterIdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Master ID',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: form.masterNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Master name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
  }
}

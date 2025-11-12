import 'package:flutter/material.dart';

import '../models/login_response.dart';
import '../models/production_bundle.dart';
import '../models/production_flow_entry.dart';
import '../models/production_flow_submission.dart';
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

const Set<String> _stagesRequiringMaster = {
  'back_pocket',
  'stitching_master',
  'jeans_assembly',
  'finishing',
};

class ProductionFlowPage extends StatefulWidget {
  final LoginResponse data;
  final ApiService api;

  const ProductionFlowPage({super.key, required this.data, required this.api});

  @override
  State<ProductionFlowPage> createState() => _ProductionFlowPageState();
}

class _ProductionFlowPageState extends State<ProductionFlowPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  final TextEditingController _masterIdCtrl = TextEditingController();
  final TextEditingController _masterNameCtrl = TextEditingController();
  final TextEditingController _rejectedCtrl = TextEditingController();

  final List<_AssignmentField> _assignments = [];

  late final String _stage = _resolveStage();

  bool _submitting = false;
  bool _loadingEntries = false;
  bool _lookupLoading = false;
  bool _useCustomAssignments = false;

  String? _formError;
  String? _entriesError;
  String? _bundleError;

  ProductionFlowSubmissionResult? _lastResult;
  ProductionBundleSummary? _bundleSummary;
  List<ProductionFlowEntry> _entries = [];

  bool get _requiresMaster => _stagesRequiringMaster.contains(_stage);
  bool get _supportsAssignments =>
      _stage == 'back_pocket' || _stage == 'stitching_master';
  bool get _supportsRejections => _stage == 'jeans_assembly' || _stage == 'washing_in';
  bool get _bundleLookupEnabled =>
      _stage == 'jeans_assembly' || _stage == 'finishing';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _remarkCtrl.dispose();
    _masterIdCtrl.dispose();
    _masterNameCtrl.dispose();
    _rejectedCtrl.dispose();
    for (final assignment in _assignments) {
      assignment.dispose();
    }
    widget.api.dispose();
    super.dispose();
  }

  String _resolveStage() {
    final normalized = widget.data.normalizedRole;
    return _roleStageMap[normalized] ?? normalized;
  }

  String get _stageDisplayName {
    return _stage
        .split('_')
        .map((part) =>
            part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String get _codeLabel {
    switch (_stage) {
      case 'back_pocket':
      case 'stitching_master':
      case 'washing':
        return 'Lot number';
      case 'washing_in':
        return 'Piece code';
      case 'jeans_assembly':
      case 'finishing':
      default:
        return 'Bundle code';
    }
  }

  String get _codeHelper {
    switch (_stage) {
      case 'back_pocket':
        return 'Enter the lot number you are assigning to back pocket. Leave assignments empty to auto-assign all sizes.';
      case 'stitching_master':
        return 'Enter the lot number received from cutting. Assign masters per size if needed.';
      case 'jeans_assembly':
        return 'Scan the bundle code to progress to jeans assembly. Add rejected piece codes if applicable.';
      case 'washing':
        return 'Enter the lot number to register all open jeans assembly pieces into washing.';
      case 'washing_in':
        return 'Scan a washed piece code or record rejected pieces returned from washing.';
      case 'finishing':
        return 'Scan the bundle code to move it to finishing once all washing-in pieces are recorded.';
      default:
        return '';
    }
  }

  List<String> get _stageNotes {
    switch (_stage) {
      case 'back_pocket':
        return [
          'Masters are required; set a default master or choose per size.',
          'Bundles will be auto-generated from the lot configuration.',
        ];
      case 'stitching_master':
        return [
          'Ensure the lot has completed the back pocket stage.',
          'You can split assignments per size for different masters.',
        ];
      case 'jeans_assembly':
        return [
          'Bundle must already be submitted by both back pocket and stitching master.',
          'Rejected piece codes can be captured separately and will auto-close earlier stages.',
        ];
      case 'washing':
        return [
          'All open jeans assembly pieces for the lot will be moved into washing.',
          'The lot must still have open jeans assembly entries.',
        ];
      case 'washing_in':
        return [
          'Each piece scanned closes the corresponding washing entry.',
          'Rejected pieces will also close the washing entry for those codes.',
        ];
      case 'finishing':
        return [
          'All pieces in the bundle must be recorded in washing_in before finishing.',
          'Masters are required for finishing submissions.',
        ];
      default:
        return [];
    }
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loadingEntries = true;
      _entriesError = null;
    });
    try {
      final results = await widget.api.fetchProductionFlowEntries(stage: _stage);
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
      if (mounted) {
        setState(() {
          _loadingEntries = false;
        });
      }
    }
  }

  void _toggleAssignments(bool value) {
    setState(() {
      _useCustomAssignments = value;
      _formError = null;
      if (value && _assignments.isEmpty) {
        _assignments.add(_AssignmentField());
      }
    });
  }

  void _addAssignment() {
    setState(() {
      _assignments.add(_AssignmentField());
    });
  }

  void _removeAssignment(int index) {
    setState(() {
      final removed = _assignments.removeAt(index);
      removed.dispose();
    });
  }

  List<String> _collectRejectedPieces() {
    if (!_supportsRejections) return const [];
    final raw = _rejectedCtrl.text;
    if (raw.trim().isEmpty) return const [];
    final tokens = raw
        .split(RegExp(r'[\s,]+'))
        .map((token) => token.trim().toUpperCase())
        .where((token) => token.isNotEmpty)
        .toSet()
        .toList();
    tokens.sort();
    return tokens;
  }

  Map<String, dynamic>? _buildAssignmentsPayload() {
    if (!_supportsAssignments || !_useCustomAssignments) {
      return null;
    }

    final payload = <Map<String, dynamic>>[];
    for (final assignment in _assignments) {
      final sizeIdText = assignment.sizeIdCtrl.text.trim();
      final sizeLabelText = assignment.sizeLabelCtrl.text.trim();
      final masterIdText = assignment.masterIdCtrl.text.trim();
      final masterNameText = assignment.masterNameCtrl.text.trim();

      if (sizeIdText.isEmpty && sizeLabelText.isEmpty) {
        // Skip empty rows.
        continue;
      }

      final entry = <String, dynamic>{};
      if (sizeIdText.isNotEmpty) {
        final parsed = int.tryParse(sizeIdText);
        if (parsed == null) {
          _formError = 'Invalid size ID "${assignment.sizeIdCtrl.text}".';
          return null;
        }
        entry['sizeId'] = parsed;
      }
      if (sizeLabelText.isNotEmpty) {
        entry['sizeLabel'] = sizeLabelText.toUpperCase();
      }

      if (_requiresMaster) {
        if (masterIdText.isEmpty && masterNameText.isEmpty) {
          _formError =
              'Provide a master for each custom assignment (missing for ${sizeLabelText.isEmpty ? 'size entry' : sizeLabelText}).';
          return null;
        }
        if (masterIdText.isNotEmpty) {
          final parsed = int.tryParse(masterIdText);
          if (parsed == null) {
            _formError = 'Invalid master ID "${assignment.masterIdCtrl.text}".';
            return null;
          }
          entry['masterId'] = parsed;
        }
        if (masterNameText.isNotEmpty) {
          entry['masterName'] = masterNameText.trim();
        }
      } else {
        if (masterIdText.isNotEmpty) {
          final parsed = int.tryParse(masterIdText);
          if (parsed == null) {
            _formError = 'Invalid master ID "${assignment.masterIdCtrl.text}".';
            return null;
          }
          entry['masterId'] = parsed;
        }
        if (masterNameText.isNotEmpty) {
          entry['masterName'] = masterNameText.trim();
        }
      }

      if (entry['sizeId'] == null && entry['sizeLabel'] == null) {
        _formError = 'Each assignment requires either a size ID or size label.';
        return null;
      }

      payload.add(entry);
    }

    if (payload.isEmpty) {
      _formError = 'Add at least one assignment entry or disable custom assignments.';
      return null;
    }

    return {'assignments': payload};
  }

  Future<void> _lookupBundle() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _bundleSummary = null;
        _bundleError = 'Enter a bundle code to lookup.';
      });
      return;
    }

    setState(() {
      _lookupLoading = true;
      _bundleError = null;
    });

    try {
      final summary = await widget.api.fetchProductionBundle(code);
      if (!mounted) return;
      setState(() {
        _bundleSummary = summary;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _bundleSummary = null;
        _bundleError = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _lookupLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    _formError = null;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final code = _codeCtrl.text.trim().toUpperCase();
    final rejectedPieces = _collectRejectedPieces();
    final remark = _remarkCtrl.text.trim();

    if (code.isEmpty && rejectedPieces.isEmpty) {
      setState(() {
        _formError =
            _supportsRejections ? 'Provide a code or at least one rejected piece.' : 'Code is required.';
      });
      return;
    }

    final defaultMasterIdText = _masterIdCtrl.text.trim();
    final defaultMasterNameText = _masterNameCtrl.text.trim();
    int? defaultMasterId;

    if (_requiresMaster && !_useCustomAssignments) {
      if (defaultMasterIdText.isEmpty && defaultMasterNameText.isEmpty) {
        setState(() {
          _formError = 'Master selection is required for this stage.';
        });
        return;
      }
    }

    if (defaultMasterIdText.isNotEmpty) {
      defaultMasterId = int.tryParse(defaultMasterIdText);
      if (defaultMasterId == null) {
        setState(() {
          _formError = 'Invalid master ID.';
        });
        return;
      }
    }

    final assignmentsPayload = _buildAssignmentsPayload();
    if (_formError != null) {
      setState(() {});
      return;
    }

    final payload = <String, dynamic>{};
    if (code.isNotEmpty) {
      payload['code'] = code;
    }
    if (remark.isNotEmpty) {
      payload['remark'] = remark;
    }
    if (_supportsRejections && rejectedPieces.isNotEmpty) {
      payload['rejectedPieces'] = rejectedPieces;
    }
    if (_requiresMaster && !_useCustomAssignments) {
      if (defaultMasterId != null) {
        payload['masterId'] = defaultMasterId;
      }
      if (defaultMasterNameText.isNotEmpty) {
        payload['masterName'] = defaultMasterNameText.trim();
      }
    } else {
      if (defaultMasterId != null) {
        payload['masterId'] = defaultMasterId;
      }
      if (defaultMasterNameText.isNotEmpty) {
        payload['masterName'] = defaultMasterNameText.trim();
      }
    }

    if (assignmentsPayload != null) {
      payload.addAll(assignmentsPayload);
    }

    setState(() {
      _submitting = true;
      _formError = null;
    });

    try {
      final result = await widget.api.submitProductionFlowEntry(payload);
      if (!mounted) return;
      setState(() {
        _lastResult = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Production entry submitted successfully.')),
      );
      if (code.isNotEmpty) {
        _codeCtrl.clear();
      }
      if (_supportsRejections) {
        _rejectedCtrl.clear();
      }
      await _loadEntries();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Production flow · $_stageDisplayName'),
          actions: [
            IconButton(
              tooltip: 'Refresh history',
              icon: const Icon(Icons.history),
              onPressed: _loadingEntries ? null : _loadEntries,
            ),
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Submit entry'),
              Tab(text: 'Recent entries'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSubmitTab(context),
            _buildEntriesTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitTab(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(theme),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCodeCard(theme),
                  const SizedBox(height: 16),
                  if (_requiresMaster) _buildMasterCard(theme),
                  if (!_requiresMaster)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _buildOptionalMasterFields(theme),
                      ),
                    ),
                  if (_supportsAssignments) ...[
                    const SizedBox(height: 16),
                    _buildAssignmentsCard(theme),
                  ],
                  if (_supportsRejections) ...[
                    const SizedBox(height: 16),
                    _buildRejectionCard(theme),
                  ],
                  const SizedBox(height: 16),
                  _buildRemarkCard(theme),
                  if (_formError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _formError!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_submitting ? 'Submitting…' : 'Submit entry'),
                      onPressed: _submitting ? null : _submit,
                    ),
                  ),
                  if (_lastResult != null) ...[
                    const SizedBox(height: 20),
                    _buildResultCard(theme),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    widget.data.username.substring(0, 1).toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data.username,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Chip(
                            label: Text('Role: ${widget.data.role}'),
                          ),
                          Chip(
                            label: Text('Stage: $_stageDisplayName'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_stageNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Guidelines',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final note in _stageNotes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(
                            child: Text(
                              note,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCodeCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _codeLabel,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codeCtrl,
              decoration: InputDecoration(
                labelText: _codeLabel,
                helperText: _codeHelper.isEmpty ? null : _codeHelper,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            if (_bundleLookupEnabled) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: _lookupLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_lookupLoading ? 'Looking up…' : 'Lookup bundle'),
                  onPressed: _lookupLoading ? null : _lookupBundle,
                ),
              ),
              if (_bundleError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _bundleError!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              if (_bundleSummary != null) ...[
                const SizedBox(height: 12),
                _buildBundleSummary(theme, _bundleSummary!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBundleSummary(ThemeData theme, ProductionBundleSummary summary) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.primary.withOpacity(0.05),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.bundleCode,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMiniDetail('Lot', summary.lotNumber),
              _buildMiniDetail('Pieces', summary.piecesInBundle.toString()),
              if (summary.sku != null && summary.sku!.isNotEmpty)
                _buildMiniDetail('SKU', summary.sku!),
              if (summary.fabricType != null && summary.fabricType!.isNotEmpty)
                _buildMiniDetail('Fabric', summary.fabricType!),
              _buildMiniDetail('Pieces recorded', summary.pieceCount.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildMasterCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Default master',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Provide either the master ID or name. This master is used when custom assignments are disabled.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _buildMasterFields(),
            if (_supportsAssignments)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use custom size assignments'),
                subtitle: const Text('Assign different masters per size'),
                value: _useCustomAssignments,
                onChanged: _toggleAssignments,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionalMasterFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Optional master override',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          'Provide master details if you want to record who processed this stage.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _buildMasterFields(),
      ],
    );
  }

  Widget _buildMasterFields() {
    return Column(
      children: [
        TextFormField(
          controller: _masterIdCtrl,
          decoration: const InputDecoration(labelText: 'Master ID'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _masterNameCtrl,
          decoration: const InputDecoration(labelText: 'Master name'),
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _buildAssignmentsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_requiresMaster)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Custom size assignments'),
                subtitle: const Text('Specify size IDs or labels manually'),
                value: _useCustomAssignments,
                onChanged: _toggleAssignments,
              ),
            if (_useCustomAssignments) ...[
              Text(
                'Assignments',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _assignments.length,
                itemBuilder: (context, index) {
                  final assignment = _assignments[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _AssignmentRow(
                      index: index,
                      data: assignment,
                      requiresMaster: _requiresMaster,
                      onRemove: () => _removeAssignment(index),
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add assignment'),
                  onPressed: _addAssignment,
                ),
              ),
            ],
            if (!_useCustomAssignments)
              Text(
                'Assignments will mirror all lot sizes automatically.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rejected piece codes',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Separate codes with commas or new lines. Each code will be recorded as rejected for this stage.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rejectedCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. P001, P002, P003',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemarkCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remark (optional)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _remarkCtrl,
              decoration: const InputDecoration(
                hintText: 'Add notes for this submission (max 255 characters).',
                alignLabelWithHint: true,
              ),
              maxLength: 255,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    final data = _lastResult!.data;
    return Card(
      color: theme.colorScheme.primary.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server response',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: data.entries.map((entry) {
                final value = entry.value;
                final text = value is Iterable
                    ? value.join(', ')
                    : value?.toString() ?? '';
                return _buildMiniDetail(entry.key, text);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntriesTab(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingEntries) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entriesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _entriesError!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _loadEntries,
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No entries recorded yet for this stage.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadEntries,
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemBuilder: (context, index) {
            final entry = _entries[index];
            return _buildEntryCard(theme, entry);
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: _entries.length,
        ),
      ),
    );
  }

  Widget _buildEntryCard(ThemeData theme, ProductionFlowEntry entry) {
    final chips = <Widget>[
      _buildInfoChip(theme, 'Status', entry.eventStatus ?? 'open'),
      _buildInfoChip(theme, 'Closed', entry.isClosed ? 'Yes' : 'No'),
      if (entry.masterName != null && entry.masterName!.isNotEmpty)
        _buildInfoChip(theme, 'Master', entry.masterName!),
      if (entry.bundleCode != null && entry.bundleCode!.isNotEmpty)
        _buildInfoChip(theme, 'Bundle', entry.bundleCode!),
      if (entry.lotNumber != null && entry.lotNumber!.isNotEmpty)
        _buildInfoChip(theme, 'Lot', entry.lotNumber!),
      if (entry.pieceCode != null && entry.pieceCode!.isNotEmpty)
        _buildInfoChip(theme, 'Piece', entry.pieceCode!),
      _buildInfoChip(theme, 'Created', _formatDate(entry.createdAt)),
      if (entry.closedAt != null)
        _buildInfoChip(theme, 'Closed at', _formatDate(entry.closedAt)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.codeValue,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  entry.codeType,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
            if (entry.remark != null && entry.remark!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Remark: ${entry.remark}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (entry.closedByStage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Closed by ${entry.closedByStage} ${entry.closedByUserUsername ?? ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(ThemeData theme, String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.6),
    );
  }
}

class _AssignmentField {
  final TextEditingController sizeIdCtrl = TextEditingController();
  final TextEditingController sizeLabelCtrl = TextEditingController();
  final TextEditingController masterIdCtrl = TextEditingController();
  final TextEditingController masterNameCtrl = TextEditingController();

  void dispose() {
    sizeIdCtrl.dispose();
    sizeLabelCtrl.dispose();
    masterIdCtrl.dispose();
    masterNameCtrl.dispose();
  }
}

class _AssignmentRow extends StatelessWidget {
  final int index;
  final _AssignmentField data;
  final bool requiresMaster;
  final VoidCallback onRemove;

  const _AssignmentRow({
    required this.index,
    required this.data,
    required this.requiresMaster,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assignment ${index + 1}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                tooltip: 'Remove assignment',
                icon: const Icon(Icons.delete_outline),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: data.sizeIdCtrl,
                  decoration: const InputDecoration(labelText: 'Size ID'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: data.sizeLabelCtrl,
                  decoration: const InputDecoration(labelText: 'Size label'),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: data.masterIdCtrl,
                  decoration: InputDecoration(
                    labelText: requiresMaster ? 'Master ID *' : 'Master ID',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: data.masterNameCtrl,
                  decoration: InputDecoration(
                    labelText: requiresMaster ? 'Master name *' : 'Master name',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

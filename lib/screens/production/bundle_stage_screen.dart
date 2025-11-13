import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/master.dart';
import '../../services/api_client.dart';
import '../../services/api_service.dart';
import '../../state/auth_controller.dart';
import '../../utils/ui_helpers.dart';

class BundleStageScreen extends StatefulWidget {
  final String title;
  final String codeLabel;
  final bool allowMaster;
  final bool allowRejectedPieces;
  final bool allowRemark;

  const BundleStageScreen({
    super.key,
    required this.title,
    required this.codeLabel,
    this.allowMaster = false,
    this.allowRejectedPieces = false,
    this.allowRemark = true,
  });

  @override
  State<BundleStageScreen> createState() => _BundleStageScreenState();
}

class _BundleStageScreenState extends State<BundleStageScreen> {
  final _codeCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final _rejectionCtrl = TextEditingController();
  List<MasterInfo> _masters = const [];
  int? _selectedMasterId;
  bool _loadingMasters = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.allowMaster) {
      _loadMasters();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _remarkCtrl.dispose();
    _rejectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() => _loadingMasters = true);
    final api = context.read<ApiService>();
    try {
      final masters = await api.fetchMasters();
      if (!mounted) return;
      setState(() {
        _masters = masters;
      });
    } catch (error) {
      showErrorSnackBar(context, error);
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    } finally {
      if (mounted) setState(() => _loadingMasters = false);
    }
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      showErrorSnackBar(context, ApiException('${widget.codeLabel} is required.'));
      return;
    }
    final rejectedPieces = widget.allowRejectedPieces
        ? _rejectionCtrl.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    setState(() => _submitting = true);
    final api = context.read<ApiService>();
    try {
      final payload = {
        'code': code,
        if (widget.allowMaster && _selectedMasterId != null) 'masterId': _selectedMasterId,
        if (widget.allowRemark && _remarkCtrl.text.trim().isNotEmpty) 'remark': _remarkCtrl.text.trim(),
        if (widget.allowRejectedPieces && rejectedPieces.isNotEmpty)
          'rejectedPieces': rejectedPieces,
      };
      final response = await api.submitProductionEntry(payload);
      if (!mounted) return;
      await showSuccessDialog(
        context,
        title: '${widget.title} recorded',
        content: Text(response['message']?.toString() ?? 'Entry saved successfully.'),
      );
      _codeCtrl.clear();
      _remarkCtrl.clear();
      _rejectionCtrl.clear();
      setState(() => _selectedMasterId = null);
    } catch (error) {
      showErrorSnackBar(context, error);
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            controller: _codeCtrl,
            decoration: InputDecoration(labelText: widget.codeLabel),
          ),
          if (widget.allowMaster)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _loadingMasters
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<int?>(
                      value: _selectedMasterId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Select master')),
                        ..._masters.map(
                          (master) => DropdownMenuItem<int?>(
                            value: master.id,
                            child: Text(master.masterName),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _selectedMasterId = value),
                      decoration: const InputDecoration(labelText: 'Master'),
                    ),
            ),
          if (widget.allowRemark)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextField(
                controller: _remarkCtrl,
                decoration: const InputDecoration(labelText: 'Remark (optional)'),
              ),
            ),
          if (widget.allowRejectedPieces)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextField(
                controller: _rejectionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rejected pieces (comma separated)',
                ),
              ),
            ),
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
                  : const Icon(Icons.task_alt),
              label: Text(_submitting ? 'Submitting...' : 'Submit'),
            ),
          ),
        ],
      ),
    );
  }
}

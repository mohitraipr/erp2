import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/api_service.dart';
import '../../state/auth_controller.dart';
import '../../utils/ui_helpers.dart';

class LotStageScreen extends StatefulWidget {
  final String title;
  final String codeLabel;
  final bool allowRemark;

  const LotStageScreen({
    super.key,
    required this.title,
    required this.codeLabel,
    this.allowRemark = true,
  });

  @override
  State<LotStageScreen> createState() => _LotStageScreenState();
}

class _LotStageScreenState extends State<LotStageScreen> {
  final _codeCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      showErrorSnackBar(context, ApiException('${widget.codeLabel} is required.'));
      return;
    }
    setState(() => _submitting = true);
    final api = context.read<ApiService>();
    try {
      final payload = {
        'code': code,
        if (widget.allowRemark && _remarkCtrl.text.trim().isNotEmpty)
          'remark': _remarkCtrl.text.trim(),
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
          if (widget.allowRemark)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextField(
                controller: _remarkCtrl,
                decoration: const InputDecoration(labelText: 'Remark (optional)'),
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

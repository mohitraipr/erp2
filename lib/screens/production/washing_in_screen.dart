import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/api_service.dart';
import '../../state/auth_controller.dart';
import '../../utils/ui_helpers.dart';

class WashingInScreen extends StatefulWidget {
  const WashingInScreen({super.key});

  @override
  State<WashingInScreen> createState() => _WashingInScreenState();
}

class _WashingInScreenState extends State<WashingInScreen> {
  final _pieceCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final _rejectionCtrl = TextEditingController();
  bool _rejectionMode = false;
  bool _submitting = false;

  @override
  void dispose() {
    _pieceCtrl.dispose();
    _remarkCtrl.dispose();
    _rejectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final api = context.read<ApiService>();
    try {
      Map<String, dynamic> payload;
      if (_rejectionMode) {
        final pieces = _rejectionCtrl.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (pieces.isEmpty) {
          throw const ApiException('Enter at least one rejected piece code.');
        }
        payload = {
          'rejectedPieces': pieces,
          if (_remarkCtrl.text.trim().isNotEmpty) 'remark': _remarkCtrl.text.trim(),
        };
      } else {
        final code = _pieceCtrl.text.trim();
        if (code.isEmpty) {
          throw const ApiException('Piece code is required.');
        }
        payload = {
          'code': code,
          if (_remarkCtrl.text.trim().isNotEmpty) 'remark': _remarkCtrl.text.trim(),
        };
      }

      final response = await api.submitProductionEntry(payload);
      if (!mounted) return;
      await showSuccessDialog(
        context,
        title: 'Washing In recorded',
        content: Text(response['message']?.toString() ?? 'Entry saved successfully.'),
      );
      _pieceCtrl.clear();
      _remarkCtrl.clear();
      _rejectionCtrl.clear();
    } on ApiException catch (error) {
      showErrorSnackBar(context, error);
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    } catch (error) {
      showErrorSnackBar(context, error);
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
          Text('Washing In', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _rejectionMode,
            onChanged: (value) => setState(() => _rejectionMode = value),
            title: const Text('Rejection mode'),
            subtitle: const Text('Toggle to record rejected pieces instead of single entry'),
          ),
          const SizedBox(height: 12),
          if (_rejectionMode)
            TextField(
              controller: _rejectionCtrl,
              decoration: const InputDecoration(
                labelText: 'Rejected piece codes (comma separated)',
              ),
            )
          else
            TextField(
              controller: _pieceCtrl,
              decoration: const InputDecoration(labelText: 'Piece code'),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _remarkCtrl,
            decoration: const InputDecoration(labelText: 'Remark (optional)'),
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

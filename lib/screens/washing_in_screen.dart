import 'package:flutter/material.dart';

import '../providers/providers.dart';
import '../services/api_service.dart';
import '../state/simple_riverpod.dart';

class WashingInScreen extends ConsumerStatefulWidget {
  const WashingInScreen({super.key});

  @override
  ConsumerState<WashingInScreen> createState() => _WashingInScreenState();
}

class _WashingInScreenState extends ConsumerState<WashingInScreen>
    with SingleTickerProviderStateMixin {
  final _pieceController = TextEditingController();
  final _returnRemarkController = TextEditingController();
  final _rejectedController = TextEditingController();
  final _rejectRemarkController = TextEditingController();

  @override
  void dispose() {
    _pieceController.dispose();
    _returnRemarkController.dispose();
    _rejectedController.dispose();
    _rejectRemarkController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget buildWithRef(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Washing-in'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Return piece'),
              Tab(text: 'Rejected pieces'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildReturnPiece(context),
            _buildRejectedPieces(context),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnPiece(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _pieceController,
            decoration: const InputDecoration(
              labelText: 'Piece code',
              hintText: 'Enter piece code (e.g. AK3p1)',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _returnRemarkController,
            decoration: const InputDecoration(labelText: 'Remark'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitSinglePiece,
              icon: const Icon(Icons.check),
              label: const Text('Register return'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedPieces(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _rejectedController,
            decoration: const InputDecoration(
              labelText: 'Rejected piece codes',
              hintText: 'Comma or newline separated codes',
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _rejectRemarkController,
            decoration: const InputDecoration(labelText: 'Remark'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitRejectedPieces,
              icon: const Icon(Icons.report),
              label: const Text('Report rejections'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSinglePiece() async {
    final code = _pieceController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter piece code.')),
      );
      return;
    }

    try {
      final response = await performApiCall(
        ref,
        (repo) => repo.submitProductionEntry(
          ProductionAssignmentPayload(
            code: code,
            assignments: const [],
            remark: _returnRemarkController.text.trim().isEmpty
                ? null
                : _returnRemarkController.text.trim(),
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Piece ${response.data['pieceCode'] ?? code} recorded at ${response.stage}.',
          ),
        ),
      );
      _pieceController.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _submitRejectedPieces() async {
    final codes = _rejectedController.text
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (codes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one piece code.')),
      );
      return;
    }

    try {
      final response = await performApiCall(
        ref,
        (repo) => repo.submitProductionEntry(
          ProductionAssignmentPayload(
            code: '',
            assignments: const [],
            rejectedPieces: codes,
            remark: _rejectRemarkController.text.trim().isEmpty
                ? null
                : _rejectRemarkController.text.trim(),
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${response.data['rejectionInserted'] ?? codes.length} pieces marked rejected.',
          ),
        ),
      );
      _rejectedController.clear();
      _rejectRemarkController.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

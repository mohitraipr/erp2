import 'package:flutter/material.dart';

import '../models/api_lot.dart';
import '../models/master.dart';
import '../providers/data_providers.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';
import '../state/simple_riverpod.dart';

class PatternAssignmentScreen extends ConsumerStatefulWidget {
  const PatternAssignmentScreen({super.key});

  @override
  ConsumerState<PatternAssignmentScreen> createState() =>
      _PatternAssignmentScreenState();
}

class _PatternAssignmentScreenState
    extends ConsumerState<PatternAssignmentScreen> {
  final _lotController = TextEditingController();
  ApiLot? _lot;
  bool _loadingLot = false;
  final Map<String, Map<int, int?>> _assignments = {};

  @override
  void dispose() {
    _lotController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget buildWithRef(BuildContext context, WidgetRef ref) {
    final mastersAsync = ref.watch(mastersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pattern assignments'),
        actions: [
          IconButton(
            onPressed: () => ref.refresh(mastersProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lotController,
                    decoration: const InputDecoration(
                      labelText: 'Lot number',
                      hintText: 'Enter lot number (e.g. AK3)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadingLot ? null : _loadLot,
                  icon: _loadingLot
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Load lot'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            mastersAsync.when(
              data: (masters) {
                if (_lot == null) {
                  return const Expanded(
                    child: Center(child: Text('Load a lot to assign patterns.')),
                  );
                }
                return Expanded(
                  child: ListView(
                    children: [
                      Card(
                        child: ListTile(
                          title: Text(_lot!.lotNumber),
                          subtitle: Text('${_lot!.sku} • ${_lot!.fabricType}'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._lot!.sizes.map(
                        (size) {
                          final patternCount = size.patternCount ?? 0;
                          final sizeAssignments =
                              _assignments[size.sizeLabel] ??= {};
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Size ${size.sizeLabel}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (int patternNo = 1;
                                          patternNo <= patternCount;
                                          patternNo++)
                                        _PatternAssignmentChip(
                                          patternNo: patternNo,
                                          masters: masters,
                                          selectedMasterId:
                                              sizeAssignments[patternNo],
                                          onChanged: (value) {
                                            setState(() {
                                              sizeAssignments[patternNo] = value;
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ).toList(),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitAssignments,
                          icon: const Icon(Icons.send),
                          label: const Text('Submit assignments'),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Expanded(
                child: Center(child: Text(error.toString())),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadLot() async {
    final lotCode = _lotController.text.trim();
    if (lotCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a lot number.')),
      );
      return;
    }

    setState(() {
      _loadingLot = true;
      _lot = null;
      _assignments.clear();
    });

    try {
      final lots = await performApiCall(ref, (repo) => repo.getLots());
      final match = lots.firstWhere(
        (lot) => lot.lotNumber.toUpperCase() == lotCode.toUpperCase(),
        orElse: () => throw ApiException('Lot $lotCode not found.'),
      );
      final lotDetail =
          await performApiCall(ref, (repo) => repo.getLotDetail(match.id));
      setState(() {
        _lot = lotDetail;
        _assignments.clear();
      });
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingLot = false;
        });
      }
    }
  }

  Future<void> _submitAssignments() async {
    if (_lot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load a lot first.')),
      );
      return;
    }

    final assignments = <Map<String, dynamic>>[];
    for (final size in _lot!.sizes) {
      final sizeAssignments = _assignments[size.sizeLabel] ?? {};
      final patternCount = size.patternCount ?? 0;
      for (int patternNo = 1; patternNo <= patternCount; patternNo++) {
        final masterId = sizeAssignments[patternNo];
        if (masterId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Select a master for pattern $patternNo in size ${size.sizeLabel}.',
              ),
            ),
          );
          return;
        }
        assignments.add({
          'sizeLabel': size.sizeLabel,
          'patternNos': [patternNo],
          'masterId': masterId,
        });
      }
    }

    try {
      final response = await performApiCall(
        ref,
        (repo) => repo.submitProductionEntry(
          ProductionAssignmentPayload(
            code: _lot!.lotNumber,
            assignments: assignments,
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assignments saved for stage ${response.stage}.')),
      );
      setState(() {
        _assignments.clear();
        _lot = null;
        _lotController.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

class _PatternAssignmentChip extends StatelessWidget {
  const _PatternAssignmentChip({
    required this.patternNo,
    required this.masters,
    required this.selectedMasterId,
    required this.onChanged,
  });

  final int patternNo;
  final List<MasterRecord> masters;
  final int? selectedMasterId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<int>(
        value: selectedMasterId,
        decoration: InputDecoration(
          labelText: 'Pattern $patternNo',
        ),
        items: masters
            .map(
              (master) => DropdownMenuItem<int>(
                value: master.id,
                child: Text(master.masterName),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

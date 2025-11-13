import 'package:flutter/material.dart';

import '../models/fabric_roll.dart';
import '../providers/data_providers.dart';
import '../providers/providers.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../widgets/async_value_widget.dart';
import 'lot_detail_screen.dart';
import '../state/simple_riverpod.dart';

class CuttingManagerCreateLotScreen extends ConsumerStatefulWidget {
  const CuttingManagerCreateLotScreen({super.key});

  @override
  ConsumerState<CuttingManagerCreateLotScreen> createState() =>
      _CuttingManagerCreateLotScreenState();
}

class _CuttingManagerCreateLotScreenState
    extends ConsumerState<CuttingManagerCreateLotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _bundleSizeController = TextEditingController(text: '10');
  final _remarkController = TextEditingController();
  String? _selectedFabric;
  final List<_SizeRow> _sizes = [
    _SizeRow(sizeLabelController: TextEditingController(), patternController: TextEditingController()),
  ];
  final List<_RollRow> _rolls = [
    _RollRow(
      rollController: TextEditingController(),
      weightController: TextEditingController(),
      layersController: TextEditingController(),
    ),
  ];

  @override
  void dispose() {
    _skuController.dispose();
    _bundleSizeController.dispose();
    _remarkController.dispose();
    for (final row in _sizes) {
      row.dispose();
    }
    for (final row in _rolls) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget buildWithRef(BuildContext context, WidgetRef ref) {
    final fabricRollsAsync = ref.watch(fabricRollsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create lot'),
      ),
      body: AsyncValueWidget<Map<String, List<FabricRoll>>>(
        value: fabricRollsAsync,
        onRetry: () => ref.refresh(fabricRollsProvider),
        builder: (fabricRolls) {
          final fabricTypes = fabricRolls.keys.toList()..sort();
          final availableRolls = _selectedFabric != null
              ? fabricRolls[_selectedFabric!] ?? const []
              : const <FabricRoll>[];

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lot information',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _skuController,
                            decoration: const InputDecoration(
                              labelText: 'SKU',
                              hintText: 'Enter SKU code',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'SKU is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedFabric,
                            decoration: const InputDecoration(
                              labelText: 'Fabric type',
                            ),
                            items: fabricTypes
                                .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedFabric = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Select fabric type';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _bundleSizeController,
                            decoration: const InputDecoration(
                              labelText: 'Bundle size',
                              hintText: 'Enter bundle size',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final parsed = int.tryParse(value ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'Bundle size must be a positive number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _remarkController,
                            decoration: const InputDecoration(
                              labelText: 'Remark',
                              hintText: 'Optional note',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSizesSection(context),
                  const SizedBox(height: 16),
                  _buildRollsSection(context, availableRolls),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _submit(context),
                      icon: const Icon(Icons.check),
                      label: const Text('Create lot'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSizesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sizes', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _sizes.add(
                        _SizeRow(
                          sizeLabelController: TextEditingController(),
                          patternController: TextEditingController(),
                        ),
                      );
                    });
                  },
                  icon: const Icon(Icons.add),
                  tooltip: 'Add size',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                for (int index = 0; index < _sizes.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _sizes[index].sizeLabelController,
                            decoration: const InputDecoration(labelText: 'Size label'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _sizes[index].patternController,
                            decoration: const InputDecoration(labelText: 'Patterns'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final parsed = int.tryParse(value ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'Positive number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _sizes.length <= 1
                              ? null
                              : () {
                                  setState(() {
                                    final removed = _sizes.removeAt(index);
                                    removed.dispose();
                                  });
                                },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRollsSection(
    BuildContext context,
    List<FabricRoll> availableRolls,
  ) {
    final rollNumbers = availableRolls.map((e) => e.rollNo).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fabric rolls',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _rolls.add(
                        _RollRow(
                          rollController: TextEditingController(),
                          weightController: TextEditingController(),
                          layersController: TextEditingController(),
                        ),
                      );
                    });
                  },
                  icon: const Icon(Icons.add),
                  tooltip: 'Add roll',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                for (int index = 0; index < _rolls.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _rolls[index].rollController.text.isEmpty
                                ? null
                                : _rolls[index].rollController.text,
                            items: rollNumbers
                                .map(
                                  (rollNo) => DropdownMenuItem(
                                    value: rollNo,
                                    child: Text(rollNo),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _rolls[index].rollController.text = value ?? '';
                              });
                            },
                            decoration: const InputDecoration(labelText: 'Roll number'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Select roll';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _rolls[index].weightController,
                            decoration: const InputDecoration(labelText: 'Weight used (kg)'),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              final parsed = double.tryParse(value ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'Enter weight';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _rolls[index].layersController,
                            decoration: const InputDecoration(labelText: 'Layers'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final parsed = int.tryParse(value ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'Enter layers';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _rolls.length <= 1
                              ? null
                              : () {
                                  setState(() {
                                    final removed = _rolls.removeAt(index);
                                    removed.dispose();
                                  });
                                },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedFabric == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select fabric type before submitting.')),
      );
      return;
    }

    final bundleSize = int.parse(_bundleSizeController.text);
    final payload = LotCreationPayload(
      sku: _skuController.text.trim(),
      fabricType: _selectedFabric!,
      bundleSize: bundleSize,
      remark: _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
      sizes: _sizes
          .map(
            (row) => LotSizePayload(
              sizeLabel: row.sizeLabelController.text.trim(),
              patternCount: int.parse(row.patternController.text.trim()),
            ),
          )
          .toList(),
      rolls: _rolls
          .map(
            (row) => LotRollPayload(
              rollNo: row.rollController.text.trim(),
              weightUsed: double.parse(row.weightController.text.trim()),
              layers: int.parse(row.layersController.text.trim()),
            ),
          )
          .toList(),
    );

    try {
      final lot = await performApiCall(ref, (repo) => repo.createLot(payload));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lot created'),
          content: Text('Lot ${lot.lotNumber} was created successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LotDetailScreen(
                      lotId: lot.id,
                      lotNumber: lot.lotNumber,
                      canDownload: true,
                    ),
                  ),
                );
              },
              child: const Text('View details'),
            ),
          ],
        ),
      );
      _formKey.currentState!.reset();
      ref.invalidate(lotsProvider);
      setState(() {
        _selectedFabric = null;
        _sizes
          ..forEach((row) => row.dispose())
          ..clear()
          ..add(
            _SizeRow(
              sizeLabelController: TextEditingController(),
              patternController: TextEditingController(),
            ),
          );
        _rolls
          ..forEach((row) => row.dispose())
          ..clear()
          ..add(
            _RollRow(
              rollController: TextEditingController(),
              weightController: TextEditingController(),
              layersController: TextEditingController(),
            ),
          );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

class _SizeRow {
  _SizeRow({
    required this.sizeLabelController,
    required this.patternController,
  });

  final TextEditingController sizeLabelController;
  final TextEditingController patternController;

  void dispose() {
    sizeLabelController.dispose();
    patternController.dispose();
  }
}

class _RollRow {
  _RollRow({
    required this.rollController,
    required this.weightController,
    required this.layersController,
  });

  final TextEditingController rollController;
  final TextEditingController weightController;
  final TextEditingController layersController;

  void dispose() {
    rollController.dispose();
    weightController.dispose();
    layersController.dispose();
  }
}

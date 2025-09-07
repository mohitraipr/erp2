import 'package:flutter/material.dart';
import '../models/login_response.dart';
import '../models/fabric_roll.dart';
import '../services/api_service.dart';
import 'login_page.dart';

class ResponsePage extends StatefulWidget {
  static const routeName = '/response';
  final LoginResponse data;
  final ApiService api;
  const ResponsePage({super.key, required this.data, required this.api});

  @override
  State<ResponsePage> createState() => _ResponsePageState();
}

class RollSelection {
  final FabricRoll roll;
  final TextEditingController weightCtrl = TextEditingController();
  RollSelection(this.roll);

  void dispose() => weightCtrl.dispose();
}

class _ResponsePageState extends State<ResponsePage> {
  Map<String, List<FabricRoll>> _rollsByType = {};
  String? _selectedFabric;
  final List<RollSelection> _selectedRolls = [];
  TextEditingController? _fabricCtrl;
  TextEditingController? _rollCtrl;
  bool _loading = true;
  String? _error;

  bool get _isCuttingManager {
    final role = widget.data.role.toLowerCase().replaceAll('_', ' ');
    return role == 'cutting manager';
  }

  @override
  void initState() {
    super.initState();
    if (_isCuttingManager) {
      _loadRolls();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadRolls() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.fetchFabricRolls();
      setState(() {
        _rollsByType = data;
      });
    } on ApiException catch (e) {
      debugPrint('Failed to load fabric rolls: $e');
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    // The controllers provided by the Autocomplete widgets are managed
    // internally by Flutter, so we should not dispose them ourselves.
    // Only dispose the controllers we explicitly created.
    for (final r in _selectedRolls) {
      r.dispose();
    }
    widget.api.dispose();
    super.dispose();
  }

  void _logout() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (!_isCuttingManager) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${widget.data.username}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Role: ${widget.data.role}'),
        ],
      );
    } else if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      content = Center(child: Text(_error!));
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${widget.data.username}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              final q = textEditingValue.text.toLowerCase();
              final types = _rollsByType.keys.toList()..sort();
              if (q.isEmpty) return types;
              return types.where((t) => t.toLowerCase().contains(q));
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              _fabricCtrl ??= controller;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Search fabric type',
                  border: OutlineInputBorder(),
                ),
              );
            },
            onSelected: (v) {
              setState(() {
                _selectedFabric = v;
                for (final r in _selectedRolls) {
                  r.dispose();
                }
                _selectedRolls.clear();
                _rollCtrl?.clear();
              });
            },
          ),
          const SizedBox(height: 16),
          if (_selectedFabric != null) ...[
            Autocomplete<FabricRoll>(
              displayStringForOption: (r) => r.rollNo,
              optionsBuilder: (TextEditingValue textEditingValue) {
                final q = textEditingValue.text.toLowerCase();
                final rolls = _rollsByType[_selectedFabric]!;
                if (q.isEmpty) return rolls;
                return rolls
                    .where((r) => r.rollNo.toLowerCase().contains(q))
                    .toList();
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                _rollCtrl ??= controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Search roll number',
                    border: OutlineInputBorder(),
                  ),
                );
              },
              onSelected: (r) {
                setState(() {
                  if (_selectedRolls
                      .any((sel) => sel.roll.rollNo == r.rollNo)) return;
                  _selectedRolls.add(RollSelection(r));
                  _rollCtrl?.clear();
                });
                FocusScope.of(context).unfocus();
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Selected Rolls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _selectedRolls.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final sel = _selectedRolls[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Roll ${sel.roll.rollNo}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Available: ${sel.roll.perRollWeight} ${sel.roll.unit}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: sel.weightCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Weight',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                final w = double.tryParse(v) ?? 0;
                                if (w > sel.roll.perRollWeight) {
                                  sel.weightCtrl.text =
                                      sel.roll.perRollWeight.toString();
                                  sel.weightCtrl.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                        offset: sel.weightCtrl.text.length),
                                  );
                                }
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove roll',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                sel.dispose();
                                _selectedRolls.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}

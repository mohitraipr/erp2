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

class _ResponsePageState extends State<ResponsePage> {
  Map<String, List<FabricRoll>> _rollsByType = {};
  String? _selectedFabric;
  final Set<String> _selectedRolls = {};
  final TextEditingController _searchCtrl = TextEditingController();
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
      _searchCtrl.addListener(() => setState(() {}));
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
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  List<String> get _filteredTypes {
    final q = _searchCtrl.text.toLowerCase();
    final types = _rollsByType.keys.toList()..sort();
    if (q.isEmpty) return types;
    return types.where((t) => t.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              labelText: 'Search fabric type',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButton<String>(
            isExpanded: true,
            hint: const Text('Select fabric type'),
            value: _filteredTypes.contains(_selectedFabric)
                ? _selectedFabric
                : null,
            items: _filteredTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedFabric = v;
                _selectedRolls.clear();
              });
            },
          ),
          const SizedBox(height: 16),
          if (_selectedFabric != null)
            Expanded(
              child: ListView(
                children: _rollsByType[_selectedFabric]!
                    .map(
                      (r) => CheckboxListTile(
                        title: Text(
                          'Roll ${r.rollNo} (${r.perRollWeight} ${r.unit})',
                        ),
                        subtitle: Text(r.vendorName),
                        value: _selectedRolls.contains(r.rollNo),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedRolls.add(r.rollNo);
                            } else {
                              _selectedRolls.remove(r.rollNo);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
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

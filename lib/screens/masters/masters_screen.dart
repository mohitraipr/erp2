import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/master.dart';
import '../../services/api_client.dart';

class MastersScreen extends StatefulWidget {
  const MastersScreen({super.key});

  @override
  State<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends State<MastersScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  List<Master> _masters = [];
  bool _loading = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMasters());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() => _loading = true);
    final api = context.read<ApiClient>();
    try {
      final masters = await api.fetchMasters();
      if (!mounted) return;
      setState(() => _masters = masters);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createMaster() async {
    if (_creating) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _creating = true);
    final api = context.read<ApiClient>();
    try {
      final master = await api.createMaster(
        name: _nameCtrl.text.trim(),
        contactNumber: _contactCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _masters = [master, ..._masters];
        _nameCtrl.clear();
        _contactCtrl.clear();
        _notesCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Master ${master.name} created.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFormCard(context),
        const SizedBox(height: 12),
        Expanded(child: _buildMastersList()),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register master',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Master name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _contactCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Contact number'),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _creating ? null : _createMaster,
                  icon: _creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: Text(_creating ? 'Creating…' : 'Create master'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMastersList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_masters.isEmpty) {
      return const Center(child: Text('No masters registered yet.'));
    }
    return RefreshIndicator(
      onRefresh: _loadMasters,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _masters.length,
        itemBuilder: (context, index) {
          final master = _masters[index];
          return Card(
            child: ListTile(
              title: Text(master.name),
              subtitle: Text(
                [
                  if ((master.contactNumber ?? '').isNotEmpty)
                    'Contact: ${master.contactNumber}',
                  if ((master.notes ?? '').isNotEmpty) master.notes!,
                ].join(' • '),
              ),
              trailing:
                  Text(master.creatorRole ?? '', style: const TextStyle(fontSize: 12)),
            ),
          );
        },
      ),
    );
  }
}

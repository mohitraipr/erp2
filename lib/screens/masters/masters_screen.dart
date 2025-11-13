import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/master.dart';
import '../../services/api_client.dart';
import '../../services/api_service.dart';
import '../../state/auth_controller.dart';
import '../../utils/ui_helpers.dart';

class MastersScreen extends StatefulWidget {
  const MastersScreen({super.key});

  @override
  State<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends State<MastersScreen> {
  bool _loading = true;
  String? _error;
  List<MasterInfo> _masters = const [];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    try {
      final masters = await api.fetchMasters();
      if (!mounted) return;
      setState(() {
        _masters = masters;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
      }
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createMaster() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final api = context.read<ApiService>();
    try {
      final master = await api.createMaster(
        MasterPayload(
          name: _nameCtrl.text.trim(),
          contactNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _masters = [master, ..._masters];
      });
      _formKey.currentState!.reset();
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _notesCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Master created successfully.')),
      );
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
          Text('Masters', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _buildForm(),
          const SizedBox(height: 24),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Master', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Name is required'
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Contact Number'),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _submitting ? null : _createMaster,
                  child: Text(_submitting ? 'Saving...' : 'Create Master'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_masters.isEmpty) {
      return const Center(child: Text('No masters available yet.'));
    }
    return ListView.separated(
      itemCount: _masters.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final master = _masters[index];
        return ListTile(
          title: Text(master.masterName),
          subtitle: Text(master.notes ?? 'No notes'),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (master.contactNumber != null) Text(master.contactNumber!),
              if (master.creatorRole != null) Text('By ${master.creatorRole}'),
            ],
          ),
        );
      },
    );
  }
}

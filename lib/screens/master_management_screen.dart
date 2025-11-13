import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/master.dart';
import '../providers/data_providers.dart';
import '../providers/providers.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../widgets/async_value_widget.dart';

class MasterManagementScreen extends ConsumerStatefulWidget {
  const MasterManagementScreen({super.key});

  @override
  ConsumerState<MasterManagementScreen> createState() =>
      _MasterManagementScreenState();
}

class _MasterManagementScreenState
    extends ConsumerState<MasterManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mastersAsync = ref.watch(mastersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master management'),
        actions: [
          IconButton(
            onPressed: () => ref.refresh(mastersProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Create new master',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contactController,
                        decoration: const InputDecoration(labelText: 'Contact number'),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Contact number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(labelText: 'Notes'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _createMaster,
                          icon: const Icon(Icons.save),
                          label: const Text('Create master'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueWidget<List<MasterRecord>>(
              value: mastersAsync,
              onRetry: () => ref.refresh(mastersProvider),
              builder: (masters) {
                if (masters.isEmpty) {
                  return const Center(child: Text('No masters available.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final master = masters[index];
                    return Card(
                      child: ListTile(
                        title: Text(master.masterName),
                        subtitle: Text(master.contactNumber),
                        trailing: master.creatorRole != null
                            ? Chip(label: Text(master.creatorRole!))
                            : null,
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: masters.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createMaster() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await performApiCall(ref, (repo) => repo.createMaster(
            name: _nameController.text.trim(),
            contactNumber: _contactController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ));
      _formKey.currentState!.reset();
      _nameController.clear();
      _contactController.clear();
      _notesController.clear();
      ref.invalidate(mastersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Master created successfully.')),
        );
      }
    } on ConflictException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

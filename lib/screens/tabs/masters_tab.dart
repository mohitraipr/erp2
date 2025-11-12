import 'package:flutter/material.dart';

import '../../models/login_response.dart';
import '../../models/master.dart';
import '../../services/api_service.dart';

class MastersTab extends StatefulWidget {
  final ApiService api;
  final LoginResponse user;

  const MastersTab({super.key, required this.api, required this.user});

  @override
  State<MastersTab> createState() => _MastersTabState();
}

class _MastersTabState extends State<MastersTab> {
  bool _loading = false;
  bool _creating = false;
  String? _error;
  List<Master> _masters = const [];

  @override
  void initState() {
    super.initState();
    _fetchMasters();
  }

  Future<void> _fetchMasters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final masters = await widget.api.fetchMasters();
      if (!mounted) return;
      masters.sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _masters = masters;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _createMaster() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? error;

    final master = await showDialog<Master?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('New master'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact number (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Notes (optional)'),
                      maxLines: 3,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _creating
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            setStateDialog(() {
                              error = 'Name is required.';
                            });
                            return;
                          }
                          setState(() {
                            _creating = true;
                          });
                          setStateDialog(() {});
                          try {
                            final created = await widget.api.createMaster(
                              name: name,
                              contactNumber: phoneCtrl.text.trim().isEmpty
                                  ? null
                                  : phoneCtrl.text.trim(),
                              notes: notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop(created);
                          } on ApiException catch (e) {
                            setStateDialog(() {
                              error = e.message;
                            });
                          } finally {
                            setState(() {
                              _creating = false;
                            });
                            setStateDialog(() {});
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    if (master != null) {
      setState(() {
        final updated = List<Master>.from(_masters);
        final index = updated.indexWhere((m) => m.id == master.id);
        if (index >= 0) {
          updated[index] = master;
        } else {
          updated.add(master);
        }
        updated.sort((a, b) => a.name.compareTo(b.name));
        _masters = updated;
      });
    }

    nameCtrl.dispose();
    phoneCtrl.dispose();
    notesCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchMasters,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Masters',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Maintain your trusted artisans for quick assignment during production. '
            'Masters are scoped to your account.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _creating ? null : _createMaster,
              icon: const Icon(Icons.add),
              label: Text(_creating ? 'Creating…' : 'Add master'),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            )
          else if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ))
          else if (_masters.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No masters yet. Create your first master to speed up lot assignments.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ..._masters.map((master) => _MasterTile(master: master)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _MasterTile extends StatelessWidget {
  final Master master;

  const _MasterTile({required this.master});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.engineering,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    master.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (master.contactNumber != null && master.contactNumber!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.call, size: 18),
                  const SizedBox(width: 8),
                  Text(master.contactNumber!),
                ],
              ),
            if (master.notes != null && master.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(master.notes!),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (master.creatorRole != null)
                  Chip(label: Text(master.creatorRole!)),
                if (master.createdAt != null)
                  Chip(
                    label: Text(
                      'Created ${_formatDate(master.createdAt!)}',
                    ),
                  ),
                if (master.updatedAt != null &&
                    master.updatedAt != master.createdAt)
                  Chip(
                    label: Text(
                      'Updated ${_formatDate(master.updatedAt!)}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

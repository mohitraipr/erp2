import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/production_flow.dart';
import '../../services/api_client.dart';
import '../../services/api_service.dart';
import '../../state/auth_controller.dart';
import '../../utils/ui_helpers.dart';

class ProductionHistoryScreen extends StatefulWidget {
  const ProductionHistoryScreen({super.key});

  @override
  State<ProductionHistoryScreen> createState() => _ProductionHistoryScreenState();
}

class _ProductionHistoryScreenState extends State<ProductionHistoryScreen> {
  final stages = const [
    'back_pocket',
    'stitching_master',
    'jeans_assembly',
    'washing',
    'washing_in',
    'finishing',
  ];
  String? _selectedStage;
  bool _loading = false;
  String? _error;
  List<ProductionFlowEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    _selectedStage = stages.first;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    try {
      final data = await api.fetchProductionEntries(stage: _selectedStage, limit: 200);
      if (!mounted) return;
      setState(() {
        _events = data[_selectedStage] ?? const [];
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStage,
                  decoration: const InputDecoration(labelText: 'Stage'),
                  items: stages
                      .map((stage) => DropdownMenuItem(
                            value: stage,
                            child: Text(stage.replaceAll('_', ' ').toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedStage = value);
                    _load();
                  },
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _events.isEmpty
                      ? const Center(child: Text('No entries yet.'))
                      : ListView.separated(
                          itemCount: _events.length,
                          separatorBuilder: (_, __) => const Divider(height: 0),
                          itemBuilder: (context, index) {
                            final event = _events[index];
                            return ListTile(
                              title: Text(event.codeValue),
                              subtitle: Text('${event.stage} • ${event.lotNumber ?? ''}'),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (event.masterName != null) Text(event.masterName!),
                                  if (event.createdAt != null)
                                    Text(
                                      event.createdAt!.toLocal().toString(),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/production_flow.dart';
import '../../services/api_client.dart';

class ProductionHistoryScreen extends StatefulWidget {
  const ProductionHistoryScreen({super.key});

  @override
  State<ProductionHistoryScreen> createState() => _ProductionHistoryScreenState();
}

class _ProductionHistoryScreenState extends State<ProductionHistoryScreen> {
  ProductionStage? _stage = ProductionStage.jeansAssembly;
  int _limit = 100;
  bool _loading = false;
  List<ProductionFlowEvent> _events = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvents());
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    final api = context.read<ApiClient>();
    try {
      final events = await api.fetchProductionEvents(stage: _stage, limit: _limit);
      if (!mounted) return;
      setState(() => _events = events);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ProductionStage>(
                  value: _stage,
                  decoration: const InputDecoration(labelText: 'Stage'),
                  items: [
                    for (final stage in ProductionStage.values)
                      DropdownMenuItem(
                        value: stage,
                        child: Text(_stageLabel(stage)),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _stage = value);
                    _loadEvents();
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _limit,
                items: const [50, 100, 200, 500]
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text('Limit $value'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _limit = value);
                  _loadEvents();
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loadEvents,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _events.isEmpty
                  ? const Center(child: Text('No events found.'))
                  : RefreshIndicator(
                      onRefresh: _loadEvents,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              title: Text('${event.codeValue ?? event.bundleCode ?? event.pieceCode ?? '-'}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_stageLabel(event.stage)} • Lot ${event.lotNumber ?? '-'}'),
                                  if (event.masterName != null)
                                    Text('Master: ${event.masterName}'),
                                  if (event.remark != null && event.remark!.isNotEmpty)
                                    Text('Remark: ${event.remark}'),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(event.createdAt?.toLocal().toString() ?? ''),
                                  Text(event.eventStatus ?? (event.isClosed ? 'closed' : 'open')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  String _stageLabel(ProductionStage? stage) {
    if (stage == null) return 'All stages';
    switch (stage) {
      case ProductionStage.backPocket:
        return 'Back pocket';
      case ProductionStage.stitchingMaster:
        return 'Stitching';
      case ProductionStage.jeansAssembly:
        return 'Jeans assembly';
      case ProductionStage.washing:
        return 'Washing';
      case ProductionStage.washingIn:
        return 'Washing in';
      case ProductionStage.finishing:
        return 'Finishing';
    }
  }
}

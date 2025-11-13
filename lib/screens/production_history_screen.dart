import 'package:flutter/material.dart';

import '../models/production_flow.dart';
import '../providers/data_providers.dart';
import '../widgets/async_value_widget.dart';
import '../state/simple_riverpod.dart';

class ProductionHistoryScreen extends ConsumerStatefulWidget {
  const ProductionHistoryScreen({super.key});

  @override
  ConsumerState<ProductionHistoryScreen> createState() =>
      _ProductionHistoryScreenState();
}

class _ProductionHistoryScreenState
    extends ConsumerState<ProductionHistoryScreen> {
  String? _stage;

  static const Map<String, String> stageLabels = {
    'back_pocket': 'Back pocket',
    'stitching_master': 'Stitching master',
    'jeans_assembly': 'Jeans assembly',
    'washing': 'Washing',
    'washing_in': 'Washing in',
    'finishing': 'Finishing',
  };

  @override
  @override
  Widget buildWithRef(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(productionHistoryProvider(_stage));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Production history'),
        actions: [
          IconButton(
            onPressed: () => ref.refresh(productionHistoryProvider(_stage)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String?>(
              initialValue: _stage,
              decoration: const InputDecoration(
                labelText: 'Stage filter',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All stages')),
                ...stageLabels.entries.map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _stage = value;
                });
              },
            ),
          ),
          Expanded(
            child: AsyncValueWidget<List<ProductionFlowEvent>>(
              value: historyAsync,
              onRetry: () => ref.refresh(productionHistoryProvider(_stage)),
              builder: (events) {
                if (events.isEmpty) {
                  return const Center(child: Text('No events recorded.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(event.stage.substring(0, 1).toUpperCase()),
                        ),
                        title: Text('${event.stage} • ${event.codeValue}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (event.lotNumber != null)
                              Text('Lot ${event.lotNumber}'),
                            if (event.bundleCode != null)
                              Text('Bundle ${event.bundleCode}'),
                            if (event.sizeLabel != null)
                              Text('Size ${event.sizeLabel}'),
                            if (event.patternNo != null)
                              Text('Pattern ${event.patternNo}'),
                            if (event.masterName != null)
                              Text('Master ${event.masterName}'),
                            if (event.userUsername != null)
                              Text('User ${event.userUsername}'),
                            if (event.remark != null && event.remark!.isNotEmpty)
                              Text('Remark: ${event.remark}'),
                            Text('Status: ${event.eventStatus ?? (event.isClosed ? 'closed' : 'open')}'),
                          ],
                        ),
                        trailing: Text(
                          event.createdAt?.toLocal().toString() ?? '-',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: events.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

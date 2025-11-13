import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';
import 'cutting_manager/cutting_manager_screen.dart';
import 'masters/masters_screen.dart';
import 'operator_lots_screen.dart';
import 'production_flow/finishing_screen.dart';
import 'production_flow/jeans_assembly_screen.dart';
import 'production_flow/pattern_assignment_screen.dart';
import 'production_flow/production_history_screen.dart';
import 'production_flow/washing_in_screen.dart';
import 'production_flow/washing_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final destinations = _destinationsFor(session);
    if (_selectedIndex >= destinations.length) {
      _selectedIndex = 0;
    }
    final destination = destinations[_selectedIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;
        final navigation = useRail
            ? NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final dest in destinations)
                    NavigationRailDestination(
                      icon: Icon(dest.icon),
                      selectedIcon: Icon(dest.icon, color: Theme.of(context).colorScheme.primary),
                      label: Text(dest.label),
                    ),
                ],
              )
            : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(destination.label),
            actions: [
              IconButton(
                tooltip: 'Change backend URL',
                icon: const Icon(Icons.link),
                onPressed: () => _promptBaseUrl(context),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  await session.logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Row(
            children: [
              if (navigation != null) navigation,
              Expanded(child: destination.builder(context)),
            ],
          ),
          bottomNavigationBar: navigation == null
              ? NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                  destinations: [
                    for (final dest in destinations)
                      NavigationDestination(icon: Icon(dest.icon), label: dest.label),
                  ],
                )
              : null,
        );
      },
    );
  }

  Future<void> _promptBaseUrl(BuildContext context) async {
    final session = context.read<SessionController>();
    final controller = TextEditingController(text: session.baseUrl);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update backend URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Base URL',
            helperText: 'Include http(s) prefix',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed == true) {
      session.setBaseUrl(controller.text.trim());
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Backend URL updated.')));
    }
  }

  List<_HomeDestination> _destinationsFor(SessionController session) {
    final destinations = <_HomeDestination>[];

    if (session.isCuttingManager) {
      destinations.add(
        _HomeDestination(
          label: 'Cutting manager',
          icon: Icons.cut,
          builder: (context) => const CuttingManagerScreen(),
        ),
      );
    }
    if (session.isOperator) {
      destinations.add(
        _HomeDestination(
          label: 'Lots',
          icon: Icons.inventory_rounded,
          builder: (context) => const OperatorLotsScreen(),
        ),
      );
    }
    if (session.isBackPocketOrStitching) {
      destinations.add(
        _HomeDestination(
          label: 'Pattern assignments',
          icon: Icons.assignment,
          builder: (context) => const PatternAssignmentScreen(),
        ),
      );
    }
    if (session.isJeansAssembly) {
      destinations.add(
        _HomeDestination(
          label: 'Jeans assembly',
          icon: Icons.precision_manufacturing_outlined,
          builder: (context) => const JeansAssemblyScreen(),
        ),
      );
    }
    if (session.isWashing) {
      destinations.add(
        _HomeDestination(
          label: 'Washing',
          icon: Icons.water_drop_outlined,
          builder: (context) => const WashingScreen(),
        ),
      );
    }
    if (session.isWashingIn) {
      destinations.add(
        _HomeDestination(
          label: 'Washing-in',
          icon: Icons.local_laundry_service_outlined,
          builder: (context) => const WashingInScreen(),
        ),
      );
    }
    if (session.isFinishing) {
      destinations.add(
        _HomeDestination(
          label: 'Finishing',
          icon: Icons.done_all,
          builder: (context) => const FinishingScreen(),
        ),
      );
    }
    if (session.canManageMasters) {
      destinations.add(
        _HomeDestination(
          label: 'Masters',
          icon: Icons.groups_3_outlined,
          builder: (context) => const MastersScreen(),
        ),
      );
    }

    destinations.add(
      _HomeDestination(
        label: 'History',
        icon: Icons.history,
        builder: (context) => const ProductionHistoryScreen(),
      ),
    );

    if (destinations.isEmpty) {
      destinations.add(
        _HomeDestination(
          label: 'Lots',
          icon: Icons.inventory_rounded,
          builder: (context) => const OperatorLotsScreen(),
        ),
      );
    }
    return destinations;
  }
}

class _HomeDestination {
  const _HomeDestination({
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

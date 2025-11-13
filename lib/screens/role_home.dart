import 'package:flutter/material.dart';

import '../models/user.dart';
import '../providers/providers.dart';
import 'bundle_lookup_screen.dart';
import 'cutting_manager_create_lot_screen.dart';
import 'finishing_screen.dart';
import 'jeans_assembly_screen.dart';
import 'lots_list_screen.dart';
import 'master_management_screen.dart';
import 'pattern_assignment_screen.dart';
import 'production_history_screen.dart';
import 'washing_in_screen.dart';
import 'washing_screen.dart';
import '../state/simple_riverpod.dart';

class RoleHome extends ConsumerStatefulWidget {
  const RoleHome({super.key, required this.role, required this.user});

  final String role;
  final UserProfile user;

  @override
  ConsumerState<RoleHome> createState() => _RoleHomeState();
}

class _RoleHomeState extends ConsumerState<RoleHome>
    with SingleTickerProviderStateMixin {
  late List<_RoleTab> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs(widget.role);
  }

  @override
  void didUpdateWidget(RoleHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      setState(() {
        _tabs = _buildTabs(widget.role);
      });
    }
  }

  @override
  @override
  Widget buildWithRef(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: _tabs.length,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              'Welcome, ${widget.user.username}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            actions: [
              IconButton(
                onPressed: () {
                  ref.read(authControllerProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabs: _tabs
                  .map(
                    (tab) => Tab(
                      text: tab.label,
                      icon: Icon(tab.icon),
                    ),
                  )
                  .toList(),
            ),
          ),
          body: TabBarView(
            children: _tabs.map((tab) => tab.builder(context)).toList(),
          ),
        ),
      ),
    );
  }

  List<_RoleTab> _buildTabs(String role) {
    final normalized = role.toLowerCase();
    switch (normalized) {
      case 'cutting_manager':
        return [
          _RoleTab(
            id: 'createLot',
            label: 'Create lot',
            icon: Icons.add_box_outlined,
            builder: (_) => const CuttingManagerCreateLotScreen(),
          ),
          _RoleTab(
            id: 'lots',
            label: 'My lots',
            icon: Icons.inventory_2_outlined,
            builder: (_) => const LotsListScreen(canDownload: true),
          ),
          _historyTab(),
        ];
      case 'cutting_master':
      case 'operator':
        return [
          _RoleTab(
            id: 'lots',
            label: 'Lots',
            icon: Icons.inventory_2_outlined,
            builder: (_) => const LotsListScreen(),
          ),
          _historyTab(),
        ];
      case 'back_pocket':
      case 'stitching_master':
        return [
          _RoleTab(
            id: 'assignments',
            label: 'Assignments',
            icon: Icons.assignment_ind_outlined,
            builder: (_) => const PatternAssignmentScreen(),
          ),
          _RoleTab(
            id: 'masters',
            label: 'Masters',
            icon: Icons.groups_outlined,
            builder: (_) => const MasterManagementScreen(),
          ),
          _RoleTab(
            id: 'lookup',
            label: 'Bundle lookup',
            icon: Icons.qr_code_scanner,
            builder: (_) => const BundleLookupScreen(),
          ),
          _historyTab(),
        ];
      case 'jeans_assembly':
        return [
          _RoleTab(
            id: 'assembly',
            label: 'Assembly entry',
            icon: Icons.fact_check_outlined,
            builder: (_) => const JeansAssemblyScreen(),
          ),
          _RoleTab(
            id: 'masters',
            label: 'Masters',
            icon: Icons.groups_outlined,
            builder: (_) => const MasterManagementScreen(),
          ),
          _RoleTab(
            id: 'lookup',
            label: 'Bundle lookup',
            icon: Icons.qr_code_scanner,
            builder: (_) => const BundleLookupScreen(),
          ),
          _historyTab(),
        ];
      case 'washing':
        return [
          _RoleTab(
            id: 'washing',
            label: 'To washing',
            icon: Icons.local_laundry_service_outlined,
            builder: (_) => const WashingScreen(),
          ),
          _RoleTab(
            id: 'lookup',
            label: 'Bundle lookup',
            icon: Icons.qr_code_scanner,
            builder: (_) => const BundleLookupScreen(),
          ),
          _historyTab(),
        ];
      case 'washing_in':
        return [
          _RoleTab(
            id: 'washingIn',
            label: 'Washing in',
            icon: Icons.assignment_turned_in_outlined,
            builder: (_) => const WashingInScreen(),
          ),
          _RoleTab(
            id: 'lookup',
            label: 'Bundle lookup',
            icon: Icons.qr_code_scanner,
            builder: (_) => const BundleLookupScreen(),
          ),
          _historyTab(),
        ];
      case 'finishing':
        return [
          _RoleTab(
            id: 'finishing',
            label: 'Finishing',
            icon: Icons.task_alt_outlined,
            builder: (_) => const FinishingScreen(),
          ),
          _RoleTab(
            id: 'lookup',
            label: 'Bundle lookup',
            icon: Icons.qr_code_scanner,
            builder: (_) => const BundleLookupScreen(),
          ),
          _historyTab(),
        ];
      default:
        return [
          _RoleTab(
            id: 'lots',
            label: 'Lots',
            icon: Icons.inventory_2_outlined,
            builder: (_) => const LotsListScreen(),
          ),
          _historyTab(),
        ];
    }
  }

  _RoleTab _historyTab() {
    return _RoleTab(
      id: 'history',
      label: 'History',
      icon: Icons.history,
      builder: (_) => const ProductionHistoryScreen(),
    );
  }
}

class _RoleTab {
  const _RoleTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

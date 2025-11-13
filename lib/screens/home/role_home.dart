import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/login_response.dart';
import '../../screens/cutting_manager/create_lot_screen.dart';
import '../../screens/cutting_manager/lots_overview_screen.dart';
import '../../screens/masters/masters_screen.dart';
import '../../screens/production/bundle_stage_screen.dart';
import '../../screens/production/lot_stage_screen.dart';
import '../../screens/production/pattern_assignment_screen.dart';
import '../../screens/production/production_history_screen.dart';
import '../../screens/production/washing_in_screen.dart';
import '../../state/auth_controller.dart';
import '../login_page.dart';

class RoleHomePage extends StatefulWidget {
  const RoleHomePage({super.key});

  @override
  State<RoleHomePage> createState() => _RoleHomePageState();
}

class _RoleHomePageState extends State<RoleHomePage> with TickerProviderStateMixin {
  TabController? _controller;
  List<_DashboardTab> _tabs = const [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _tabs = _buildTabs(context.read<AuthController>().user);
      _controller = TabController(length: _tabs.length, vsync: this);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final username = user?.username ?? 'User';
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $username'),
        bottom: _tabs.isNotEmpty
            ? TabBar(
                controller: _controller,
                tabs: [
                  for (final tab in _tabs)
                    Tab(
                      text: tab.label,
                      icon: Icon(tab.icon),
                    ),
                ],
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _tabs.isEmpty
          ? const Center(child: Text('No dashboard configured for this role.'))
          : TabBarView(
              controller: _controller,
              children: [for (final tab in _tabs) tab.child],
            ),
    );
  }

  List<_DashboardTab> _buildTabs(LoginResponse? user) {
    final role = user?.normalizedRole ?? '';
    final tabs = <_DashboardTab>[];

    void addTab(String label, IconData icon, Widget child) {
      tabs.add(_DashboardTab(label: label, icon: icon, child: child));
    }

    switch (role) {
      case 'cutting_manager':
        addTab('Create Lot', Icons.playlist_add, const CreateLotScreen());
        addTab('My Lots', Icons.list_alt, const LotsOverviewScreen());
        addTab('Masters', Icons.groups, const MastersScreen());
        addTab('History', Icons.history, const ProductionHistoryScreen());
        break;
      case 'cutting_master':
        addTab('Lots', Icons.list, const LotsOverviewScreen());
        addTab('History', Icons.history, const ProductionHistoryScreen());
        break;
      case 'operator':
        addTab('Lots', Icons.list, const LotsOverviewScreen());
        addTab('History', Icons.history, const ProductionHistoryScreen());
        break;
      case 'back_pocket':
      case 'stitching_master':
        addTab('Assignments', Icons.assignment_ind, const PatternAssignmentScreen());
        addTab('Masters', Icons.groups, const MastersScreen());
        addTab('History', Icons.history, const ProductionHistoryScreen());
        break;
      case 'jeans_assembly':
        addTab(
          'Jeans Assembly',
          Icons.qr_code_scanner,
          const BundleStageScreen(
            title: 'Jeans Assembly',
            codeLabel: 'Bundle code',
            allowMaster: true,
            allowRejectedPieces: true,
          ),
        );
        addTab('Masters', Icons.groups, const MastersScreen());
        addTab('History', Icons.history, const ProductionHistoryScreen());
        break;
      case 'washing':
        addTab(
          'Washing',
          Icons.local_laundry_service,
          const LotStageScreen(
            title: 'Register for Washing',
            codeLabel: 'Lot number',
          ),
        );
        addTab('History', Icons.history, const ProductionHistoryScreen());
        break;
      case 'washing_in':
        addTab('Washing In', Icons.water_drop, const WashingInScreen());
        addTab('History', Icons.history, const ProductionHistoryScreen());
        break;
      case 'finishing':
        addTab(
          'Finishing',
          Icons.check_circle,
          const BundleStageScreen(
            title: 'Finishing',
            codeLabel: 'Bundle code',
            allowRejectedPieces: true,
          ),
        );
        addTab('History', Icons.history, const ProductionHistoryScreen());
        break;
      default:
        addTab('History', Icons.history, const ProductionHistoryScreen());
    }

    return tabs;
  }
}

class _DashboardTab {
  final String label;
  final IconData icon;
  final Widget child;

  const _DashboardTab({
    required this.label,
    required this.icon,
    required this.child,
  });
}

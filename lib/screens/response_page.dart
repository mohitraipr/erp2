import 'package:flutter/material.dart';

import '../models/login_response.dart';
import '../models/production_stage.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import 'tabs/cutting_manager_tab.dart';
import 'tabs/masters_tab.dart';
import 'tabs/production_flow_tab.dart';

class ResponsePage extends StatefulWidget {
  static const routeName = '/response';
  final LoginResponse data;
  final ApiService api;

  const ResponsePage({super.key, required this.data, required this.api});

  @override
  State<ResponsePage> createState() => _ResponsePageState();
}

class _DashboardTab {
  final String id;
  final String title;
  final IconData icon;
  final Widget content;

  const _DashboardTab({
    required this.id,
    required this.title,
    required this.icon,
    required this.content,
  });
}

class _ResponsePageState extends State<ResponsePage> {
  static const Set<String> _masterCreatorRoles = {
    'back_pocket',
    'jeans_assembly',
    'stitching_master',
  };

  late final ProductionStage? _stage;
  late final bool _isCuttingRole;
  late final bool _canManageMasters;
  late final List<_DashboardTab> _tabs;

  @override
  void initState() {
    super.initState();
    final normalizedRole = widget.data.normalizedRole;
    _stage = ProductionStage.fromRole(widget.data.role);
    _isCuttingRole = normalizedRole == 'cutting_manager' ||
        normalizedRole.contains('cutting');
    _canManageMasters = _masterCreatorRoles.contains(normalizedRole);
    _tabs = _buildTabs();
  }

  List<_DashboardTab> _buildTabs() {
    final tabs = <_DashboardTab>[
      _DashboardTab(
        id: 'overview',
        title: 'Overview',
        icon: Icons.dashboard_outlined,
        content: _OverviewTab(
          user: widget.data,
          stage: _stage,
          canManageMasters: _canManageMasters,
          showCutting: _isCuttingRole,
          onNavigate: _goToTabById,
        ),
      ),
    ];

    if (_stage != null) {
      tabs.add(
        _DashboardTab(
          id: 'production',
          title: 'Production flow',
          icon: Icons.precision_manufacturing_outlined,
          content: ProductionFlowTab(user: widget.data, api: widget.api),
        ),
      );
    }

    if (_canManageMasters) {
      tabs.add(
        _DashboardTab(
          id: 'masters',
          title: 'Masters',
          icon: Icons.groups_2_outlined,
          content: MastersTab(api: widget.api, user: widget.data),
        ),
      );
    }

    if (_isCuttingRole) {
      tabs.add(
        _DashboardTab(
          id: 'cutting',
          title: 'Cutting manager',
          icon: Icons.content_cut_outlined,
          content: CuttingManagerTab(user: widget.data, api: widget.api),
        ),
      );
    }

    return tabs;
  }

  int _tabIndex(String id) {
    return _tabs.indexWhere((tab) => tab.id == id);
  }

  void _goToTabById(String id) {
    final index = _tabIndex(id);
    if (index <= 0) return;
    final controller = DefaultTabController.of(context);
    controller?.animateTo(index);
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    widget.api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTabs = _tabs.length > 1;

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aurora ERP'),
          actions: [
            IconButton(
              tooltip: 'Log out',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: showTabs
              ? TabBar(
                  tabs: [
                    for (final tab in _tabs)
                      Tab(text: tab.title, icon: Icon(tab.icon)),
                  ],
                )
              : null,
        ),
        body: TabBarView(
          physics: const BouncingScrollPhysics(),
          children: [
            for (final tab in _tabs)
              SafeArea(child: tab.content),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final LoginResponse user;
  final ProductionStage? stage;
  final bool canManageMasters;
  final bool showCutting;
  final void Function(String id) onNavigate;

  const _OverviewTab({
    required this.user,
    required this.stage,
    required this.canManageMasters,
    required this.showCutting,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];
    if (stage != null) {
      chips.add(ActionChip(
        label: Text('${stage!.displayName} workflow'),
        avatar: const Icon(Icons.precision_manufacturing_outlined, size: 18),
        onPressed: () => onNavigate('production'),
      ));
    }
    if (canManageMasters) {
      chips.add(ActionChip(
        label: const Text('Manage masters'),
        avatar: const Icon(Icons.groups_2_outlined, size: 18),
        onPressed: () => onNavigate('masters'),
      ));
    }
    if (showCutting) {
      chips.add(ActionChip(
        label: const Text('Cutting manager tools'),
        avatar: const Icon(Icons.content_cut_outlined, size: 18),
        onPressed: () => onNavigate('cutting'),
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${user.username}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Signed in as ${user.role}. Use the shortcuts below to jump to the tools available for your role.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: chips,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (stage != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.insights_outlined),
                      const SizedBox(width: 12),
                      Text(
                        '${stage!.displayName} stage',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Submit ${stage!.codeLabel.toLowerCase()} updates and close upstream events. '
                    '${stage!.requiresMaster ? 'A master selection is required.' : 'No master is required for this stage.'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.qr_code_2_outlined, size: 18),
                        label: Text('Code: ${stage!.codeLabel}'),
                      ),
                      if (stage!.requiresMaster)
                        const Chip(
                          avatar: Icon(Icons.engineering_outlined, size: 18),
                          label: Text('Master required'),
                        ),
                      if (stage!.supportsRejectedPieces)
                        const Chip(
                          avatar: Icon(Icons.report_outlined, size: 18),
                          label: Text('Can mark rejections'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if (canManageMasters) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.groups_2_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Masters library',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create and maintain your team of masters for quick selection during production submissions.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (showCutting) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.content_cut_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cutting workspace',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generate new lots from fabric rolls, download bundle & piece codes, and review your existing lots.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/tracely_sidebar.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _recentTraces = [];
  Map<String, dynamic> _stats = {
    'active_traces': '0',
    'avg_latency': '0ms',
    'error_rate': '0%',
  };
  
  List<dynamic> _violations = [];
  bool _isLoading = true;
  bool _hasWorkspace = true;

  @override
  void initState() {
    super.initState();
    ApiService.activeWorkspaceNotifier.addListener(_fetchDashboardData);
    _fetchDashboardData();
  }

  @override
  void dispose() {
    ApiService.activeWorkspaceNotifier.removeListener(_fetchDashboardData);
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      String? workspaceId = await _apiService.getActiveWorkspaceId();
      
      if (workspaceId == null) {
        final wsResult = await _apiService.getWorkspaces();
        if (wsResult.isSuccess && wsResult.data is List && (wsResult.data as List).isNotEmpty) {
          workspaceId = wsResult.data[0]['id'].toString();
          await _apiService.setActiveWorkspace(workspaceId);
        } else {
          // No workspaces found OR API failed, redirect to workspace creation
          if (mounted) {
            setState(() {
              _hasWorkspace = false;
              _isLoading = false;
            });
            context.go('/workspaces');
          }
          return;
        }
      }

      if (workspaceId == null) return;
      if (mounted) setState(() => _hasWorkspace = true);

      // Fetch health stats
      final healthResult = await _apiService.getHealth(workspaceId);
      if (healthResult.isSuccess && mounted) {
        final health = healthResult.data;
        setState(() {
          final activeTraces = health['active_traces'] ?? 0;
          _stats['active_traces'] = activeTraces.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
            (Match m) => '${m[1]},'
          );
          _stats['avg_latency'] = '${health['avg_latency_ms'] ?? 0}ms';
          _stats['error_rate'] = '${(health['error_rate'] ?? 0.0).toStringAsFixed(2)}%';
        });
      }

      // Fetch traces
      final tracesResult = await _apiService.getTraces(workspaceId);
      if (tracesResult.isSuccess && mounted) {
        setState(() => _recentTraces = tracesResult.data ?? []);
      }

      // Fetch violations
      final violationsRes = await _apiService.getAlertViolations(workspaceId);
      if (violationsRes.isSuccess && mounted) {
        setState(() => _violations = violationsRes.data ?? []);
      }

    } catch (e) {
       debugPrint('Error fetching dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return ValueListenableBuilder<String?>(
      valueListenable: ApiService.activeWorkspaceNotifier,
      builder: (context, workspaceId, child) {
        return Scaffold(
          body: Row(
            children: [
              const TracelySidebar(activeRoute: '/dashboard'),
              // Main Content
              Expanded(
                child: !_hasWorkspace 
                  ? _buildNoWorkspaceView()
                  : _recentTraces.isEmpty 
                      ? _buildGetStartedGuide()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 48),
                              _buildStatsGrid(),
                              const SizedBox(height: 48),
                              _buildTracesGrid(),
                              const SizedBox(height: 48),
                              _buildQuickActions(),
                            ],
                          ),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workspace Overview',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 4),
            const Text('Detailed analytics and real-time tracing data.', style: TextStyle(color: Colors.white54)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => context.push('/workspaces'),
          icon: const Icon(Icons.add),
          label: const Text('Add Workspace'),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _StatCard(title: 'Active Traces', value: _stats['active_traces']!, trend: '+0%', color: Colors.green),
        const SizedBox(width: 24),
        _StatCard(title: 'Avg. Latency', value: _stats['avg_latency']!, trend: '0%', color: Colors.orange),
        const SizedBox(width: 24),
        _StatCard(title: 'Error Rate', value: _stats['error_rate']!, trend: '0%', color: Colors.red),
      ],
    );
  }

  Widget _buildTracesGrid() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _DashboardCard(
            title: 'Recent Traces',
            child: _TraceList(traces: _recentTraces),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _DashboardCard(
            title: 'Recent Violations',
            child: _ViolationsList(violations: _violations),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _QuickActionCard(
          title: 'Load Test Analytics',
          icon: Icons.speed,
          onTap: () => context.go('/load-test-results'),
        ),
        const SizedBox(width: 24),
        _QuickActionCard(
          title: 'Deployment Gates',
          icon: Icons.verified_user_outlined,
          onTap: () => context.go('/pipeline-status'),
        ),
        const SizedBox(width: 24),
        _QuickActionCard(
          title: 'Contract Testing',
          icon: Icons.fact_check_outlined,
          onTap: () => context.go('/contract-testing'),
        ),
      ],
    );
  }

  Widget _buildGetStartedGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 64),
          Text(
            'Get Started with Tracely',
            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Your workspace is ready! Follow these steps to begin tracing.', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 48),
          Row(
            children: [
              _buildGuideStep(
                icon: Icons.code,
                title: '1. Connect your App',
                desc: 'Use our SDK to start sending traces from your backend services.',
                btnLabel: 'View Docs',
                onTap: () {},
              ),
              const SizedBox(width: 24),
              _buildGuideStep(
                icon: Icons.settings_input_composite,
                title: '2. Setup Environments',
                desc: 'Define your production and staging environments for comparison.',
                btnLabel: 'Configure Envs',
                onTap: () => context.go('/environments'),
              ),
              const SizedBox(width: 24),
              _buildGuideStep(
                icon: Icons.play_circle_outline,
                title: '3. Run a Request',
                desc: 'Use Request Studio to test your endpoints through the Tracely proxy.',
                btnLabel: 'Try Studio',
                onTap: () => context.go('/request-studio'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep({required IconData icon, required String title, required String desc, required String btnLabel, required VoidCallback onTap}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: TracelyTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: TracelyTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: TracelyTheme.primaryColor),
            ),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
            const SizedBox(height: 32),
            TextButton(
              onPressed: onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(btnLabel),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoWorkspaceView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 100),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: TracelyTheme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: TracelyTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspaces_outline, size: 48, color: TracelyTheme.primaryColor),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Tracely',
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'To get started with API tracing and monitoring, you first need to create a workspace for your team.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, height: 1.5),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/workspaces'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Workspace'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: TracelyTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickActionCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: TracelyTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(icon, color: TracelyTheme.primaryColor),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;

  const _SidebarItem({required this.icon, required this.label, required this.route, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? TracelyTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isActive ? TracelyTheme.primaryColor : Colors.white54),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => context.go(route),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.trend, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: TracelyTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(trend, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TraceList extends StatelessWidget {
  final List<dynamic> traces;
  const _TraceList({required this.traces});

  @override
  Widget build(BuildContext context) {
    if (traces.isEmpty) {
      return const Center(child: Text('No recent traces', style: TextStyle(color: Colors.white24)));
    }
    return ListView.separated(
      itemCount: traces.length,
      separatorBuilder: (context, index) => const Divider(color: Colors.white10),
      itemBuilder: (context, index) {
        final trace = traces[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
          ),
          title: Text(trace['operation'] ?? 'API Call', style: GoogleFonts.firaCode(fontSize: 14)),
          subtitle: Text('${trace['service']} • ${trace['duration']}ms'),
          trailing: Text(trace['timestamp'] ?? 'Just now', style: const TextStyle(color: Colors.white30)),
          onTap: () => context.go('/traces/${trace['id']}'),
        );
      },
    );
  }
}

class _ErrorPatternItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _ErrorPatternItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(width: 4, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _DashboardCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: TracelyTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ViolationsList extends StatelessWidget {
  final List<dynamic> violations;
  const _ViolationsList({required this.violations});

  @override
  Widget build(BuildContext context) {
    if (violations.isEmpty) {
      return const Center(child: Text('No recent violations', style: TextStyle(color: Colors.white24)));
    }
    return ListView.builder(
      itemCount: violations.length,
      itemBuilder: (context, index) {
        final v = violations[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
          title: Text(v['alert_rule_name'] ?? 'Threshold Breached', style: const TextStyle(fontSize: 12, color: Colors.white)),
          subtitle: Text('Value: ${v['value']} | Trace: ${v['trace_id']}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
          trailing: const Icon(Icons.chevron_right, size: 14, color: Colors.white24),
          onTap: () => context.push('/traces/${v['trace_id']}'),
        );
      },
    );
  }
}

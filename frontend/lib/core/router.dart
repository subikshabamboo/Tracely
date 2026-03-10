import 'package:go_router/go_router.dart';
import '../features/traces/error_analysis_screen.dart';
import '../features/testing/test_data_generator_screen.dart';
import '../features/traces/trace_detail_screen.dart';
import '../features/traces/trace_metrics_overlay_screen.dart';
import '../features/audit/audit_logs_screen.dart';
import '../features/dashboard/workflow_builder_screen.dart';
import '../features/dashboard/topology_screen.dart';
import '../features/dashboard/mock_management_screen.dart';
import '../features/dashboard/request_studio_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/landing/landing_page.dart';
import '../features/auth/login_screen.dart';
import '../features/workspace/workspace_screen.dart';
import '../features/collections/collections_screen.dart';
import '../features/governance/governance_screen.dart';
import '../features/governance/secret_management_screen.dart';
import '../features/alerts/alert_management_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/replays/replay_comparison_screen.dart';
import '../features/alerts/threshold_config_screen.dart';
import '../features/collections/collection_detail_screen.dart';
import '../features/loadtest/load_test_results_screen.dart';
import '../features/devops/cicd_pipeline_status_screen.dart';
import '../features/testing/contract_testing_screen.dart';
import '../features/traces/latency_comparison_screen.dart';
import '../features/dashboard/environments_screen.dart';


import 'package:shared_preferences/shared_preferences.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    final authRoutes = ['/login', '/register'];
    final currentPath = state.uri.path;
    
    // If user has token and visits auth pages, redirect to dashboard
    if (token != null && authRoutes.contains(currentPath)) {
      return '/dashboard';
    }
    
    // If no token and tries to access protected route (not landing, login, or register), redirect to login
    if (token == null && currentPath != '/' && currentPath != '/login' && currentPath != '/register') {
      return '/login';
    }
    
    // Otherwise, allow access to the requested route
    return null;
  },
  routes: [
    GoRoute(
      path: '/error-analysis',
      builder: (context, state) => const ErrorAnalysisScreen(),
    ),

    GoRoute(
      path: '/collections/:id',
      builder: (context, state) => CollectionDetailScreen(collectionId: state.pathParameters['id']!),
    ),

    GoRoute(
      path: '/alerts/thresholds',
      builder: (context, state) => const ThresholdConfigScreen(),
    ),

    GoRoute(
      path: '/',
      builder: (context, state) => const LandingPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/workspaces',
      builder: (context, state) => const WorkspaceScreen(),
    ),
    GoRoute(
      path: '/collections',
      builder: (context, state) => const CollectionsScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/request-studio',
      builder: (context, state) => const RequestStudioScreen(),
    ),
    GoRoute(
      path: '/traces/:id',
      builder: (context, state) => TraceDetailScreen(traceId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/traces/:id/metrics',
      builder: (context, state) => TraceMetricsOverlayScreen(traceId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/workflows',
      builder: (context, state) => const WorkflowBuilderScreen(),
    ),
    GoRoute(
      path: '/topology',
      builder: (context, state) => const TopologyScreen(),
    ),
    GoRoute(
      path: '/mocks',
      builder: (context, state) => const MockManagementScreen(),
    ),
    GoRoute(
      path: '/governance',
      builder: (context, state) => const GovernanceScreen(),
    ),
    GoRoute(
      path: '/alerts',
      builder: (context, state) => const AlertManagementScreen(),
    ),
    GoRoute(
      path: '/secrets',
      builder: (context, state) => const SecretManagementScreen(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/replays/comparison/:id',
      builder: (context, state) => ReplayComparisonScreen(replayId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/traces/compare/:id1/:id2',
      builder: (context, state) => LatencyComparisonScreen(
        traceId1: state.pathParameters['id1']!,
        traceId2: state.pathParameters['id2'],
      ),
    ),

    GoRoute(
      path: '/load-test-results',
      builder: (context, state) => const LoadTestResultsScreen(),
    ),
    GoRoute(
      path: '/pipeline-status',
      builder: (context, state) => const CICDPipelineStatusScreen(),
    ),
    GoRoute(
      path: '/data-generator',
      builder: (context, state) => const TestDataGeneratorScreen(),
    ),
    GoRoute(
      path: '/contract-testing',
      builder: (context, state) => const ContractTestingScreen(),
    ),
    GoRoute(
      path: '/audit-logs',
      builder: (context, state) => const AuditLogsScreen(),
    ),
    GoRoute(
      path: '/environments',
      builder: (context, state) => const EnvironmentsScreen(),
    ),

  ],
);

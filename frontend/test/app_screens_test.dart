import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/dashboard/dashboard_screen.dart';
import 'package:frontend/features/workspace/workspace_screen.dart';
import 'package:frontend/features/dashboard/topology_screen.dart';
import 'package:frontend/features/traces/trace_metrics_overlay_screen.dart';
import 'package:frontend/features/dashboard/mock_management_screen.dart';
import 'package:frontend/features/dashboard/workflow_builder_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A wrapper that provides GoRouter context for screens that use navigation
Widget createTestableWidget(Widget child) {
  // Create a simple router for testing
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/workspaces',
        builder: (context, state) => const WorkspaceScreen(),
      ),
      GoRoute(
        path: '/topology',
        builder: (context, state) => const TopologyScreen(),
      ),
      GoRoute(
        path: '/traces/:id/metrics',
        builder: (context, state) => TraceMetricsOverlayScreen(
          traceId: state.pathParameters['id'] ?? 'test',
        ),
      ),
      GoRoute(
        path: '/mocks',
        builder: (context, state) => const MockManagementScreen(),
      ),
      GoRoute(
        path: '/workflows',
        builder: (context, state) => const WorkflowBuilderScreen(),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

// Helper to initialize SharedPreferences for tests
Future<void> initTestPrefs() async {
  SharedPreferences.setMockInitialValues({
    'active_workspace_id': 'test-workspace-id',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize mock SharedPreferences before any tests run
    await initTestPrefs();
  });

  group('Frontend Screens Smoke Test', () {
    // Dashboard Screen test - uses context.go() so needs router
    testWidgets('Dashboard Screen renders without crashing', (WidgetTester tester) async {
      // Set a larger surface size to avoid overflow
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      
      await tester.pumpWidget(createTestableWidget(const DashboardScreen()));
      // Use pump with duration instead of pumpAndSettle to avoid timeout
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      
      // Verify the screen widget exists
      expect(find.byType(DashboardScreen), findsOneWidget);
      
      // Reset the surface size
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Workspace Screen test
    testWidgets('Workspace Screen renders without crashing', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      
      await tester.pumpWidget(createTestableWidget(const WorkspaceScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Topology Screen test
    testWidgets('Topology Screen renders without crashing', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      
      await tester.pumpWidget(createTestableWidget(const TopologyScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TopologyScreen), findsOneWidget);
      
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Trace Metrics Overlay test
    testWidgets('Trace Metrics Overlay renders without crashing', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      
      await tester.pumpWidget(createTestableWidget(
        const TraceMetricsOverlayScreen(traceId: 'test-trace-id'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TraceMetricsOverlayScreen), findsOneWidget);
      
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Mock Management Screen test
    testWidgets('Mock Management Screen renders without crashing', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      
      await tester.pumpWidget(createTestableWidget(const MockManagementScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MockManagementScreen), findsOneWidget);
      
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
	
    // Workflow Builder Screen test
    testWidgets('Workflow Builder Screen renders without crashing', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      
      await tester.pumpWidget(createTestableWidget(const WorkflowBuilderScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WorkflowBuilderScreen), findsOneWidget);
      
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}


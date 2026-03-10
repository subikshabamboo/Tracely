import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/dashboard_screen.dart';
import 'package:frontend/features/workspace/workspace_screen.dart';
import 'package:frontend/features/dashboard/topology_screen.dart';
import 'package:frontend/features/traces/trace_metrics_overlay_screen.dart';
import 'package:frontend/features/dashboard/mock_management_screen.dart';
import 'package:frontend/features/dashboard/workflow_builder_screen.dart';

// A wrapper to provide necessary ancestors like MaterialApp and MediaQuery
Widget createTestableWidget(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Frontend Screens Smoke Test', () {
    testWidgets('Dashboard Screen renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const DashboardScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('Workspace Screen renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const WorkspaceScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceScreen), findsOneWidget);
    });

    testWidgets('Topology Screen renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const TopologyScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(TopologyScreen), findsOneWidget);
    });

    testWidgets('Trace Metrics Overlay renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const TraceMetricsOverlayScreen(traceId: 'test-trace-id')));
      await tester.pumpAndSettle();
      expect(find.byType(TraceMetricsOverlayScreen), findsOneWidget);
    });

    testWidgets('Mock Management Screen renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const MockManagementScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(MockManagementScreen), findsOneWidget);
    });
	
	testWidgets('Workflow Builder Screen renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const WorkflowBuilderScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(WorkflowBuilderScreen), findsOneWidget);
    });
  });
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/router.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api/v1';
  
  static final ValueNotifier<String?> activeWorkspaceNotifier = ValueNotifier<String?>(null);

  ApiService() {
    _initializeWorkspace();
  }

  Future<void> _initializeWorkspace() async {
    activeWorkspaceNotifier.value = await getActiveWorkspaceId();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> setActiveWorkspace(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_workspace_id', id);
    activeWorkspaceNotifier.value = id;
  }

  Future<String?> getActiveWorkspaceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_workspace_id');
  }

  // Auth
  Future<DynamicResult> login(String email, String password) async {
    final resp = await post('/auth/login', {'email': email, 'password': password});
    final result = await _handleResponse(resp);
    if (result.isSuccess) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', result.data['token']);
    }
    return result;
  }

  Future<DynamicResult> register(String email, String password) => 
    safePost('/auth/register', {
      'email': email, 
      'password': password,
      'full_name': email.split('@').first // Use part before @ as default name
    });

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final token = await _getToken();
    return http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  Future<http.Response> get(String endpoint) async {
    final token = await _getToken();
    return http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  Future<http.Response> delete(String endpoint) async {
    final token = await _getToken();
    return http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  // Helper for parsing response and handling errors
  Future<DynamicResult> _handleResponse(http.Response response) async {
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Token is expired, invalid, or missing. Clear out local storage to force login.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('active_workspace_id');
      
      // Force global UI redirect to login immediately
      router.go('/login');
      
      return DynamicResult.error('Session expired. Please log in again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return DynamicResult.success(null);
      return DynamicResult.success(jsonDecode(response.body));
    } else {
      String errorMessage = 'Request failed with status: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'];
        }
      } catch (_) {
        if (response.body.isNotEmpty) {
          errorMessage += ', body: ${response.body}';
        }
      }
      return DynamicResult.error(errorMessage);
    }
  }

  Future<DynamicResult> safeGet(String endpoint) async {
    try {
      final response = await get(endpoint);
      return await _handleResponse(response);
    } catch (e) {
      return DynamicResult.error(e.toString());
    }
  }

  Future<DynamicResult> safePost(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await post(endpoint, body);
      return await _handleResponse(response);
    } catch (e) {
      return DynamicResult.error(e.toString());
    }
  }

  Future<DynamicResult> safeDelete(String endpoint) async {
    try {
      final response = await delete(endpoint);
      return await _handleResponse(response);
    } catch (e) {
      return DynamicResult.error(e.toString());
    }
  }

  // Trace Intelligence
  Future<DynamicResult> getTraces(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/traces?workspace_id=$id');
  }

  Future<DynamicResult> getTraceStats(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/traces/stats?workspace_id=$id');
  }

  Future<DynamicResult> getWaterfall(String traceId) => safeGet('/traces/$traceId/waterfall');
  Future<DynamicResult> getCriticalPath(String traceId) => safeGet('/traces/$traceId/critical-path');
  Future<DynamicResult> getTraceLogs(String traceId) => safeGet('/traces/$traceId/logs');
  Future<DynamicResult> getTraceMetrics(String traceId) => safeGet('/traces/$traceId/metrics');
  Future<DynamicResult> getTraceAnomalies(String traceId) => safeGet('/traces/$traceId/anomalies');
  Future<DynamicResult> getTraceOptimizations(String traceId) => safeGet('/traces/$traceId/optimizations');
  
  // System Metrics Overlay - Get metrics with anomalies for a trace
  Future<DynamicResult> getTraceMetricsWithAnomalies(String traceId) => safeGet('/traces/$traceId/trace-metrics');

  Future<DynamicResult> getTopology(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/traces/topology?workspace_id=$id');
  }

  Future<DynamicResult> createTraceAnnotation(String traceId, String content, {String? spanId}) =>
    safePost('/traces/$traceId/annotations', {
      'trace_uuid': traceId,
      'content': content,
      if (spanId != null) 'span_id': spanId,
    });

  Future<DynamicResult> createTraceReply(String traceId, String parentId, String content, {String? spanId}) =>
    safePost('/traces/annotations/replies', {
      'trace_uuid': traceId,
      'parent_id': parentId,
      'content': content,
      if (spanId != null) 'span_id': spanId,
    });

  Future<DynamicResult> resolveAnnotationThread(String rootId, bool resolved) =>
    safePost('/traces/annotations/resolve', {'root_id': rootId, 'resolved': resolved});

  Future<DynamicResult> getAnnotationThread(String rootId) => safeGet('/traces/annotations/threads/$rootId');

  Future<DynamicResult> getTraceAnnotations(String traceId) => safeGet('/traces/$traceId/annotations');

  Future<DynamicResult> createTraceShare(String traceId, bool isPublic, {DateTime? expiresAt}) =>
    safePost('/traces/shares', {
      'trace_uuid': traceId,
      'is_public': isPublic,
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
    });

  Future<DynamicResult> getPublicTrace(String accessKey) async {
    // Note: This endpoint is public, so it might not need the /api/v1 prefix 
    // depending on how we set up the router. In our case, router.GET("/public/traces/:key", ...)
    // which is usually at the root if not group-prefixed. 
    // However, safeGet uses baseUrl. I should probably use a direct call for public routes if they don't have /api/v1.
    final response = await http.get(Uri.parse('http://localhost:8080/public/traces/$accessKey'));
    return await _handleResponse(response);
  }

  Future<DynamicResult> saveTraceConfig(Map<String, dynamic> config) => safePost('/traces/config', config);
  
  // Workspaces & Collections
  Future<DynamicResult> getWorkspaces() => safeGet('/workspaces');
  
  Future<DynamicResult> createWorkspace(String name) => safePost('/workspaces', {'name': name});
  Future<DynamicResult> deleteWorkspace(String id) => safeDelete('/workspaces/$id');

  Future<DynamicResult> getCollections(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    if (id == null) return DynamicResult.success([]);
    return safeGet('/collections?workspace_id=$id');
  }

  Future<DynamicResult> getCollection(String id) => safeGet('/collections/$id');

  Future<DynamicResult> getCollectionVersions(String name, String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    if (id == null) return DynamicResult.success([]);
    return safeGet('/collections/versions?name=$name&workspace_id=$id');
  }

  Future<DynamicResult> importPostman(String? workspaceId, List<int> bytes, String filename) async {
     // Multi-part would go here, leaving as stub for now per plan
     return DynamicResult.error('Multipart upload not implemented');
  }

  // Environments
  Future<DynamicResult> getEnvironments(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    if (id == null) return DynamicResult.success([]);
    return safeGet('/environments?workspace_id=$id');
  }

  Future<DynamicResult> createEnvironment(Map<String, dynamic> env) => safePost('/environments', env);

  // Testing & Simulation
  Future<DynamicResult> runLoadTest(String url, int concurrency, int duration) => 
    safePost('/load-test', {'url': url, 'concurrency': concurrency, 'duration_sec': duration});
  
  Future<DynamicResult> proxyRequest(Map<String, dynamic> data) async {
    if (!data.containsKey('workspace_id')) {
        final id = await getActiveWorkspaceId();
        if (id != null) data['workspace_id'] = id;
    }
    return safePost('/proxy', data);
  }

  // Mock Management
  Future<DynamicResult> getMocks() => safeGet('/mocks');
  Future<DynamicResult> createMock(Map<String, dynamic> data) => safePost('/mocks', data);
  Future<DynamicResult> updateMock(String id, Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/mocks/$id'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    return await _handleResponse(response);
  }
  Future<DynamicResult> deleteMock(String id) => safeDelete('/mocks/$id');
  
  // Workflows
  Future<DynamicResult> getWorkflows() => safeGet('/workflows');
  Future<DynamicResult> runWorkflow(String id) => safePost('/workflows/$id/run', {});

  // Platform Health
  Future<DynamicResult> getHealth([String? workspaceId]) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    if (id == null) return safeGet('/health');
    return safeGet('/health?workspace_id=$id');
  }

  // Alerts Management
  Future<DynamicResult> getAlertRules(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    if (id == null) return DynamicResult.success([]);
    return safeGet('/alerts/rules?workspace_id=$id');
  }

  Future<DynamicResult> createAlertRule(Map<String, dynamic> rule) => safePost('/alerts/rules', rule);

  Future<DynamicResult> getAlertViolations(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/alerts/violations?workspace_id=$id');
  }

  // Secret Management
  Future<DynamicResult> getSecrets(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/secrets?workspace_id=$id');
  }

  Future<DynamicResult> addSecret(String? workspaceId, String key, String value) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safePost('/secrets', {'workspace_id': id, 'key': key, 'value': value});
  }

  Future<DynamicResult> deleteSecret(String id) => safeDelete('/secrets/$id');

  // Replay Analysis
  Future<DynamicResult> getReplays(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/replays?workspace_id=$id');
  }

  Future<DynamicResult> createReplay(Map<String, dynamic> data) => safePost('/replays', data);
  Future<DynamicResult> executeReplay(String id) => safePost('/replays/$id/execute', {});
  Future<DynamicResult> getReplayComparison(String executionId) => safeGet('/replays/$executionId/comparison');

  // Governance & Auditing
  Future<DynamicResult> getGovernanceAudits(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/governance/audits?workspace_id=$id');
  }

  Future<DynamicResult> getRedactionRules(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/governance/redaction-rules?workspace_id=$id');
  }

  Future<DynamicResult> createRedactionRule(Map<String, dynamic> rule) => safePost('/governance/redaction-rules', rule);
  Future<DynamicResult> deleteRedactionRule(String id) => safeDelete('/governance/redaction-rules/$id');

  // Settings
  Future<DynamicResult> getSettings() => safeGet('/settings');
  Future<DynamicResult> updateSettings(Map<String, dynamic> settings) => safePost('/settings', settings);

  // Workspace & Users
  Future<DynamicResult> getWorkspaceUsers(String workspaceId) => safeGet('/workspaces/$workspaceId/users');

  // Mutation History
  Future<DynamicResult> getMutationHistory(String executionId) async {
    return await safeGet('/replays/executions/$executionId/mutations');
  }

  // Error Cascade Simulation
  Future<DynamicResult> getCascadeSimulations(String workspaceId) async {
    return await safeGet('/replays/cascades?workspace_id=$workspaceId');
  }

  Future<DynamicResult> startCascadeSimulation(String workspaceId, Map<String, dynamic> config) async {
    return await safePost('/replays/cascades?workspace_id=$workspaceId', config);
  }

  Future<DynamicResult> getCascadeResults(String simulationId) async {
    return await safeGet('/replays/cascades/$simulationId/results');
  }

  // Error Injection Configs
  Future<DynamicResult> getErrorInjections(String workspaceId) async {
    return await safeGet('/replays/error-injections?workspace_id=$workspaceId');
  }

  Future<DynamicResult> executeLoadRamp(String id, Map<String, dynamic> pattern) async {
    return await safePost('/replays/$id/load-ramp', pattern);
  }

  // Reports
  Future<DynamicResult> getReports(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/reports?workspace_id=$id');
  }

  // CI/CD
  Future<DynamicResult> getCiStatus(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/webhooks/ci-status?workspace_id=$id');
  }

  // Audit Logs
  Future<DynamicResult> getAuditLogs(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/audit-logs?workspace_id=$id');
  }

  // Testing Tools
  Future<DynamicResult> generateTestData(Map<String, dynamic> config) => safePost('/test-data/generate', config);
  Future<DynamicResult> getContractTests(String? workspaceId) async {
    final id = workspaceId ?? await getActiveWorkspaceId();
    return safeGet('/testing/contracts?workspace_id=$id');
  }
}

class DynamicResult {
  final dynamic data;
  final String? error;
  final bool isSuccess;

  DynamicResult.success(this.data) : error = null, isSuccess = true;
  DynamicResult.error(this.error) : data = null, isSuccess = false;
}



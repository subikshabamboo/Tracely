import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/tracely_sidebar.dart';

import '../../services/api_service.dart';
import 'dart:convert';

class MockManagementScreen extends StatefulWidget {
  const MockManagementScreen({super.key});

  @override
  State<MockManagementScreen> createState() => _MockManagementScreenState();
}

class _MockManagementScreenState extends State<MockManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _mocks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMocks();
  }

  Future<void> _fetchMocks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getMocks();
      if (mounted && result.isSuccess) {
        setState(() {
          _mocks = result.data ?? [];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateMockDialog() {
    final endpointController = TextEditingController();
    final bodyController = TextEditingController(text: '{\n  "status": "success"\n}');
    String method = 'GET';
    int statusCode = 200;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: TracelyTheme.surfaceColor,
          title: const Text('Create New Mock'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: ['GET', 'POST', 'PUT', 'DELETE'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setDialogState(() => method = v!),
                ),
                TextField(
                  controller: endpointController,
                  decoration: const InputDecoration(labelText: 'Endpoint', hintText: '/api/v1/resource'),
                ),
                TextField(
                  controller: bodyController,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Response Body (JSON)'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                DropdownButtonFormField<int>(
                  value: statusCode,
                  decoration: const InputDecoration(labelText: 'Response Status Code'),
                  items: [200, 201, 400, 401, 404, 500].map((s) => DropdownMenuItem(value: s, child: Text(s.toString()))).toList(),
                  onChanged: (v) => setDialogState(() => statusCode = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final result = await _apiService.createMock({
                  'method': method,
                  'endpoint': endpointController.text,
                  'response_body': bodyController.text,
                  'response_code': statusCode,
                  'is_active': true,
                });
                if (result.isSuccess) {
                  if (mounted) Navigator.pop(context);
                  _fetchMocks();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMock(String id, bool isActive) async {
    final result = await _apiService.updateMock(id, {'is_active': isActive});
    if (result.isSuccess) {
      _fetchMocks();
    }
  }

  Future<void> _deleteMock(String id) async {
    final result = await _apiService.deleteMock(id);
    if (result.isSuccess) {
      _fetchMocks();
    }
  }

  void _showEditMockDialog(dynamic mock) {
    final endpointController = TextEditingController(text: mock['endpoint']);
    final bodyController = TextEditingController(text: mock['response_body']);
    String method = mock['method'];
    int statusCode = mock['response_code'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: TracelyTheme.surfaceColor,
          title: const Text('Edit Mock'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: ['GET', 'POST', 'PUT', 'DELETE'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setDialogState(() => method = v!),
                ),
                TextField(
                  controller: endpointController,
                  decoration: const InputDecoration(labelText: 'Endpoint'),
                ),
                TextField(
                  controller: bodyController,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Response Body (JSON)'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                DropdownButtonFormField<int>(
                  value: statusCode,
                  decoration: const InputDecoration(labelText: 'Response Status Code'),
                  items: [200, 201, 400, 401, 404, 500].map((s) => DropdownMenuItem(value: s, child: Text(s.toString()))).toList(),
                  onChanged: (v) => setDialogState(() => statusCode = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final result = await _apiService.updateMock(mock['id'].toString(), {
                  'method': method,
                  'endpoint': endpointController.text,
                  'response_body': bodyController.text,
                  'response_code': statusCode,
                });
                if (result.isSuccess) {
                  if (mounted) Navigator.pop(context);
                  _fetchMocks();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const TracelySidebar(activeRoute: '/mocks'),
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text('Mock Service Management', style: TextStyle(fontSize: 18, color: Colors.white70)),
                backgroundColor: Colors.transparent,
                actions: [
                  ElevatedButton.icon(
                    onPressed: _showCreateMockDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Mock'),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: Container(
                margin: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Search & Filter
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search mocks by endpoint or method...',
                              prefixIcon: const Icon(Icons.search),
                              fillColor: TracelyTheme.surfaceColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: 'All Methods',
                          items: ['All Methods', 'GET', 'POST', 'PUT', 'DELETE']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Mock List
                    Expanded(
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator(color: TracelyTheme.primaryColor))
                        : _mocks.isEmpty
                          ? const Center(child: Text('No mocks configured yet.', style: TextStyle(color: Colors.white24)))
                          : ListView.separated(
                        itemCount: _mocks.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final mock = _mocks[index];
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: TracelyTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                _MethodBadge(method: mock['method'] ?? 'GET'),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(mock['endpoint'] ?? '/', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text('Returns status ${mock['response_code']}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                     Text('${mock['response_code']} OK', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                     const SizedBox(height: 4),
                                     const Text('JSON Content', style: TextStyle(color: Colors.white30, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Switch(
                                  value: mock['is_active'] ?? true, 
                                  onChanged: (v) => _toggleMock(mock['id'].toString(), v),
                                  activeColor: TracelyTheme.primaryColor,
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.edit_note), 
                                  onPressed: () => _showEditMockDialog(mock),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                                  onPressed: () => _deleteMock(mock['id'].toString()),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _MethodBadge extends StatelessWidget {
  final String method;
  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    Color color = method == 'GET' ? Colors.green : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        method,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

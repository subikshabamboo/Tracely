import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../core/app_state.dart';
import '../../widgets/tracely_sidebar.dart';

class RequestStudioScreen extends StatefulWidget {
  const RequestStudioScreen({super.key});

  @override
  State<RequestStudioScreen> createState() => _RequestStudioScreenState();
}

class _RequestStudioScreenState extends State<RequestStudioScreen> with SingleTickerProviderStateMixin {
  final AppState _appState = AppState();
  final ApiService _apiService = ApiService();
  
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String _selectedMethod = 'GET';
  Map<String, dynamic>? _response;
  bool _isLoading = false;
  
  final List<Map<String, String>> _history = [
    {'method': 'GET', 'url': 'http://localhost:8080/api/v1/health', 'time': '5m ago'},
    {'method': 'POST', 'url': 'http://localhost:8080/api/v1/auth/login', 'time': '12m ago'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _selectedMethod = _appState.lastMethod;
    _urlController.text = _appState.lastUrl;
    _bodyController.text = _appState.lastRequestBody;
    _response = _appState.lastResponse;

    _urlController.addListener(() => _appState.lastUrl = _urlController.text);
    _bodyController.addListener(() => _appState.lastRequestBody = _bodyController.text);
  }

  void _sendRequest() async {
    setState(() => _isLoading = true);
    try {
      final activeWorkspaceId = await _apiService.getActiveWorkspaceId();
      final result = await _apiService.proxyRequest({
        'method': _selectedMethod,
        'url': _urlController.text,
        'headers': {
          'Content-Type': 'application/json',
          // Header pass-through could be added here
        },
        'body': _bodyController.text,
        if (activeWorkspaceId != null) 'workspace_id': activeWorkspaceId,
      });

      if (result.isSuccess) {
        final data = result.data;
        setState(() {
          _response = {
            'status': data['status'],
            'time': data['time'],
            'size': '${utf8.encode(data['body']?.toString() ?? '').length} bytes',
            'body': data['body'],
            'trace_id': data['trace_id'],
          };
          _appState.lastResponse = _response;
          _history.insert(0, {'method': _selectedMethod, 'url': _urlController.text, 'time': 'Just now'});
        });
      } else {
        setState(() {
          _response = {
            'status': 'Error', 
            'body': '🔴 Failed to execute request:\n\n${result.error ?? "Unknown error"}'
          };
          _appState.lastResponse = _response;
        });
      }
    } catch (e) {
      setState(() {
        _response = {'status': 500, 'body': 'Connection Error: $e'};
        _appState.lastResponse = _response;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const TracelySidebar(activeRoute: '/request-studio'),
          // History/Collections Sidebar
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: TracelyTheme.surfaceColor,
              border: const Border(right: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.white30, size: 20),
                      SizedBox(width: 12),
                      Text('History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return ListTile(
                        dense: true,
                        leading: Text(item['method']!, style: TextStyle(color: _getMethodColor(item['method']!), fontWeight: FontWeight.bold, fontSize: 10)),
                        title: Text(item['url']!, style: const TextStyle(fontSize: 12, overflow: TextOverflow.ellipsis)),
                        subtitle: Text(item['time']!, style: const TextStyle(fontSize: 10, color: Colors.white24)),
                        onTap: () => setState(() {
                          _selectedMethod = item['method']!;
                          _urlController.text = item['url']!;
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main Editor
          Expanded(
            child: Column(
              children: [
                AppBar(
                  title: const Text('Request Studio', style: TextStyle(fontSize: 18, color: Colors.white70)),
                  backgroundColor: Colors.transparent,
                  actions: [
                    TextButton.icon(onPressed: () {}, icon: const Icon(Icons.save_outlined, size: 20), label: const Text('Save')),
                    const SizedBox(width: 16),
                  ],
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Request Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: TracelyTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedMethod,
                                  dropdownColor: TracelyTheme.surfaceColor,
                                  items: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
                                      .map((m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(m, style: TextStyle(color: _getMethodColor(m), fontWeight: FontWeight.bold)),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedMethod = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _urlController,
                                  style: GoogleFonts.firaCode(fontSize: 14),
                                  decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter request URL'),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _sendRequest,
                                child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('SEND'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Tabs
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(color: TracelyTheme.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                            child: Column(
                              children: [
                                TabBar(controller: _tabController, indicatorColor: TracelyTheme.primaryColor, tabs: const [Tab(text: 'Params'), Tab(text: 'Headers'), Tab(text: 'Body')]),
                                Expanded(child: TabBarView(controller: _tabController, children: [
                                  const _TableEditor(rows: [['key', 'value']]),
                                  const _TableEditor(rows: [['Content-Type', 'application/json']]),
                                  Padding(padding: const EdgeInsets.all(16.0), child: TextField(controller: _bodyController, maxLines: null, expands: true, style: GoogleFonts.firaCode(fontSize: 13, color: Colors.greenAccent), decoration: const InputDecoration(border: InputBorder.none, hintText: '{\n  "key": "value"\n}'))),
                                ])),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Response
                        Expanded(
                          flex: 3,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(color: TracelyTheme.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                            child: _response == null 
                              ? const Center(child: Text('Hit SEND to see the response', style: TextStyle(color: Colors.white24)))
                              : _buildResponseView(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text('Status: ', style: TextStyle(color: Colors.white30)),
              Text('${_response!['status']} OK', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_response!['trace_id'] != null)
                TextButton.icon(
                  onPressed: () => context.go('/traces/${_response!['trace_id']}'),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('View Trace'),
                ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(_response!['body'], style: GoogleFonts.firaCode(fontSize: 13, color: Colors.white70)))),
      ],
    );
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'GET': return Colors.green;
      case 'POST': return Colors.blue;
      case 'PUT': return Colors.orange;
      case 'PATCH': return Colors.deepOrange;
      case 'DELETE': return Colors.red;
      default: return Colors.white;
    }
  }
}

class _TableEditor extends StatelessWidget {
  final List<List<String>> rows;
  const _TableEditor({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(children: [Expanded(child: Text('Key', style: TextStyle(color: Colors.white30, fontSize: 12))), Expanded(child: Text('Value', style: TextStyle(color: Colors.white30, fontSize: 12))), const SizedBox(width: 48)]),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(children: [Expanded(child: TextField(decoration: InputDecoration(hintText: r[0], isDense: true))), const SizedBox(width: 16), Expanded(child: TextField(decoration: InputDecoration(hintText: r[1], isDense: true))), IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.white10), onPressed: () {})]))),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import 'widgets/trace_share_dialog.dart';

class TraceDetailScreen extends StatefulWidget {
  final String traceId;
  const TraceDetailScreen({super.key, required this.traceId});

  @override
  State<TraceDetailScreen> createState() => _TraceDetailScreenState();
}


class _TraceDetailScreenState extends State<TraceDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _traceData;
  Map<String, dynamic>? _metrics;
  List<dynamic> _anomalies = [];
  List<dynamic> _annotations = [];
  bool _isLoading = true;
  int _activeTab = 0;
  WebSocket? _socket;
  Map<String, dynamic>? _selectedSpan;

  @override
  void initState() {
    super.initState();
    _fetchTraceDetails();
    _fetchAnnotations();
    _fetchMetrics();
    _fetchAnomalies();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _socket?.close();
    super.dispose();
  }

  Future<void> _fetchTraceDetails() async {
    final result = await _apiService.getWaterfall(widget.traceId);
    if (result.isSuccess) {
      setState(() {
        _traceData = result.data;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAnnotations() async {
    final result = await _apiService.getTraceAnnotations(widget.traceId);
    if (result.isSuccess) {
      setState(() => _annotations = result.data);
    }
  }

  Future<void> _fetchMetrics() async {
    final result = await _apiService.getTraceMetrics(widget.traceId);
    if (result.isSuccess) {
      setState(() => _metrics = result.data);
    }
  }

  Future<void> _fetchAnomalies() async {
    final result = await _apiService.getTraceAnomalies(widget.traceId);
    if (result.isSuccess) {
      setState(() => _anomalies = result.data);
    }
  }

  void _connectWebSocket() async {
    try {
      _socket = await WebSocket.connect('ws://localhost:8080/api/v1/ws');
      _socket?.listen((data) {
        final Map<String, dynamic> msg = jsonDecode(data);
        if (msg['type'] == 'new_annotation') {
          final payload = msg['payload'];
          if (payload['trace_uuid'] == widget.traceId) {
            setState(() => _annotations.insert(0, payload));
          }
        } else if (msg['type'] == 'new_reply') {
          final payload = msg['payload'];
          if (payload['trace_uuid'] == widget.traceId) {
            _fetchAnnotations(); // Refresh for simplicity or update local state
          }
        } else if (msg['type'] == 'thread_resolved') {
          if (msg['trace_uuid'] == widget.traceId) {
             _fetchAnnotations();
          }
        }
      });
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Trace: ${widget.traceId}', style: const TextStyle(fontSize: 18, color: Colors.white70)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.orange),
            tooltip: 'Share Trace',
            onPressed: () => showDialog(
              context: context,
              builder: (context) => TraceShareDialog(traceId: widget.traceId),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Main Content
          Expanded(
            flex: _selectedSpan == null ? 3 : 2,
            child: Column(
              children: [
                // Header Info
                Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: TracelyTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _HeaderStat(label: 'Total Duration', value: '${(_traceData?['duration_ms'] ?? 0)}ms'),
                      _HeaderStat(label: 'Services', value: _traceData?['service_count']?.toString() ?? '1'),
                      _HeaderStat(label: 'Status', value: _traceData?['status_code']?.toString() ?? '200 OK', color: Colors.green),
                      _HeaderStat(label: 'Timestamp', value: 'Recent'),
                    ],
                  ),
                ),
                // Optimization Suggestions
                if (_traceData?['recommendation'] != null || (_traceData?['optimizations'] as List?)?.isNotEmpty == true)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.orangeAccent),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Potential Savings: ${(_traceData?['potential_savings_ms'] as num? ?? 0).toStringAsFixed(1)}ms', 
                              style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _traceData?['recommendation'] ?? 'Analyze your critical path to find bottlenecks.',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            if ((_traceData?['optimizations'] as List?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 12),
                              ...(_traceData?['optimizations'] as List).map((opt) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• ${opt['title']}: ${opt['description']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              )),
                            ],
                          ],
                        )),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                // Tab Switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _TabButton(
                        label: 'Waterfall', 
                        isActive: _activeTab == 0, 
                        onTap: () => setState(() => _activeTab = 0)
                      ),
                      const SizedBox(width: 16),
                      _TabButton(
                        label: 'Unified Timeline', 
                        isActive: _activeTab == 1, 
                        onTap: () => setState(() => _activeTab = 1)
                      ),
                      const SizedBox(width: 16),
                      _TabButton(
                        label: 'Metrics Overlay', 
                        isActive: _activeTab == 2, 
                        onTap: () => setState(() => _activeTab = 2)
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Main View Area
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: TracelyTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: _activeTab == 0 
                      ? _buildWaterfallView()
                      : _activeTab == 1
                        ? _buildUnifiedTimeline()
                        : _buildMetricsView(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          
          // Span Detail Panel (if selected)
          if (_selectedSpan != null)
            Container(
              width: 350,
              decoration: const BoxDecoration(
                color: TracelyTheme.surfaceColor,
                border: Border(left: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    title: const Text('Span Details', style: TextStyle(fontSize: 16)),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _selectedSpan = null),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _DetailRow(label: 'Operation', value: _selectedSpan!['operation_name'] ?? 'N/A'),
                        _DetailRow(label: 'Service', value: _selectedSpan!['service_name'] ?? 'N/A'),
                        _DetailRow(label: 'Duration', value: '${_selectedSpan!['duration_ms']}ms'),
                        _DetailRow(label: 'Start Time', value: _selectedSpan!['start_time'] ?? 'N/A'),
                        const SizedBox(height: 24),
                        const Text('Request Body', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                          child: Text(_selectedSpan!['request_body'] ?? 'No data', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ),
                        const SizedBox(height: 24),
                        const Text('Response Body', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                          child: Text(_selectedSpan!['response_body'] ?? 'No data', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ),
                        if (_selectedSpan!['logs'] != null) ...[
                          const SizedBox(height: 24),
                          const Text('Logs', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...(_selectedSpan!['logs'] as List).map((log) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(log['level'] ?? 'INFO', style: TextStyle(color: log['level'] == 'ERROR' ? Colors.redAccent : Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Text(log['timestamp']?.toString().split('T').last.substring(0, 8) ?? '', style: const TextStyle(color: Colors.white10, fontSize: 10)),
                                  ],
                                ),
                                Text(log['message'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                              ],
                            ),
                          )),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Annotations/Insights Sidebar (only if no span selected)
          if (_selectedSpan == null)
            Container(
              width: 300,
              margin: const EdgeInsets.only(right: 24, top: 24, bottom: 24),
              decoration: BoxDecoration(
                color: TracelyTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Collaborative Insights
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('Collaborative Insights', style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _annotations.where((a) => a['parent_id'] == null).length,
                      itemBuilder: (context, index) {
                        final roots = _annotations.where((a) => a['parent_id'] == null).toList();
                        final annotation = roots[index];
                        final replies = _annotations.where((a) => a['parent_id'] == annotation['id']).toList();
                        
                        return _AnnotationThreadWidget(
                          root: annotation,
                          replies: replies,
                          onReply: (content) async {
                            await _apiService.createTraceReply(widget.traceId, annotation['id'], content);
                            _fetchAnnotations();
                          },
                          onResolve: (resolved) async {
                            await _apiService.resolveAnnotationThread(annotation['id'], resolved);
                            _fetchAnnotations();
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Add an insight...',
                        suffixIcon: const Icon(Icons.send, size: 18),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (value) async {
                         if (value.trim().isEmpty) return;
                         await _apiService.createTraceAnnotation(widget.traceId, value);
                         _fetchAnnotations();
                      },
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  // System Health Overlay
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('System Health', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        if (_metrics != null) ...[
                          _HealthRow(
                            label: 'Avg CPU', 
                            value: '${(_metrics!['cpu_avg'] ?? 0).toStringAsFixed(1)}%', 
                            color: Colors.blueAccent
                          ),
                          const SizedBox(height: 8),
                          _HealthRow(
                            label: 'Avg Memory', 
                            value: '${(_metrics!['memory_avg_mb'] ?? 0).toStringAsFixed(1)} MB', 
                            color: Colors.purpleAccent
                          ),
                        ] else 
                          const Text('No metrics available', style: TextStyle(color: Colors.white24, fontSize: 13)),
                        
                        if (_anomalies.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text('Anomalies Detected', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 12),
                          ..._anomalies.map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
                                const SizedBox(width: 8),
                                Expanded(child: Text('${a['message']}', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                              ],
                            ),
                          )),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddSpanCommentDialog(BuildContext context, String spanId) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TracelyTheme.surfaceColor,
        title: Text('Comment on Span: $spanId', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Add an insight...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _apiService.createTraceAnnotation(widget.traceId, controller.text, spanId: spanId);
                _fetchAnnotations();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add Comment'),
          ),
        ],
      ),
    );
  }


  Widget _buildWaterfallView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Waterfall Analysis', style: Theme.of(context).textTheme.headlineMedium),
            Row(
              children: [
                _Legend(label: 'Network', color: Colors.blue),
                const SizedBox(width: 16),
                _Legend(label: 'Execution', color: TracelyTheme.primaryColor),
                const SizedBox(width: 16),
                _Legend(label: 'Critical Path', color: Colors.redAccent),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: Colors.white54),
                  onPressed: _fetchTraceDetails,
                  tooltip: 'Refresh Trace',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (_traceData?['tree'] == null || (_traceData!['tree'] as List).isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics_outlined, size: 48, color: Colors.white10),
                  const SizedBox(height: 16),
                  const Text('No Spans Found', style: TextStyle(color: Colors.white30)),
                  const SizedBox(height: 8),
                  const Text('The trace may still be processing or contains no spans.', style: TextStyle(color: Colors.white24, fontSize: 12)),
                  const SizedBox(height: 24),
                  TextButton(onPressed: _fetchTraceDetails, child: const Text('Check Again')),
                ],
              ),
            ),
          )
        else
          Expanded(child: _WaterfallPainter(
            spans: _traceData?['tree'] ?? [], 
            criticalPath: List<String>.from(_traceData?['critical_path'] ?? []),
            onAddComment: (spanId) => _showAddSpanCommentDialog(context, spanId),
            onSelectSpan: (span) => setState(() => _selectedSpan = span),
            selectedSpanId: _selectedSpan?['span_id'],
          )),
      ],
    );
  }

  Widget _buildUnifiedTimeline() {
    final logs = _traceData?['logs'] as List? ?? [];
    final tree = _traceData?['tree'] as List? ?? [];
    
    // Flatten tree to get all spans
    List<dynamic> allSpans = [];
    void flatten(List<dynamic> nodes) {
      for (var node in nodes) {
        allSpans.add(node['span']);
        if (node['children'] != null) flatten(node['children']);
      }
    }
    flatten(tree);

    // Merge and sort
    List<dynamic> events = [];
    for (var span in allSpans) {
      events.add({'type': 'span', 'data': span, 'time': DateTime.parse(span['start_time'])});
    }
    for (var log in logs) {
      events.add({'type': 'log', 'data': log, 'time': DateTime.parse(log['timestamp'])});
    }
    events.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        if (event['type'] == 'span') {
          final span = event['data'];
          return ListTile(
            leading: const Icon(Icons.compare_arrows, color: TracelyTheme.primaryColor, size: 16),
            title: Text('${span['service_name']}: ${span['operation_name']}', style: const TextStyle(fontSize: 13)),
            trailing: Text('${span['duration_ms']}ms', style: const TextStyle(color: Colors.white24, fontSize: 11)),
          );
        } else {
          final log = event['data'];
          return ListTile(
            leading: Icon(Icons.notes, color: log['level'] == 'ERROR' ? Colors.redAccent : Colors.white24, size: 14),
            title: Text(log['message'], style: TextStyle(fontSize: 12, color: log['level'] == 'ERROR' ? Colors.redAccent : Colors.white70)),
            subtitle: Text(log['service'], style: const TextStyle(fontSize: 10, color: Colors.white24)),
          );
        }
      },
    );
  }

  Widget _buildMetricsView() {
    if (_metrics == null) {
      return const Center(child: Text('Loading metrics...', style: TextStyle(color: Colors.white54)));
    }

    final metricsData = _metrics!['metrics'] as Map<String, dynamic>? ?? {};
    final summary = _metrics!['summary'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System Metrics Overlay', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          // Summary Cards
          Row(
            children: [
              _MetricCard(
                title: 'Avg CPU',
                value: '${(summary['cpu_avg'] ?? 0).toStringAsFixed(1)}%',
                icon: Icons.memory,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 16),
              _MetricCard(
                title: 'Avg Memory',
                value: '${(summary['memory_avg_mb'] ?? 0).toStringAsFixed(1)} MB',
                icon: Icons.storage,
                color: Colors.purpleAccent,
              ),
              const SizedBox(width: 16),
              _MetricCard(
                title: 'Request Count',
                value: '${summary['request_count'] ?? 0}',
                icon: Icons.speed,
                color: Colors.greenAccent,
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Anomalies Section
          if (_anomalies.isNotEmpty) ...[
            Text('Anomalies Detected', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.redAccent)),
            const SizedBox(height: 16),
            ..._anomalies.map((anomaly) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    anomaly['message'] ?? 'Unknown anomaly',
                    style: const TextStyle(color: Colors.white70),
                  )),
                ],
              ),
            )),
            const SizedBox(height: 24),
          ],
          // Metrics Timeline
          Text('Metrics Timeline', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (metricsData.isNotEmpty)
            ...metricsData.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 100, child: Text(entry.key, style: const TextStyle(color: Colors.white54, fontSize: 12))),
                  Expanded(child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (entry.value as num? ?? 0) / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: TracelyTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Text('${entry.value}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ))
          else
            const Text('No metrics data available for this trace', style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _HealthRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}


class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _HeaderStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;

  const _Legend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

class _WaterfallPainter extends StatefulWidget {
  final List<dynamic> spans;
  final List<String> criticalPath;
  final Function(String spanId)? onAddComment;
  final Function(Map<String, dynamic> span)? onSelectSpan;
  final String? selectedSpanId;

  const _WaterfallPainter({
    required this.spans, 
    required this.criticalPath,
    this.onAddComment,
    this.onSelectSpan,
    this.selectedSpanId,
  });

  @override
  State<_WaterfallPainter> createState() => _WaterfallPainterState();
}

class _WaterfallPainterState extends State<_WaterfallPainter> {
  final Set<int> _expandedIndices = {};

  @override
  Widget build(BuildContext context) {
    if (widget.spans.isEmpty) return const Center(child: Text('No spans found', style: TextStyle(color: Colors.white24)));

    double maxEnd = 0;
    void findMax(List<dynamic> nodes) {
      for (var node in nodes) {
        final span = node['span'];
        if (span == null) continue;
        double offset = (span['offset_ms'] ?? 0.0).toDouble();
        double duration = (span['duration_ms'] ?? 0.0).toDouble();
        double end = offset + duration;
        if (end > maxEnd) maxEnd = end;
        if (node['children'] != null) findMax(node['children']);
      }
    }
    findMax(widget.spans);

    List<Widget> buildRows(List<dynamic> nodes, int depth) {
      List<Widget> rows = [];
      for (var node in nodes) {
        final span = node['span'];
        if (span == null) continue;
        final String spanID = span['span_id'] ?? '';
        final bool isCritical = widget.criticalPath.contains(spanID);
        final int uniqueId = spanID.hashCode;
        final bool isExpanded = _expandedIndices.contains(uniqueId);
        final List<dynamic> children = node['children'] ?? [];

        rows.add(
          InkWell(
            onTap: () {
              if (widget.onSelectSpan != null) {
                widget.onSelectSpan!(span);
              }
              setState(() => isExpanded ? _expandedIndices.remove(uniqueId) : _expandedIndices.add(uniqueId));
            },
            child: Container(
              decoration: BoxDecoration(
                color: widget.selectedSpanId == spanID ? TracelyTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.only(left: depth * 16.0, top: 8, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (children.isNotEmpty)
                            Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 16, color: Colors.white24),
                          Text('${span['service_name']}: ${span['operation_name']}', 
                            style: TextStyle(
                              fontSize: 13, 
                              color: isCritical ? Colors.redAccent : Colors.white70,
                              fontWeight: isCritical ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (isCritical) 
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: const Text('CRITICAL', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.comment_outlined, size: 14, color: Colors.white24),
                            onPressed: () {
                              if (widget.onAddComment != null) {
                                widget.onAddComment!(spanID);
                              }
                            },
                            tooltip: 'Add Span Comment',
                          ),
                          Text('${span['duration_ms']}ms', style: const TextStyle(fontSize: 12, color: Colors.white30)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(width: ((span['offset_ms'] ?? 0.0) / (maxEnd == 0 ? 1 : maxEnd)) * MediaQuery.of(context).size.width * 0.4),
                      Container(
                        width: ((span['duration_ms'] ?? 0.0) / (maxEnd == 0 ? 1 : maxEnd)) * MediaQuery.of(context).size.width * 0.4,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isCritical ? Colors.redAccent : TracelyTheme.primaryColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: isCritical ? [
                            BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)
                          ] : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        if (isExpanded && children.isNotEmpty) {
          rows.addAll(buildRows(children, depth + 1));
        }
      }
      return rows;
    }

    return ListView(children: buildRows(widget.spans, 0));
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? TracelyTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? TracelyTheme.primaryColor : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class _AnnotationThreadWidget extends StatefulWidget {
  final Map<String, dynamic> root;
  final List<dynamic> replies;
  final Function(String) onReply;
  final Function(bool) onResolve;

  const _AnnotationThreadWidget({
    required this.root,
    required this.replies,
    required this.onReply,
    required this.onResolve,
  });

  @override
  State<_AnnotationThreadWidget> createState() => _AnnotationThreadWidgetState();
}

class _AnnotationThreadWidgetState extends State<_AnnotationThreadWidget> {
  bool _isReplying = false;
  final _replyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final bool isResolved = widget.root['resolved'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isResolved ? Colors.green.withOpacity(0.05) : Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: isResolved ? Border.all(color: Colors.green.withOpacity(0.2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.root['content'],
                  style: TextStyle(
                    color: isResolved ? Colors.white54 : Colors.white70,
                    fontSize: 13,
                    decoration: isResolved ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (!isResolved)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                  onPressed: () => widget.onResolve(true),
                  tooltip: 'Resolve',
                )
              else
                IconButton(
                  icon: const Icon(Icons.replay, size: 16, color: Colors.orange),
                  onPressed: () => widget.onResolve(false),
                  tooltip: 'Reopen',
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'By ${widget.root['user_id']?.toString().substring(0, 8) ?? "Team"} • ${isResolved ? "Resolved" : "Active"}',
            style: const TextStyle(color: Colors.white24, fontSize: 10),
          ),
          
          if (widget.replies.isNotEmpty) ...[
            const Divider(color: Colors.white10),
            ...widget.replies.map((reply) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reply['content'], style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  Text(
                    'By ${reply['user_id']?.toString().substring(0, 8) ?? "Team"}',
                    style: const TextStyle(color: Colors.white10, fontSize: 9),
                  ),
                ],
              ),
            )),
          ],

          if (!isResolved) ...[
            if (_isReplying)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Write a reply...',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, size: 16, color: Colors.orange),
                      onPressed: () {
                        if (_replyController.text.isNotEmpty) {
                          widget.onReply(_replyController.text);
                          _replyController.clear();
                          setState(() => _isReplying = false);
                        }
                      },
                    ),
                  ],
                ),
              )
            else
              TextButton(
                onPressed: () => setState(() => _isReplying = true),
                child: const Text('Reply', style: TextStyle(fontSize: 11, color: Colors.orange)),
              ),
          ],
        ],
      ),
    );
  }
}




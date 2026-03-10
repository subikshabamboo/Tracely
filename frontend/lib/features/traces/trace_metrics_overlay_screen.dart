import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';

class TraceMetricsOverlayScreen extends StatefulWidget {
  final String traceId;

  const TraceMetricsOverlayScreen({super.key, required this.traceId});

  @override
  State<TraceMetricsOverlayScreen> createState() => _TraceMetricsOverlayScreenState();
}

class _TraceMetricsOverlayScreenState extends State<TraceMetricsOverlayScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _metricsData;
  List<dynamic> _anomalies = [];
  
  // Selected metric for detailed view
  String _selectedMetric = 'cpu';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchMetrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMetrics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.getTraceMetricsWithAnomalies(widget.traceId);
      
      if (result.isSuccess && result.data != null) {
        setState(() {
          _metricsData = result.data;
          _anomalies = result.data['anomalies'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result.error ?? 'Failed to load metrics';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Metrics Overlay', style: TextStyle(fontSize: 18, color: Colors.white70)),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/traces/${widget.traceId}'),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TracelyTheme.primaryColor,
          tabs: const [
            Tab(text: 'Metrics'),
            Tab(text: 'Anomalies'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? _buildErrorView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMetricsTab(),
                _buildAnomaliesTab(),
                _buildSummaryTab(),
              ],
            ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchMetrics,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trace Info
          _buildTraceInfoCard(),
          const SizedBox(height: 24),
          
          // Metric Selector
          _buildMetricSelector(),
          const SizedBox(height: 24),
          
          // Metric Charts
          _buildMetricChart('CPU Usage (%)', 'cpu', Colors.blue, _metricsData?['metrics']?['cpu'] ?? []),
          const SizedBox(height: 24),
          _buildMetricChart('Memory Usage (MB)', 'memory', Colors.purple, _metricsData?['metrics']?['memory'] ?? []),
          const SizedBox(height: 24),
          _buildMetricChart('Network I/O (KB/s)', 'network', Colors.green, _metricsData?['metrics']?['network'] ?? []),
          const SizedBox(height: 24),
          _buildMetricChart('DB Connections', 'db_connections', Colors.orange, _metricsData?['metrics']?['db_connections'] ?? []),
          const SizedBox(height: 24),
          _buildMetricChart('Disk I/O (KB/s)', 'disk_io', Colors.teal, _metricsData?['metrics']?['disk_io'] ?? []),
          const SizedBox(height: 24),
          _buildMetricChart('GC Pauses (ms)', 'gc_pauses', Colors.red, _metricsData?['metrics']?['gc_pauses'] ?? []),
        ],
      ),
    );
  }

  Widget _buildTraceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TracelyTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined, color: TracelyTheme.primaryColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trace: ${_metricsData?['trace_id'] ?? widget.traceId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Service: ${_metricsData?['service_name'] ?? 'Unknown'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _fetchMetrics,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSelector() {
    final metrics = [
      {'key': 'cpu', 'label': 'CPU', 'icon': Icons.memory, 'color': Colors.blue},
      {'key': 'memory', 'label': 'Memory', 'icon': Icons.storage, 'color': Colors.purple},
      {'key': 'network', 'label': 'Network', 'icon': Icons.network_check, 'color': Colors.green},
      {'key': 'db', 'label': 'DB', 'icon': Icons.table_chart, 'color': Colors.orange},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TracelyTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Metric', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: metrics.map((m) {
              final isSelected = _selectedMetric == m['key'];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => setState(() => _selectedMetric = m['key'] as String),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? (m['color'] as Color).withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? (m['color'] as Color) : Colors.white10,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(m['icon'] as IconData, color: m['color'] as Color, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            m['label'] as String,
                            style: TextStyle(
                              color: isSelected ? (m['color'] as Color) : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChart(String title, String metricKey, Color color, List<dynamic> dataPoints) {
    // Convert data points
    final points = dataPoints.map((p) {
      if (p is Map) {
        return {'timestamp': p['timestamp'] ?? 0, 'value': p['value'] ?? 0};
      }
      return {'timestamp': 0, 'value': 0};
    }).toList();

    // Calculate stats
    double maxVal = 0;
    double avgVal = 0;
    if (points.isNotEmpty) {
      double sum = 0;
      for (var p in points) {
        final val = (p['value'] as num?)?.toDouble() ?? 0;
        if (val > maxVal) maxVal = val;
        sum += val;
      }
      avgVal = sum / points.length;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TracelyTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Text('${points.length} data points', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Stats Row
          Row(
            children: [
              _buildStatChip('Current', '${(points.isNotEmpty ? (points.last['value'] ?? 0) : 0).toStringAsFixed(1)}', color),
              const SizedBox(width: 12),
              _buildStatChip('Avg', avgVal.toStringAsFixed(1), Colors.white54),
              const SizedBox(width: 12),
              _buildStatChip('Max', maxVal.toStringAsFixed(1), Colors.redAccent),
            ],
          ),
          const SizedBox(height: 20),
          
          // Simple bar chart visualization
          if (points.isNotEmpty)
            SizedBox(
              height: 100,
              child: CustomPaint(
                size: const Size(double.infinity, 100),
                painter: MetricChartPainter(points, color, maxVal > 0 ? maxVal : 100),
              ),
            )
          else
            Container(
              height: 100,
              alignment: Alignment.center,
              child: const Text('No data available', style: TextStyle(color: Colors.white24)),
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAnomaliesTab() {
    if (_anomalies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('No anomalies detected', style: TextStyle(color: Colors.white54, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('System metrics are within normal ranges', style: TextStyle(color: Colors.white24)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _anomalies.length,
      itemBuilder: (context, index) {
        final anomaly = _anomalies[index];
        final severity = anomaly['severity'] ?? 'low';
        final severityColor = severity == 'high' ? Colors.red : severity == 'medium' ? Colors.orange : Colors.yellow;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TracelyTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: severityColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  severity == 'high' ? Icons.warning : Icons.info_outline,
                  color: severityColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anomaly['type'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      anomaly['message'] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: TextStyle(color: severityColor, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryTab() {
    final summary = _metricsData?['summary'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(child: _buildSummaryCard('CPU Average', '${summary['cpu_avg']?.toStringAsFixed(1) ?? '0'}%', Icons.memory, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryCard('Memory Average', '${summary['memory_avg_mb']?.toStringAsFixed(0) ?? '0'} MB', Icons.storage, Colors.purple)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSummaryCard('Has Metrics', summary['has_metrics'] == true ? 'Yes' : 'No', Icons.check_circle, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryCard('Anomalies', '${_anomalies.length}', Icons.warning, _anomalies.isEmpty ? Colors.green : Colors.orange)),
            ],
          ),
          const SizedBox(height: 32),
          
          // Time Range
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: TracelyTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Time Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Start:', style: TextStyle(color: Colors.white54)),
                    Text(_formatTimestamp(summary['time_range']?['start'])),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('End:', style: TextStyle(color: Colors.white54)),
                    Text(_formatTimestamp(summary['time_range']?['end'])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // System Health Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _anomalies.isEmpty ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _anomalies.isEmpty ? Colors.green : Colors.orange),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _anomalies.isEmpty ? Icons.verified : Icons.warning,
                  color: _anomalies.isEmpty ? Colors.green : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _anomalies.isEmpty ? 'System Health: Good' : 'System Health: Warning',
                  style: TextStyle(
                    color: _anomalies.isEmpty ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TracelyTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24)),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'N/A';
    if (ts is int) {
      return DateTime.fromMillisecondsSinceEpoch(ts).toString().substring(0, 19);
    }
    return ts.toString();
  }
}

// Custom painter for metric chart
class MetricChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> dataPoints;
  final Color color;
  final double maxValue;

  MetricChartPainter(this.dataPoints, this.color, this.maxValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    
    final pointWidth = size.width / (dataPoints.length - 1).clamp(1, dataPoints.length);

    for (int i = 0; i < dataPoints.length; i++) {
      final value = (dataPoints[i]['value'] as num?)?.toDouble() ?? 0;
      final normalizedValue = (value / maxValue).clamp(0.0, 1.0);
      final x = i * pointWidth;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw line
    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dataPoints.length; i++) {
      final value = (dataPoints[i]['value'] as num?)?.toDouble() ?? 0;
      final normalizedValue = (value / maxValue).clamp(0.0, 1.0);
      final x = i * pointWidth;
      final y = size.height - (normalizedValue * size.height);
      
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


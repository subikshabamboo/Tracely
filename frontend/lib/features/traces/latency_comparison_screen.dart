import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';

class LatencyComparisonScreen extends StatefulWidget {
  final String traceId1;
  final String? traceId2;
  const LatencyComparisonScreen({super.key, required this.traceId1, this.traceId2});

  @override
  State<LatencyComparisonScreen> createState() => _LatencyComparisonScreenState();
}

class _LatencyComparisonScreenState extends State<LatencyComparisonScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _trace1;
  Map<String, dynamic>? _trace2;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final res1 = await _apiService.getWaterfall(widget.traceId1);
    if (widget.traceId2 != null) {
      final res2 = await _apiService.getWaterfall(widget.traceId2!);
      if (res2.isSuccess) _trace2 = res2.data;
    }
    
    if (res1.isSuccess) {
      setState(() {
        _trace1 = res1.data;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Latency Comparison', style: TextStyle(color: Colors.white70)),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _buildComparisonHeader(),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTraceWaterfall(_trace1, 'Trace A')),
                const VerticalDivider(color: Colors.white10),
                Expanded(child: _buildTraceWaterfall(_trace2, 'Trace B (Baseline)')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonHeader() {
    final d1 = _trace1?['duration_ms'] ?? 0;
    final d2 = _trace2?['duration_ms'] ?? 0;
    final diff = d1 - d2;
    final percent = d2 == 0 ? 0 : (diff / d2 * 100).round();

    return Container(
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
          _Stat(label: 'Trace A', value: '${d1}ms'),
          Icon(Icons.compare_arrows, color: diff > 0 ? Colors.redAccent : Colors.greenAccent),
          _Stat(label: 'Trace B', value: '${d2}ms'),
          _Stat(
            label: 'Difference', 
            value: '${diff > 0 ? "+" : ""}${diff}ms ($percent%)',
            color: diff > 0 ? Colors.redAccent : Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildTraceWaterfall(Map<String, dynamic>? data, String label) {
    if (data == null) return Center(child: Text('Select $label to compare', style: const TextStyle(color: Colors.white24)));
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white38)),
        ),
        // Simple list view for comparison
        Expanded(
          child: ListView.builder(
            itemCount: (data['tree'] as List?)?.length ?? 0,
            itemBuilder: (context, index) {
              final nodes = data['tree'] as List;
              final node = nodes[index];
              final span = node['span'];
              if (span == null) return const SizedBox();
              
              final duration = (span['duration_ms'] ?? 0).toDouble();
              final totalDuration = (data['duration_ms'] ?? 1).toDouble();

              return ListTile(
                title: Text(span['operation_name'] ?? 'Unknown', style: const TextStyle(fontSize: 12)),
                subtitle: LinearProgressIndicator(
                  value: duration / totalDuration,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  color: TracelyTheme.primaryColor,
                ),
                trailing: Text('${duration.toInt()}ms', style: const TextStyle(fontSize: 10, color: Colors.white24)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 12)),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

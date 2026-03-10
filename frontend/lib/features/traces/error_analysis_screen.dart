import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';

class ErrorAnalysisScreen extends StatefulWidget {
  const ErrorAnalysisScreen({super.key});

  @override
  State<ErrorAnalysisScreen> createState() => _ErrorAnalysisScreenState();
}

class _ErrorAnalysisScreenState extends State<ErrorAnalysisScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _patterns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    final workspaceId = await _apiService.getActiveWorkspaceId();
    final result = await _apiService.safeGet('/traces/analytics/errors?workspace_id=$workspaceId');
    if (mounted) {
      setState(() {
        if (result.isSuccess) _patterns = result.data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error Pattern Analysis')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _patterns.length,
            itemBuilder: (context, index) {
              final pattern = _patterns[index];
              return Card(
                color: TracelyTheme.surfaceColor,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(pattern['service'] ?? 'Unknown', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                          Text('${pattern['count'] ?? 0} occurrences', style: const TextStyle(color: Colors.white24, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(pattern['message'] ?? 'No error message available', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                               final traceId = pattern['sample_trace_id'];
                               if (traceId != null) {
                                 context.push('/traces/$traceId');
                               }
                            },
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                            label: const Text('View Sample Trace'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}

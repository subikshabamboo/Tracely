import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';

class LoadTestResultsScreen extends StatefulWidget {
  const LoadTestResultsScreen({super.key});

  @override
  State<LoadTestResultsScreen> createState() => _LoadTestResultsScreenState();
}

class _LoadTestResultsScreenState extends State<LoadTestResultsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _executions = [];

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    // In a real app we'd fetch actual execution results
    // For now, we list recent replays which might be load tests
    final result = await _apiService.safeGet('/replays');
    if (result.isSuccess) {
      setState(() => _executions = result.data);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Load Test Analytics')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _executions.length,
            itemBuilder: (context, index) {
              final exec = _executions[index];
              return Card(
                color: TracelyTheme.surfaceColor,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text(exec['name'] ?? 'Load Test Execution'),
                  subtitle: Text('Status: ${exec['status']} | Results: ${exec['results']?.length ?? 0} spans'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';

class CICDPipelineStatusScreen extends StatefulWidget {
  const CICDPipelineStatusScreen({super.key});

  @override
  State<CICDPipelineStatusScreen> createState() => _CICDPipelineStatusScreenState();
}

class _CICDPipelineStatusScreenState extends State<CICDPipelineStatusScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _pipelines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final result = await _apiService.getCiStatus(null);
      if (mounted && result.isSuccess) {
        setState(() {
          _pipelines = result.data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CI/CD Deployment Gates')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active Deployment Gates', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: TracelyTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pipelines.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final p = _pipelines[index];
                      return _GateItem(
                        name: p['repo'] ?? 'Unknown Repo',
                        status: p['status'] ?? 'UNKNOWN',
                        lastRun: '1h ago', // Stub for now
                        isError: p['status'] == 'failed',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _GateItem extends StatelessWidget {
  final String name;
  final String status;
  final String lastRun;
  final bool isError;
  const _GateItem({required this.name, required this.status, required this.lastRun, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Last active: $lastRun'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isError ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(status, style: TextStyle(color: isError ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

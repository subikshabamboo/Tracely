import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';
import 'mutation_history_screen.dart';
import 'cascade_simulation_screen.dart';
import 'error_injection_config_screen.dart';

class ReplayComparisonScreen extends StatefulWidget {
  final String replayId;
  const ReplayComparisonScreen({super.key, required this.replayId});

  @override
  State<ReplayComparisonScreen> createState() => _ReplayComparisonScreenState();
}

class _ReplayComparisonScreenState extends State<ReplayComparisonScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _comparison;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComparison();
  }

  Future<void> _fetchComparison() async {
    try {
      final response = await _apiService.get('/replays/${widget.replayId}/comparison');
      if (response.statusCode == 200) {
        setState(() {
          _comparison = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Replay Comparison'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.orange),
            tooltip: 'Mutation History',
            onPressed: () {
              final executionId = _comparison?['execution_id'];
              if (executionId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MutationHistoryScreen(executionId: executionId),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.hub, color: Colors.orange),
            tooltip: 'Cascade Simulation',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CascadeSimulationScreen(workspaceId: _comparison?['workspace_id'] ?? 'default'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.speed, color: Colors.orange),
            tooltip: 'Ramp Load Test',
            onPressed: () => _showRampConfig(context),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orange),
            tooltip: 'Error Injection Rules',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ErrorInjectionConfigScreen(workspaceId: _comparison?['workspace_id'] ?? 'default'),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _comparison == null
              ? const Center(child: Text('No comparison data available'))
              : Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 24),
                      Expanded(child: _buildDiffView()),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      color: TracelyTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryItem(label: 'Status', value: _comparison!['diff_status'], color: _getStatusColor(_comparison!['diff_status'])),
            _SummaryItem(label: 'Latency Δ', value: '${_comparison!['latency_diff_ms']}ms'),
            _SummaryItem(label: 'Nodes Matched', value: '12/12'),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'identical': return Colors.green;
      case 'minor_diff': return Colors.orange;
      case 'major_diff': return Colors.red;
      default: return Colors.blue;
    }
  }

  Widget _buildDiffView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: TracelyTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Response Diff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Text(
              _comparison!['response_diff'] ?? 'No significant differences in response body.',
              style: const TextStyle(fontFamily: 'monospace', color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRampConfig(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _RampConfigDialog(),
    );

    if (result != null) {
      final replayId = widget.replayId;
      final apiResult = await _apiService.executeLoadRamp(replayId, result);
      
      if (mounted) {
        if (apiResult.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ramp load test started successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start load test: ${apiResult.error}')),
          );
        }
      }
    }
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _SummaryItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _RampConfigDialog extends StatefulWidget {
  @override
  State<_RampConfigDialog> createState() => _RampConfigDialogState();
}

class _RampConfigDialogState extends State<_RampConfigDialog> {
  final _peakController = TextEditingController(text: '50');
  final _rampUpController = TextEditingController(text: '30');
  final _holdController = TextEditingController(text: '60');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Configure Ramp Load Test', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildField(_peakController, 'Peak Concurrent Users'),
          _buildField(_rampUpController, 'Ramp-up (seconds)'),
          _buildField(_holdController, 'Hold Duration (seconds)'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'peak_users': int.tryParse(_peakController.text) ?? 50,
              'ramp_up_seconds': int.tryParse(_rampUpController.text) ?? 30,
              'hold_seconds': int.tryParse(_holdController.text) ?? 60,
              'step_seconds': 5,
            });
          },
          child: const Text('Start Replay'),
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
      ),
    );
  }
}

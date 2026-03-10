import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';

class ThresholdConfigScreen extends StatefulWidget {
  const ThresholdConfigScreen({super.key});

  @override
  State<ThresholdConfigScreen> createState() => _ThresholdConfigScreenState();
}

class _ThresholdConfigScreenState extends State<ThresholdConfigScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  String _metric = 'duration_ms';
  double _threshold = 1000.0;
  bool _isEnabled = true;

  void _saveRule() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final workspaceId = await _apiService.getActiveWorkspaceId();
      final result = await _apiService.createAlertRule({
        'workspace_id': workspaceId,
        'metric': _metric,
        'threshold': _threshold,
        'is_enabled': _isEnabled,
      });

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert rule saved successfully!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result.error}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configure Thresholds')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Definition', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _metric,
                decoration: const InputDecoration(labelText: 'Metric'),
                items: const [
                  DropdownMenuItem(value: 'duration_ms', child: Text('Latency (ms)')),
                  DropdownMenuItem(value: 'error_rate', child: Text('Error Rate (%)')),
                ],
                onChanged: (val) => setState(() => _metric = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _threshold.toString(),
                decoration: const InputDecoration(labelText: 'Threshold Value'),
                keyboardType: TextInputType.number,
                validator: (val) => (val == null || double.tryParse(val) == null) ? 'Invalid number' : null,
                onSaved: (val) => _threshold = double.parse(val!),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Enable Alerting'),
                subtitle: const Text('Trigger violations when threshold is exceeded'),
                value: _isEnabled,
                activeColor: TracelyTheme.primaryColor,
                onChanged: (val) => setState(() => _isEnabled = val),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveRule,
                  child: const Text('Save Alert Rule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

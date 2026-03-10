import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import 'dart:convert';

class AlertManagementScreen extends StatefulWidget {
  const AlertManagementScreen({super.key});

  @override
  State<AlertManagementScreen> createState() => _AlertManagementScreenState();
}

class _AlertManagementScreenState extends State<AlertManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _alertRules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAlertRules();
  }

  Future<void> _fetchAlertRules() async {
    final result = await _apiService.getAlertRules(null);
    if (mounted) {
      setState(() {
        if (result.isSuccess) {
          _alertRules = result.data;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert Management')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: () {}, // TODO: Open creation dialog
              icon: const Icon(Icons.add_alert),
              label: const Text('Create Alert Rule'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _alertRules.length,
                      itemBuilder: (context, index) {
                        final rule = _alertRules[index];
                        return Card(
                          color: TracelyTheme.surfaceColor,
                          child: ListTile(
                            leading: Icon(
                              rule['severity'] == 'critical' ? Icons.error : Icons.warning,
                              color: rule['severity'] == 'critical' ? Colors.red : Colors.orange,
                            ),
                            title: Text('${rule['metric']} > ${rule['threshold']}'),
                            subtitle: Text('Severity: ${rule['severity']}'),
                            trailing: Switch(
                              value: rule['is_enabled'] ?? true,
                              onChanged: (val) {},
                            ),
                          ),
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

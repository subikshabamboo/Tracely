import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    try {
      final result = await _apiService.getAuditLogs(null);
      if (mounted) {
        if (result.isSuccess) {
          setState(() {
            _logs = result.data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access Audit Logs')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: _logs.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.white10),
            itemBuilder: (context, index) {
              final log = _logs[index];
              final date = DateTime.parse(log['timestamp']);
              
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getActionColor(log['action']).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getActionIcon(log['action']),
                    color: _getActionColor(log['action']),
                    size: 20,
                  ),
                ),
                title: Text(log['action'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Resource: ${log['resource']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('Metadata: ${log['metadata']}', style: const TextStyle(color: Colors.white24, fontSize: 11)),
                  ],
                ),
                trailing: Text(
                  DateFormat('MMM dd, HH:mm:ss').format(date),
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              );
            },
          ),
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('DELETE')) return Colors.redAccent;
    if (action.contains('CREATE')) return Colors.greenAccent;
    if (action.contains('UPDATE')) return Colors.blueAccent;
    return TracelyTheme.primaryColor;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('DELETE')) return Icons.delete_outline;
    if (action.contains('CREATE')) return Icons.add_circle_outline;
    if (action.contains('UPDATE')) return Icons.edit_outlined;
    return Icons.history_toggle_off;
  }
}

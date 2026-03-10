import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ErrorInjectionConfigScreen extends StatefulWidget {
  final String workspaceId;

  const ErrorInjectionConfigScreen({super.key, required this.workspaceId});

  @override
  State<ErrorInjectionConfigScreen> createState() => _ErrorInjectionConfigScreenState();
}

class _ErrorInjectionConfigScreenState extends State<ErrorInjectionConfigScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _configs = [];

  @override
  void initState() {
    super.initState();
    _fetchConfigs();
  }

  Future<void> _fetchConfigs() async {
    final result = await _apiService.getErrorInjections(widget.workspaceId);
    if (mounted) {
      setState(() {
        _configs = result.data ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Injection Rules'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.orange),
            onPressed: () {
              // Dialog to add rule
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F0F), Color(0xFF1A1A1A)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
            : _configs.isEmpty
                ? const Center(
                    child: Text('No injection rules configured',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _configs.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final config = _configs[index];
                      return Card(
                        color: Colors.black45,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(config['name'] ?? 'Rule', style: const TextStyle(color: Colors.white)),
                          subtitle: Text('${config['service_name']} -> ${config['error_code']}',
                              style: const TextStyle(color: Colors.grey)),
                          trailing: Switch(
                            value: config['is_enabled'] ?? true,
                            onChanged: (val) {
                              // Update rule
                            },
                            activeColor: Colors.orange,
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

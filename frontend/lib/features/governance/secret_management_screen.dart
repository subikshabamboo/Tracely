import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import 'dart:convert';

class SecretManagementScreen extends StatefulWidget {
  const SecretManagementScreen({super.key});

  @override
  State<SecretManagementScreen> createState() => _SecretManagementScreenState();
}

class _SecretManagementScreenState extends State<SecretManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _secrets = [];
  bool _isLoading = true;
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSecrets();
  }

  Future<void> _fetchSecrets() async {
    final result = await _apiService.getSecrets(null);
    if (mounted) {
      setState(() {
        if (result.isSuccess) {
          _secrets = result.data;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _addSecret() async {
    final result = await _apiService.addSecret(null, _keyController.text, _valueController.text);
    if (result.isSuccess) {
      _keyController.clear();
      _valueController.clear();
      _fetchSecrets();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add secret: ${result.error}')),
        );
      }
    }
  }

  Future<void> _deleteSecret(String id) async {
    final result = await _apiService.deleteSecret(id);
    if (result.isSuccess) {
      _fetchSecrets();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete secret: ${result.error}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secret Management')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Card(
              color: TracelyTheme.surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _keyController,
                        decoration: const InputDecoration(labelText: 'Secret Key'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _valueController,
                        decoration: const InputDecoration(labelText: 'Value'),
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _addSecret,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _secrets.length,
                      itemBuilder: (context, index) {
                        final secret = _secrets[index];
                        return ListTile(
                          title: Text(secret['key']),
                          subtitle: const Text('********'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteSecret(secret['id']),
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

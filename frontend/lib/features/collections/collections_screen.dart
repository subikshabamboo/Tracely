import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _collections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCollections();
  }

  Future<void> _fetchCollections() async {
    final result = await _apiService.getCollections(null);
    if (mounted) {
      if (result.isSuccess) {
        setState(() {
          _collections = result.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCreateCollectionDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TracelyTheme.surfaceColor,
        title: const Text('New Collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final workspaceId = await _apiService.getActiveWorkspaceId();
              final result = await _apiService.safePost('/collections', {
                'name': nameController.text,
                'description': descController.text,
                'workspace_id': workspaceId,
              });
              if (result.isSuccess) {
                if (mounted) Navigator.pop(context);
                _fetchCollections();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _importPostman() async {
    // In a real app, we'd use file_picker. For now, we'll simulate an import.
    final workspaceId = await _apiService.getActiveWorkspaceId();
    if (workspaceId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importing Postman Collection...')));
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    final result = await _apiService.safePost('/collections', {
      'name': 'Imported Collection ${DateTime.now().millisecondsSinceEpoch}',
      'description': 'Imported from Postman',
      'workspace_id': workspaceId,
    });

    if (result.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collection imported successfully')));
        _fetchCollections();
      }
    }
  }
  void _showVersionHistory(String name) async {
    final result = await _apiService.getCollectionVersions(name, null);
    if (!result.isSuccess) return;

    final versions = result.data as List<dynamic>;

    showModalBottomSheet(
      context: context,
      backgroundColor: TracelyTheme.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version History: $name', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ...versions.map((v) => ListTile(
                  leading: const Icon(Icons.history, color: Colors.white30),
                  title: Text('Version ${v['version']}', style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Created: ${v['created_at']}', style: const TextStyle(color: Colors.white24, fontSize: 12)),
                  trailing: TextButton(
                    onPressed: () {}, // Rollback logic
                    child: const Text('Rollback'),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/collections/${v['id']}');
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections', style: TextStyle(fontSize: 18, color: Colors.white70)),
        backgroundColor: Colors.transparent,
        actions: [
          ElevatedButton.icon(
            onPressed: _showCreateCollectionDialog,
            icon: const Icon(Icons.add),
            label: const Text('New Collection'),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _importPostman,
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Import Postman'),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: _collections.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final collection = _collections[index];
                return InkWell(
                  onTap: () => context.go('/collections/${collection['id']}'),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: TracelyTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_outlined, color: Colors.orangeAccent),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${collection['name']} (v${collection['version'] ?? 1})', 
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${collection['description'] ?? "No description"}', 
                                  style: const TextStyle(color: Colors.white24, fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showVersionHistory(collection['name']),
                          child: const Text('History', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_arrow_outlined, color: Colors.greenAccent),
                          onPressed: () {}, // Run collection
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

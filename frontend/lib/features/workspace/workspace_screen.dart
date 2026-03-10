import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/tracely_sidebar.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _workspaces = [];
  String? _activeWorkspaceId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWorkspaces();
    _loadActiveWorkspace();
    ApiService.activeWorkspaceNotifier.addListener(_onWorkspaceChanged);
  }

  @override
  void dispose() {
    ApiService.activeWorkspaceNotifier.removeListener(_onWorkspaceChanged);
    super.dispose();
  }

  void _onWorkspaceChanged() {
    if (mounted) {
      setState(() => _activeWorkspaceId = ApiService.activeWorkspaceNotifier.value);
    }
  }

  Future<void> _loadActiveWorkspace() async {
    final id = await _apiService.getActiveWorkspaceId();
    if (mounted) setState(() => _activeWorkspaceId = id);
  }

  Future<void> _fetchWorkspaces() async {
    try {
      final result = await _apiService.getWorkspaces();
      if (mounted) {
        if (result.isSuccess) {
          setState(() {
            _workspaces = result.data ?? [];
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectWorkspace(String id) async {
    await _apiService.setActiveWorkspace(id);
    if (mounted) {
      setState(() => _activeWorkspaceId = id);
      // Wait a bit to ensure the notification propagates before navigating
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) context.go('/dashboard');
      });
    }
  }

  Future<void> _deleteWorkspace(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TracelyTheme.surfaceColor,
        title: const Text('Delete Workspace'),
        content: const Text('Are you sure you want to delete this workspace? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _apiService.deleteWorkspace(id);
      if (result.isSuccess) {
        if (_activeWorkspaceId == id) {
          _apiService.setActiveWorkspace('');
          _activeWorkspaceId = null;
        }
        _fetchWorkspaces();
      }
    }
  }

  void _createWorkspace() async {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TracelyTheme.surfaceColor,
        title: const Text('Create Workspace'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Workspace Name'),
          onSubmitted: (_) {
            Navigator.pop(dialogContext);
            _handleCreate(nameController.text.trim());
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleCreate(nameController.text.trim());
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreate(String name) async {
    if (name.isEmpty) return;
    
    final result = await _apiService.createWorkspace(name);
    if (result.isSuccess) {
      final newWorkspace = result.data;
      final newId = newWorkspace['id'].toString();
      
      await _apiService.setActiveWorkspace(newId);
      
      if (mounted) {
        // Refresh the list immediately before navigating away
        await _fetchWorkspaces();
        context.go('/dashboard'); 
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to create workspace'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
              const TracelySidebar(activeRoute: '/workspaces'),
          
          // Main Content
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text('Workspaces', style: TextStyle(fontSize: 18, color: Colors.white70)),
                backgroundColor: Colors.transparent,
                actions: [
                  ElevatedButton.icon(
                    onPressed: _createWorkspace,
                    icon: const Icon(Icons.add),
                    label: const Text('New Workspace'),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              body: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _workspaces.isEmpty
                      ? _buildEmptyState()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 24,
                              childAspectRatio: 1.5,
                            ),
                            itemCount: _workspaces.length,
                            itemBuilder: (context, index) {
                              final ws = _workspaces[index];
                              final wsId = ws['id']?.toString() ?? '';
                              final isActive = wsId == _activeWorkspaceId;
                              return Card(
                                color: TracelyTheme.surfaceColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: isActive ? const BorderSide(color: TracelyTheme.primaryColor, width: 2) : BorderSide.none,
                                ),
                                child: InkWell(
                                  onTap: () => _selectWorkspace(wsId),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Icon(Icons.workspaces_outline, color: isActive ? TracelyTheme.primaryColor : Colors.white24, size: 32),
                                            Row(
                                              children: [
                                                if (!isActive)
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                                                    onPressed: () => _deleteWorkspace(wsId),
                                                  ),
                                                if (isActive) const Icon(Icons.check_circle, color: TracelyTheme.primaryColor, size: 24),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Text(ws['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        Text('${ws['user_count'] ?? 1} members', style: const TextStyle(color: Colors.white30)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspaces_outline, size: 80, color: Colors.white.withOpacity(0.05)),
            const SizedBox(height: 32),
            Text(
              'No Workspaces Found',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create your first workspace to start collaborating and tracking API performance across your team.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.5),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _createWorkspace,
              icon: const Icon(Icons.add),
              label: const Text('Create First Workspace'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


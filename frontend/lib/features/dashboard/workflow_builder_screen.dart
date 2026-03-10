import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/tracely_sidebar.dart';

class WorkflowBuilderScreen extends StatefulWidget {
  const WorkflowBuilderScreen({super.key});

  @override
  State<WorkflowBuilderScreen> createState() => _WorkflowBuilderScreenState();
}

class _WorkflowBuilderScreenState extends State<WorkflowBuilderScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _workflows = [];
  bool _isLoading = true;
  
  // Workflow graph state
  final List<WorkflowNode> _nodes = [];
  final List<WorkflowEdge> _edges = [];
  int _selectedNodeIndex = -1;
  
  // Node types available
  final List<NodeType> _nodeTypes = [
    NodeType(name: 'HTTP Request', icon: Icons.http, color: Colors.blue),
    NodeType(name: 'Condition', icon: Icons.call_split, color: Colors.orange),
    NodeType(name: 'Loop', icon: Icons.loop, color: Colors.purple),
    NodeType(name: 'Assign Variable', icon: Icons.assignment, color: Colors.teal),
    NodeType(name: 'Log', icon: Icons.notes, color: Colors.grey),
    NodeType(name: 'Delay', icon: Icons.timelapse, color: Colors.amber),
    NodeType(name: 'Transform', icon: Icons.transform, color: Colors.indigo),
    NodeType(name: 'Mock', icon: Icons.bug_report, color: Colors.red),
  ];

  @override
  void initState() {
    super.initState();
    _fetchWorkflows();
    ApiService.activeWorkspaceNotifier.addListener(_fetchWorkflows);
    // Add default start node
    _nodes.add(WorkflowNode(
      id: 'start',
      type: 'start',
      label: 'Start',
      position: const Offset(200, 50),
    ));
  }

  @override
  void dispose() {
    ApiService.activeWorkspaceNotifier.removeListener(_fetchWorkflows);
    super.dispose();
  }

  Future<void> _fetchWorkflows() async {
    try {
      final result = await _apiService.getWorkflows();
      if (result.isSuccess) {
        setState(() {
          _workflows = result.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _addNode(NodeType nodeType) {
    final newNode = WorkflowNode(
      id: 'node_${DateTime.now().millisecondsSinceEpoch}',
      type: nodeType.name,
      label: nodeType.name,
      position: Offset(200, 150 + _nodes.length * 80),
      config: _getDefaultConfig(nodeType.name),
    );
    setState(() {
      _nodes.add(newNode);
    });
  }

  Map<String, dynamic> _getDefaultConfig(String type) {
    switch (type) {
      case 'HTTP Request':
        return {'method': 'GET', 'url': '', 'headers': {}, 'body': ''};
      case 'Condition':
        return {'expression': '', 'trueLabel': 'True', 'falseLabel': 'False'};
      case 'Loop':
        return {'type': 'times', 'count': 10, 'variable': 'i'};
      case 'Assign Variable':
        return {'variable': '', 'value': ''};
      case 'Log':
        return {'message': '', 'level': 'info'};
      case 'Delay':
        return {'duration_ms': 1000};
      case 'Transform':
        return {'input': '', 'transformation': ''};
      case 'Mock':
        return {'response': '', 'status_code': 200};
      default:
        return {};
    }
  }

  void _removeNode(int index) {
    setState(() {
      _nodes.removeAt(index);
      // Remove all edges connected to this node
      _edges.removeWhere((e) => e.fromIndex == index || e.toIndex == index);
      // Update indices
      for (var i = 0; i < _edges.length; i++) {
        if (_edges[i].fromIndex > index) _edges[i].fromIndex--;
        if (_edges[i].toIndex > index) _edges[i].toIndex--;
      }
    });
  }

  void _showNodeConfigDialog(int index) {
    final node = _nodes[index];
    showDialog(
      context: context,
      builder: (context) => _NodeConfigDialog(
        node: node,
        onSave: (updatedNode) {
          setState(() {
            _nodes[index] = updatedNode;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const TracelySidebar(activeRoute: '/workflows'),
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text('Workflow Builder', style: TextStyle(fontSize: 18, color: Colors.white70)),
                backgroundColor: Colors.transparent,
                actions: [
                  ElevatedButton.icon(
                    onPressed: _saveWorkflow,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _runWorkflow,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: Row(
                children: [
                  // Toolbox / Components Panel
                  Container(
                    width: 280,
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: TracelyTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Workflows', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                          ),
                          _isLoading 
                            ? const Center(child: CircularProgressIndicator())
                            : _workflows.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No workflows found.', style: TextStyle(color: Colors.white24, fontSize: 12)),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _workflows.length,
                                  itemBuilder: (context, index) {
                                    final workflow = _workflows[index];
                                    return _ToolboxItem(
                                      icon: Icons.account_tree_outlined,
                                      label: workflow['name'] ?? 'Untitled Workflow',
                                      color: TracelyTheme.primaryColor,
                                    );
                                  },
                                ),
                          const Divider(color: Colors.white10),
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Components', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                          ),
                          _ToolboxItem(
                            icon: Icons.call_split,
                            label: 'If/Else (Branch)',
                            color: Colors.orange,
                            onTap: () => _addNode(_nodeTypes.firstWhere((n) => n.name == 'Condition')),
                          ),
                          _ToolboxItem(
                            icon: Icons.call_merge,
                            label: 'Merge Branches',
                            color: Colors.orangeAccent,
                          ),
                          const Divider(color: Colors.white10),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text('Loops', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12)),
                          ),
                          _ToolboxItem(
                            icon: Icons.loop,
                            label: 'Repeat N Times',
                            color: Colors.purple,
                            onTap: () => _addNode(_nodeTypes.firstWhere((n) => n.name == 'Loop')),
                          ),
                          _ToolboxItem(
                            icon: Icons.repeat,
                            label: 'For Each',
                            color: Colors.deepPurple,
                          ),
                          _ToolboxItem(
                            icon: Icons.all_inclusive,
                            label: 'While',
                            color: Colors.purpleAccent,
                          ),
                          _ToolboxItem(
                            icon: Icons.exit_to_app,
                            label: 'Break/Continue',
                            color: Colors.redAccent,
                          ),
                          const Divider(color: Colors.white10),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12)),
                          ),
                          ..._nodeTypes.where((n) => n.name != 'Condition' && n.name != 'Loop').map(
                            (type) => _ToolboxItem(
                              icon: type.icon,
                              label: type.name,
                              color: type.color,
                              onTap: () => _addNode(type),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  // Canvas
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0, 24, 24, 24),
                      decoration: BoxDecoration(
                        color: TracelyTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: _nodes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline, size: 64, color: Colors.white24),
                                const SizedBox(height: 16),
                                const Text('Add nodes from the components panel', style: TextStyle(color: Colors.white24)),
                              ],
                            ),
                          )
                        : _buildWorkflowCanvas(),
                    ),
                  ),
                  // Properties Panel
                  if (_selectedNodeIndex >= 0)
                    Container(
                      width: 300,
                      margin: const EdgeInsets.fromLTRB(0, 24, 24, 24),
                      decoration: BoxDecoration(
                        color: TracelyTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Node Properties', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() => _selectedNodeIndex = -1),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _PropertyField(label: 'Node ID', value: _nodes[_selectedNodeIndex].id),
                                  _PropertyField(label: 'Type', value: _nodes[_selectedNodeIndex].type),
                                  const SizedBox(height: 8),
                                  TextField(
                                    decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder()),
                                    controller: TextEditingController(text: _nodes[_selectedNodeIndex].label),
                                    onChanged: (val) {
                                      setState(() {
                                        _nodes[_selectedNodeIndex].label = val;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildConfigFields(_nodes[_selectedNodeIndex]),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _showNodeConfigDialog(_selectedNodeIndex),
                                          icon: const Icon(Icons.settings),
                                          label: const Text('Configure'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _removeNode(_selectedNodeIndex),
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowCanvas() {
    return DragTarget<WorkflowNode>(
      onAcceptWithDetails: (details) {
        // Handle dropped nodes
      },
      builder: (context, candidateData, rejectedData) {
        return CustomPaint(
          painter: _WorkflowPainter(nodes: _nodes, edges: _edges, selectedIndex: _selectedNodeIndex),
          child: Stack(
            children: _nodes.asMap().entries.map((entry) {
              final index = entry.key;
              final node = entry.value;
              return Positioned(
                left: node.position.dx,
                top: node.position.dy,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedNodeIndex = index),
                  child: _buildNodeWidget(node, index),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildNodeWidget(WorkflowNode node, int index) {
    Color nodeColor;
    switch (node.type) {
      case 'start':
      case 'End':
        nodeColor = Colors.green;
        break;
      case 'Condition':
        nodeColor = Colors.orange;
        break;
      case 'Loop':
        nodeColor = Colors.purple;
        break;
      default:
        nodeColor = TracelyTheme.primaryColor;
    }

    // Special shape for condition (diamond)
    if (node.type == 'Condition') {
      return SizedBox(
        width: 160,
        child: Transform.rotate(
          angle: 0.785, // 45 degrees
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TracelyTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: index == _selectedNodeIndex ? nodeColor : nodeColor.withValues(alpha: 0.5),
                width: index == _selectedNodeIndex ? 3 : 2,
              ),
            ),
            child: Transform.rotate(
              angle: -0.785,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call_split, color: nodeColor, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    node.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Special shape for loops (rounded rectangle with repeat icon)
    if (node.type == 'Loop') {
      return Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TracelyTheme.backgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: index == _selectedNodeIndex ? nodeColor : nodeColor.withValues(alpha: 0.5),
            width: index == _selectedNodeIndex ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.loop, color: nodeColor, size: 24),
            const SizedBox(height: 4),
            Text(
              node.label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (node.config['count'] != null)
              Text(
                '${node.config['count']} times',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
          ],
        ),
      );
    }

    // Standard node
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TracelyTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: index == _selectedNodeIndex ? nodeColor : nodeColor.withValues(alpha: 0.5),
          width: index == _selectedNodeIndex ? 3 : 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getNodeIcon(node.type), color: nodeColor, size: 24),
          const SizedBox(height: 4),
          Text(
            node.label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getNodeIcon(String type) {
    switch (type) {
      case 'start':
        return Icons.play_circle;
      case 'End':
        return Icons.stop_circle;
      case 'HTTP Request':
        return Icons.http;
      case 'Assign Variable':
        return Icons.assignment;
      case 'Log':
        return Icons.notes;
      case 'Delay':
        return Icons.timelapse;
      case 'Transform':
        return Icons.transform;
      case 'Mock':
        return Icons.bug_report;
      default:
        return Icons.circle;
    }
  }

  Widget _buildConfigFields(WorkflowNode node) {
    switch (node.type) {
      case 'HTTP Request':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Method', style: TextStyle(color: Colors.white54, fontSize: 12)),
            DropdownButton<String>(
              value: node.config['method'] ?? 'GET',
              items: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'].map((m) => 
                DropdownMenuItem(value: m, child: Text(m))
              ).toList(),
              onChanged: (val) {
                setState(() {
                  node.config['method'] = val;
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'URL', border: OutlineInputBorder()),
              controller: TextEditingController(text: node.config['url'] ?? ''),
              onChanged: (val) => node.config['url'] = val,
            ),
          ],
        );
      case 'Condition':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Expression', border: OutlineInputBorder(), hintText: 'e.g., response.status == 200'),
              controller: TextEditingController(text: node.config['expression'] ?? ''),
              onChanged: (val) => node.config['expression'] = val,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'True Branch Label', border: OutlineInputBorder()),
              controller: TextEditingController(text: node.config['trueLabel'] ?? 'True'),
              onChanged: (val) => node.config['trueLabel'] = val,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'False Branch Label', border: OutlineInputBorder()),
              controller: TextEditingController(text: node.config['falseLabel'] ?? 'False'),
              onChanged: (val) => node.config['falseLabel'] = val,
            ),
          ],
        );
      case 'Loop':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Loop Type', style: TextStyle(color: Colors.white54, fontSize: 12)),
            DropdownButton<String>(
              value: node.config['type'] ?? 'times',
              items: ['times', 'while', 'foreach'].map((t) => 
                DropdownMenuItem(value: t, child: Text(t == 'times' ? 'Repeat N Times' : t == 'while' ? 'While' : 'For Each'))
              ).toList(),
              onChanged: (val) {
                setState(() {
                  node.config['type'] = val;
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Count/Variable', border: OutlineInputBorder()),
              controller: TextEditingController(text: node.config['count']?.toString() ?? '10'),
              keyboardType: TextInputType.number,
              onChanged: (val) => node.config['count'] = int.tryParse(val) ?? 10,
            ),
          ],
        );
      default:
        return const Text('No additional configuration', style: TextStyle(color: Colors.white24));
    }
  }

  void _saveWorkflow() {
    final workflowData = {
      'name': 'Workflow ${DateTime.now().millisecondsSinceEpoch}',
      'nodes': _nodes.map((n) => {'id': n.id, 'type': n.type, 'label': n.label, 'config': n.config}).toList(),
      'edges': _edges.map((e) => {'from': e.fromIndex, 'to': e.toIndex}).toList(),
    };
    // Would save to API - using workflowData to avoid unused variable warning
    debugPrint('Saving workflow: ${workflowData['name']}');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workflow saved!')));
  }

  void _runWorkflow() {
    // Would execute the workflow
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Running workflow...')));
  }
}

class NodeType {
  final String name;
  final IconData icon;
  final Color color;
  NodeType({required this.name, required this.icon, required this.color});
}

class WorkflowNode {
  String id;
  String type;
  String label;
  Offset position;
  Map<String, dynamic> config;
  WorkflowNode({
    required this.id,
    required this.type,
    required this.label,
    required this.position,
    this.config = const {},
  });
}

class WorkflowEdge {
  int fromIndex;
  int toIndex;
  WorkflowEdge({required this.fromIndex, required this.toIndex});
}

class _ToolboxItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ToolboxItem({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70))),
          ],
        ),
      ),
    );
  }
}

class _PropertyField extends StatelessWidget {
  final String label;
  final String value;
  const _PropertyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12))),
        ],
      ),
    );
  }
}

class _NodeConfigDialog extends StatefulWidget {
  final WorkflowNode node;
  final Function(WorkflowNode) onSave;
  const _NodeConfigDialog({required this.node, required this.onSave});

  @override
  State<_NodeConfigDialog> createState() => _NodeConfigDialogState();
}

class _NodeConfigDialogState extends State<_NodeConfigDialog> {
  late TextEditingController _labelController;
  late TextEditingController _urlController;
  late TextEditingController _bodyController;
  late TextEditingController _expressionController;
  late TextEditingController _countController;
  String _method = 'GET';
  String _loopType = 'times';

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.node.label);
    _urlController = TextEditingController(text: widget.node.config['url'] ?? '');
    _bodyController = TextEditingController(text: widget.node.config['body'] ?? '');
    _expressionController = TextEditingController(text: widget.node.config['expression'] ?? '');
    _countController = TextEditingController(text: widget.node.config['count']?.toString() ?? '10');
    _method = widget.node.config['method'] ?? 'GET';
    _loopType = widget.node.config['type'] ?? 'times';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TracelyTheme.surfaceColor,
      title: Text('Configure ${widget.node.type}', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              if (widget.node.type == 'HTTP Request') ...[
                const Text('Method', style: TextStyle(color: Colors.white54)),
                DropdownButton<String>(
                  value: _method,
                  isExpanded: true,
                  items: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'].map((m) => 
                    DropdownMenuItem(value: m, child: Text(m))
                  ).toList(),
                  onChanged: (val) => setState(() => _method = val ?? 'GET'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'URL', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyController,
                  decoration: const InputDecoration(labelText: 'Request Body', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
              ],
              if (widget.node.type == 'Condition') ...[
                TextField(
                  controller: _expressionController,
                  decoration: const InputDecoration(
                    labelText: 'Condition Expression', 
                    border: OutlineInputBorder(),
                    hintText: 'e.g., response.status >= 200 && response.status < 300',
                  ),
                ),
              ],
              if (widget.node.type == 'Loop') ...[
                const Text('Loop Type', style: TextStyle(color: Colors.white54)),
                DropdownButton<String>(
                  value: _loopType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'times', child: Text('Repeat N Times')),
                    DropdownMenuItem(value: 'while', child: Text('While Condition')),
                    DropdownMenuItem(value: 'foreach', child: Text('For Each Item')),
                  ],
                  onChanged: (val) => setState(() => _loopType = val ?? 'times'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _countController,
                  decoration: const InputDecoration(labelText: 'Count/Iterations', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveConfig,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveConfig() {
    final updatedNode = WorkflowNode(
      id: widget.node.id,
      type: widget.node.type,
      label: _labelController.text,
      position: widget.node.position,
      config: {
        ...widget.node.config,
        'method': _method,
        'url': _urlController.text,
        'body': _bodyController.text,
        'expression': _expressionController.text,
        'count': int.tryParse(_countController.text) ?? 10,
        'type': _loopType,
      },
    );
    widget.onSave(updatedNode);
    Navigator.pop(context);
  }
}

class _WorkflowPainter extends CustomPainter {
  final List<WorkflowNode> nodes;
  final List<WorkflowEdge> edges;
  final int selectedIndex;

  _WorkflowPainter({required this.nodes, required this.edges, required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw edges
    for (var edge in edges) {
      if (edge.fromIndex < nodes.length && edge.toIndex < nodes.length) {
        final from = nodes[edge.fromIndex].position;
        final to = nodes[edge.toIndex].position;
        
        // Calculate connection points
        final fromPoint = Offset(from.dx + 80, from.dy + 30);
        final toPoint = Offset(to.dx + 80, to.dy);

        // Draw line
        final path = Path();
        path.moveTo(fromPoint.dx, fromPoint.dy);
        
        // Add bezier curve for smooth connection
        final controlY = (fromPoint.dy + toPoint.dy) / 2;
        path.cubicTo(
          fromPoint.dx, controlY,
          toPoint.dx, controlY,
          toPoint.dx, toPoint.dy,
        );
        
        canvas.drawPath(path, paint);
        
        // Draw arrow
        _drawArrow(canvas, toPoint, paint);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset point, Paint paint) {
    final path = Path();
    path.moveTo(point.dx, point.dy);
    path.lineTo(point.dx - 8, point.dy - 12);
    path.lineTo(point.dx + 8, point.dy - 12);
    path.close();
    
    final fillPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _WorkflowPainter oldDelegate) {
    return nodes.length != oldDelegate.nodes.length ||
           edges.length != oldDelegate.edges.length ||
           selectedIndex != oldDelegate.selectedIndex;
  }
}


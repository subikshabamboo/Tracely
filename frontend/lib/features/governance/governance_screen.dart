import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';

class GovernanceScreen extends StatefulWidget {
  const GovernanceScreen({super.key});

  @override
  State<GovernanceScreen> createState() => _GovernanceScreenState();
}

class _GovernanceScreenState extends State<GovernanceScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _audits = [];
  List<dynamic> _rules = [];
  Map<String, dynamic> _config = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }
  Future<void> _fetchData() async {
    final workspaceId = await _apiService.getActiveWorkspaceId();
    if (workspaceId == null) return;

    final auditRes = await _apiService.getGovernanceAudits(workspaceId);
    final rulesRes = await _apiService.getRedactionRules(workspaceId);
    final configRes = await _apiService.safeGet('/traces/config?workspace_id=$workspaceId');

    if (mounted) {
      setState(() {
        if (auditRes.isSuccess) _audits = auditRes.data;
        if (rulesRes.isSuccess) _rules = rulesRes.data;
        if (configRes.isSuccess) _config = configRes.data;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRule(String ruleId) async {
    await _apiService.safePost('/governance/redaction-rules', {'action': 'delete', 'id': ruleId});
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: TracelyTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Governance & Privacy', style: TextStyle(color: Colors.white70)),
          backgroundColor: Colors.transparent,
          bottom: const TabBar(
            indicatorColor: TracelyTheme.primaryColor,
            tabs: [
              Tab(text: 'Masking Audits'),
              Tab(text: 'Redaction Rules'),
              Tab(text: 'Sampling Rules'),
              Tab(text: 'Access Control'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AuditTab(audits: _audits, isLoading: _isLoading),
            _RedactionTab(rules: _rules, apiService: _apiService, onRefresh: _fetchData, onDeleteRule: _deleteRule),
            _SamplingTab(config: _config, apiService: _apiService, onSave: (newConfig) async {
               await _apiService.safePost('/traces/config', newConfig);
               _fetchData();
            }),
            const _AccessTab(),
          ],
        ),
      ),
    );
  }
}

class _AuditTab extends StatelessWidget {
  final List<dynamic> audits;
  final bool isLoading;
  const _AuditTab({required this.audits, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (audits.isEmpty) return const Center(child: Text('No masking audits found', style: TextStyle(color: Colors.white24)));

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: audits.length,
      itemBuilder: (context, index) {
        final audit = audits[index];
        return Card(
          color: TracelyTheme.surfaceColor,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.security, color: Colors.orange),
            title: Text('PII Masked: ${audit['field']}', style: const TextStyle(color: Colors.white)),
            subtitle: Text('Rule: ${audit['rule']} | Trace: ${audit['trace_id']}', style: const TextStyle(color: Colors.white30)),
            trailing: Text(audit['timestamp']?.split('T')[0] ?? '', style: const TextStyle(color: Colors.white24)),
          ),
        );
      },
    );
  }
}

class _RedactionTab extends StatelessWidget {
  final List<dynamic> rules;
  final ApiService apiService;
  final VoidCallback onRefresh;
  final Function(String) onDeleteRule;
  const _RedactionTab({required this.rules, required this.apiService, required this.onRefresh, required this.onDeleteRule});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manual Redaction Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showAddRule(context),
                icon: const Icon(Icons.add),
                label: const Text('New Rule'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return ListTile(
                  title: Text(rule['name']),
                  subtitle: Text(rule['pattern'], style: const TextStyle(fontFamily: 'monospace', color: Colors.white38)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                    onPressed: () async {
                      final ruleId = rule['id'] ?? '';
                      await onDeleteRule(ruleId);
                      onRefresh();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRule(BuildContext context) {
    final nameController = TextEditingController();
    final patternController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Redaction Rule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Rule Name')),
            TextField(controller: patternController, decoration: const InputDecoration(labelText: 'Regex Pattern (e.g. [0-9]{16})')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final workspaceId = await apiService.getActiveWorkspaceId();
              await apiService.createRedactionRule({
                'name': nameController.text,
                'pattern': patternController.text,
                'workspace_id': workspaceId,
              });
              if (context.mounted) Navigator.pop(context);
              onRefresh();
            },
            child: const Text('Save Rule'),
          ),
        ],
      ),
    );
  }
}

class _AccessTab extends StatelessWidget {
  const _AccessTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        _UserAccessRow(email: 'admin@tracely.io', role: 'ADMIN', lastActive: '1h ago'),
        Divider(color: Colors.white10),
        _UserAccessRow(email: 'dev@tracely.io', role: 'DEVELOPER', lastActive: '5m ago'),
      ],
    );
  }
}

class _UserAccessRow extends StatelessWidget {
  final String email;
  final String role;
  final String lastActive;

  const _UserAccessRow({required this.email, required this.role, required this.lastActive});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(email, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text('Last active: $lastActive', style: const TextStyle(color: Colors.white30, fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: role == 'ADMIN' ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(role, style: TextStyle(color: role == 'ADMIN' ? Colors.red : Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SamplingTab extends StatefulWidget {
  final Map<String, dynamic> config;
  final ApiService apiService;
  final Function(Map<String, dynamic>) onSave;
  const _SamplingTab({required this.config, required this.apiService, required this.onSave});

  @override
  State<_SamplingTab> createState() => _SamplingTabState();
}

class _SamplingTabState extends State<_SamplingTab> {
  late Map<String, double> _rules;
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.config['is_enabled'] ?? true;
    final rulesRaw = widget.config['sampling_rules'] as Map<String, dynamic>? ?? {'*': 1.0};
    _rules = rulesRaw.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SwitchListTile(
          title: const Text('Tracing Enabled', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: const Text('Global kill-switch for all trace capture', style: TextStyle(color: Colors.white38, fontSize: 12)),
          value: _isEnabled,
          activeColor: TracelyTheme.primaryColor,
          onChanged: (v) => setState(() => _isEnabled = v),
        ),
        const SizedBox(height: 24),
        const Text('Service Sampling Rules', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const Text('Define the % of traces to capture per service endpoint', style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 16),
        ..._rules.entries.map((entry) => _buildRuleRow(entry.key, entry.value)),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => _showAddRuleDialog(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Service Override'),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          onPressed: () async {
            final workspaceId = await widget.apiService.getActiveWorkspaceId();
            widget.onSave({
              ...widget.config,
              'is_enabled': _isEnabled,
              'sampling_rules': _rules,
              'workspace_id': workspaceId,
            });
          },
          child: const Text('Save Tracing Configuration'),
        ),
      ],
    );
  }

  Widget _buildRuleRow(String pattern, double rate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(pattern, style: const TextStyle(fontFamily: 'monospace', color: TracelyTheme.primaryColor))),
          Expanded(
            flex: 3,
            child: Slider(
              value: rate,
              onChanged: (v) => setState(() => _rules[pattern] = v),
              activeColor: TracelyTheme.primaryColor,
            ),
          ),
          Text('${(rate * 100).toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (pattern != '*')
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.white24),
              onPressed: () => setState(() => _rules.remove(pattern)),
            ),
        ],
      ),
    );
  }

  void _showAddRuleDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Sampling Override'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'service-name or endpoint pattern'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() => _rules[controller.text] = 1.0);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

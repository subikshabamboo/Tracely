import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class CascadeSimulationScreen extends StatefulWidget {
  final String workspaceId;

  const CascadeSimulationScreen({super.key, required this.workspaceId});

  @override
  State<CascadeSimulationScreen> createState() => _CascadeSimulationScreenState();
}

class _CascadeSimulationScreenState extends State<CascadeSimulationScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _simulations = [];

  @override
  void initState() {
    super.initState();
    _fetchSimulations();
  }

  Future<void> _fetchSimulations() async {
    final result = await _apiService.getCascadeSimulations(widget.workspaceId);
    if (mounted) {
      setState(() {
        _simulations = result.data ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _startSimulation() async {
    // Show dialog to configure simulation
    final config = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SimulationConfigDialog(),
    );

    if (config != null) {
      setState(() => _isLoading = true);
      await _apiService.startCascadeSimulation(widget.workspaceId, config);
      _fetchSimulations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cascade Simulations'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.orange),
            onPressed: _startSimulation,
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
            : _simulations.isEmpty
                ? const Center(
                    child: Text('No simulations recorded',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _simulations.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final sim = _simulations[index];
                      return _buildSimulationCard(sim);
                    },
                  ),
      ),
    );
  }

  Widget _buildSimulationCard(dynamic sim) {
    return Card(
      color: Colors.black45,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.withOpacity(0.2)),
      ),
      child: ListTile(
        title: Text(sim['name'] ?? 'Simulation',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('Trigger: ${sim['trigger_service']} (${sim['failure_type']})',
            style: const TextStyle(color: Colors.grey)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: sim['status'] == 'completed' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            sim['status']?.toString().toUpperCase() ?? 'PENDING',
            style: TextStyle(
              color: sim['status'] == 'completed' ? Colors.green : Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _showResults(sim['id']),
      ),
    );
  }

  Future<void> _showResults(String simId) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CascadeResultsSheet(simulationId: simId),
    );
  }
}

class _CascadeResultsSheet extends StatefulWidget {
  final String simulationId;
  const _CascadeResultsSheet({required this.simulationId});

  @override
  State<_CascadeResultsSheet> createState() => _CascadeResultsSheetState();
}

class _CascadeResultsSheetState extends State<_CascadeResultsSheet> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _results = [];

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    final result = await _apiService.getCascadeResults(widget.simulationId);
    if (mounted) {
      setState(() {
        _results = result.data ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Simulation Results',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.grey),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _results.isEmpty
                    ? const Center(child: Text('No results yet', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final res = _results[index];
                          return ListTile(
                            leading: Icon(
                              res['impact_level'] == 'error' ? Icons.error : Icons.warning,
                              color: res['impact_level'] == 'error' ? Colors.red : Colors.orange,
                            ),
                            title: Text(res['service_name'] ?? '', style: const TextStyle(color: Colors.white)),
                            subtitle: Text(res['details'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SimulationConfigDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final serviceController = TextEditingController();
    final typeController = TextEditingController(text: 'error');

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('New Cascade Simulation', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Simulation Name', labelStyle: TextStyle(color: Colors.grey)),
          ),
          TextField(
            controller: serviceController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Trigger Service', labelStyle: TextStyle(color: Colors.grey)),
          ),
          DropdownButtonFormField<String>(
            value: 'error',
            dropdownColor: Colors.black,
            style: const TextStyle(color: Colors.white),
            items: ['error', 'timeout', 'latency'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) => typeController.text = val ?? 'error',
            decoration: const InputDecoration(labelText: 'Failure Type', labelStyle: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'name': nameController.text,
            'trigger_service': serviceController.text,
            'failure_type': typeController.text,
            'affected_services': ['auth-service', 'payment-gateway', 'order-processor'], // Mock for demonstration
          }),
          child: const Text('Start'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class MutationHistoryScreen extends StatefulWidget {
  final String executionId;

  const MutationHistoryScreen({super.key, required this.executionId});

  @override
  State<MutationHistoryScreen> createState() => _MutationHistoryScreenState();
}

class _MutationHistoryScreenState extends State<MutationHistoryScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _mutations = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final result = await _apiService.getMutationHistory(widget.executionId);
    if (mounted) {
      setState(() {
        _mutations = result.data ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mutation History'),
        backgroundColor: Colors.black,
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
            : _mutations.isEmpty
                ? const Center(
                    child: Text('No mutations recorded',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _mutations.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final mutation = _mutations[index];
                      return _buildMutationCard(mutation);
                    },
                  ),
      ),
    );
  }

  Widget _buildMutationCard(dynamic mutation) {
    return Card(
      color: Colors.black45,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Span: ${mutation['span_id']}',
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                ),
                Text(
                  mutation['timestamp']?.toString().split('T').last.split('.').first ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Variable: {{${mutation['key']}}}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Original',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text(mutation['original_value'] ?? '',
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mutated',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text(mutation['mutated_value'] ?? '',
                          style: const TextStyle(
                              color: Colors.greenAccent, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/tracely_sidebar.dart';

class EnvironmentsScreen extends StatefulWidget {
  const EnvironmentsScreen({super.key});

  @override
  State<EnvironmentsScreen> createState() => _EnvironmentsScreenState();
}

class _EnvironmentsScreenState extends State<EnvironmentsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _environments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEnvironments();
  }

  Future<void> _fetchEnvironments() async {
    try {
      final result = await _apiService.getEnvironments(null);
      if (mounted) {
        if (result.isSuccess) {
          setState(() {
            _environments = result.data;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const TracelySidebar(activeRoute: '/environments'),
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text('Environment Variables', style: TextStyle(fontSize: 18, color: Colors.white70)),
                backgroundColor: Colors.transparent,
              ),
              body: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Saved Environments', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add),
                              label: const Text('New Environment'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.5,
                            ),
                            itemCount: _environments.length,
                            itemBuilder: (context, index) {
                              final env = _environments[index];
                              final vars = env['variables'] as Map<String, dynamic>? ?? {};
                              
                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: TracelyTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(env['name'] ?? 'Environment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        const Icon(Icons.settings_outlined, size: 16, color: Colors.white38),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: ListView(
                                        children: vars.entries.map((e) => Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              Text('${e.key}: ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                              Text(e.value.toString(), style: const TextStyle(color: TracelyTheme.primaryColor, fontSize: 12)),
                                            ],
                                          ),
                                        )).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

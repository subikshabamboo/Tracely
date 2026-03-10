import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/tracely_sidebar.dart';
import 'dart:convert';
import 'dart:math' as Math;


class TopologyScreen extends StatefulWidget {
  const TopologyScreen({super.key});

  @override
  State<TopologyScreen> createState() => _TopologyScreenState();
}

class _TopologyScreenState extends State<TopologyScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _selectedService;
  double _latency = 0;
  double _jitter = 0;
  double _failureRate = 0;
  bool _isInjecting = false;
  List<dynamic> _dependencies = [];

  @override
  void initState() {
    super.initState();
    ApiService.activeWorkspaceNotifier.addListener(_fetchTopology);
    _fetchTopology();
  }

  @override
  void dispose() {
    ApiService.activeWorkspaceNotifier.removeListener(_fetchTopology);
    super.dispose();
  }

  Future<void> _fetchTopology() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final workspaceId = ApiService.activeWorkspaceNotifier.value;
      final result = await _apiService.getTopology(workspaceId);
      if (mounted) {
        if (result.isSuccess) {
          setState(() {
            _dependencies = result.data ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _dependencies = [];
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
    // Unique services extraction
    Set<String> services = {};
    for (var dep in _dependencies) {
      services.add(dep['parent']);
      services.add(dep['child']);
    }

    return Scaffold(
      body: Row(
        children: [
          const TracelySidebar(activeRoute: '/topology'),
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text('Service Topology Map', style: TextStyle(fontSize: 18, color: Colors.white70)),
                backgroundColor: Colors.transparent,
              ),
              body: Container(
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: TracelyTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : services.isEmpty
                        ? _buildEmptyState()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final size = Size(constraints.maxWidth, constraints.maxHeight);
                              return Stack(
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (details) => _handleTap(details, services.toList(), size),
                                    child: CustomPaint(
                                      size: size,
                                      painter: TopologyPainter(services.toList(), _dependencies, _selectedService),
                                    ),
                                  ),
                                  Positioned(
                                    right: 24,
                                    top: 24,
                                    child: _buildInfoPanel(services.length),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
            ),
          ),
          if (_selectedService != null)
            _buildFaultInjectionPanel(),
        ],
      ),
    );
  }
  void _handleTap(TapUpDetails details, List<String> services, Size totalSize) {
    if (services.isEmpty) return;

    // Must match TopologyPainter layout exactly
    final Offset center = Offset(totalSize.width / 2, totalSize.height / 2);
    final double radius = totalSize.width < totalSize.height ? totalSize.width * 0.35 : totalSize.height * 0.35;

    for (int i = 0; i < services.length; i++) {
      double angle = (2 * 3.14159 * i) / services.length;
      double x = center.dx + radius * 1.2 * Math.cos(angle);
      double y = center.dy + radius * 1.2 * Math.sin(angle);
      final nodeOffset = Offset(x, y);

      final distance = (details.localPosition - nodeOffset).distance;
      if (distance < 30) { 
        setState(() {
          _selectedService = services[i];
        });
        return;
      }
    }
  }


  Widget _buildFaultInjectionPanel() {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 24, top: 24, bottom: 24),
      padding: const EdgeInsets.all(24),
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
              Text('Fault Injection', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(onPressed: () => setState(() => _selectedService = null), icon: const Icon(Icons.close, size: 18)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Service: $_selectedService', style: const TextStyle(color: TracelyTheme.primaryColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          _FaultSlider(
            label: 'Latency (ms)', 
            value: _latency, 
            max: 2000, 
            onChanged: (v) => setState(() => _latency = v),
          ),
          _FaultSlider(
            label: 'Jitter (ms)', 
            value: _jitter, 
            max: 500, 
            onChanged: (v) => setState(() => _jitter = v),
          ),
          _FaultSlider(
            label: 'Failure Rate (%)', 
            value: _failureRate, 
            max: 100, 
            onChanged: (v) => setState(() => _failureRate = v),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isInjecting ? null : _handleInjectFault,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: _isInjecting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Inject Fault'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleInjectFault() async {
    if (_selectedService == null) return;
    
    setState(() => _isInjecting = true);
    try {
      // Assuming backend expects a generic 'fault_injection' endpoint for ToxiProxy
      // or we use the specific replay/service to trigger it.
      // For now, using a direct ToxiProxy control endpoint if it exists.
      final result = await _apiService.safePost('/replays/toxiproxy/inject', {
        'service_name': _selectedService,
        'latency_ms': _latency.toInt(),
        'jitter_ms': _jitter.toInt(),
        'failure_rate': _failureRate / 100.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.isSuccess ? 'Fault injected successfully' : 'Failed to inject fault'),
            backgroundColor: result.isSuccess ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInjecting = false);
    }
  }

  Widget _buildInfoPanel(int serviceCount) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TracelyTheme.backgroundColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Topology Info', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _InfoRow(label: 'Total Services', value: serviceCount.toString()),
          _InfoRow(label: 'Active Flows', value: _dependencies.length.toString()),
          const _InfoRow(label: 'Avg Heat', value: 'Healthy', color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hub_outlined, size: 64, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          const Text('No Service Topology Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Run some requests in the Request Studio to see your service map.', style: TextStyle(color: Colors.white30)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/request-studio'),
            icon: const Icon(Icons.send),
            label: const Text('Go to Request Studio'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _fetchTopology,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _FaultSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  const _FaultSlider({required this.label, required this.value, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text(value.round().toString(), style: const TextStyle(color: TracelyTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        Slider(
          value: value,
          max: max,
          divisions: max > 0 ? max.toInt() : 1,
          activeColor: TracelyTheme.primaryColor,
          inactiveColor: Colors.white10,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _InfoRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}


class TopologyPainter extends CustomPainter {
  final List<String> services;
  final List<dynamic> dependencies;
  final String? selectedService;

  TopologyPainter(this.services, this.dependencies, this.selectedService);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TracelyTheme.primaryColor
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Calculate positions (Robust Circular Layout)
    Map<String, Offset> positions = {};
    double radius = size.width < size.height ? size.width * 0.35 : size.height * 0.35;
    Offset center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < services.length; i++) {
      double angle = (2 * 3.14159 * i) / services.length;
      
      // Real robust circle
      double x = center.dx + radius * 1.2 * Math.cos(angle);
      double y = center.dy + radius * 1.2 * Math.sin(angle);
      positions[services[i]] = Offset(x, y);
    }


    // Draw lines
    for (var dep in dependencies) {
      Offset? p1 = positions[dep['parent']];
      Offset? p2 = positions[dep['child']];
      if (p1 != null && p2 != null) {
        bool isAffected = (dep['parent'] == selectedService || dep['child'] == selectedService);
        canvas.drawLine(p1, p2, linePaint..color = isAffected ? Colors.redAccent.withOpacity(0.4) : Colors.white24);
      }
    }

    // Draw nodes
    for (var entry in positions.entries) {
      bool isSelected = entry.key == selectedService;
      
      if (isSelected) {
        canvas.drawCircle(entry.value, 25, paint..color = Colors.redAccent.withOpacity(0.2));
      }
      
      canvas.drawCircle(entry.value, 15, paint..color = isSelected ? Colors.redAccent : TracelyTheme.primaryColor);
      canvas.drawCircle(entry.value, 20, paint..color = (isSelected ? Colors.redAccent : TracelyTheme.primaryColor).withOpacity(0.2));
      
      textPainter.text = TextSpan(
        text: entry.key,
        style: TextStyle(
          color: isSelected ? Colors.redAccent : Colors.white70, 
          fontSize: 10, 
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, entry.value + const Offset(-20, 25));
    }
  }

  @override
  bool shouldRepaint(covariant TopologyPainter oldDelegate) {
     return selectedService != oldDelegate.selectedService || 
            services.length != oldDelegate.services.length;
  }
}



import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';

class CollectionDetailScreen extends StatefulWidget {
  final String collectionId;
  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _collection;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCollection();
  }

  Future<void> _fetchCollection() async {
    final result = await _apiService.getCollection(widget.collectionId);
    if (result.isSuccess) {
      setState(() {
        _collection = result.data;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final items = _collection?['items'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('${_collection?['name']} (v${_collection?['version']})'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            color: TracelyTheme.surfaceColor,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${item['method']} ${item['url']}', style: const TextStyle(color: Colors.white24, fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white10),
            ),
          );
        },
      ),
    );
  }
}

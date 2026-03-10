import 'dart:convert';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../core/app_state.dart';

class TestDataGeneratorScreen extends StatefulWidget {
  const TestDataGeneratorScreen({super.key});

  @override
  State<TestDataGeneratorScreen> createState() => _TestDataGeneratorScreenState();
}

class _TestDataGeneratorScreenState extends State<TestDataGeneratorScreen> {
  final TextEditingController _templateController = TextEditingController();
  String _generatedData = '';
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _templateController.text = _appState.lastDataSchema;
    _generatedData = _appState.lastGeneratedData;
    _templateController.addListener(() {
      _appState.lastDataSchema = _templateController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Data Generator')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Generate synthetic data based on a JSON template.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('JSON Template', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextField(
                            controller: _templateController,
                            maxLines: null,
                            expands: true,
                            decoration: InputDecoration(
                              hintText: '{\n  "id": "{{uuid}}",\n  "name": "{{name}}",\n  "email": "{{email}}"\n}',
                              fillColor: TracelyTheme.surfaceColor,
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Generated Output', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: SingleChildScrollView(
                              child: Text(_generatedData, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final template = _templateController.text.isEmpty 
                      ? '{\n  "id": "{{uuid}}",\n  "name": "{{name}}",\n  "email": "{{email}}"\n}' 
                      : _templateController.text;
                    
                    final api = ApiService();
                    final result = await api.generateTestData({'template': template, 'count': 10});
                    
                    if (result.isSuccess) {
                       setState(() {
                        _generatedData = _generateRecords(template, 10);
                        _appState.lastGeneratedData = _generatedData;
                      });
                    }
                  },
                  child: const Text('Generate 10 Records (Cloud)'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    if (_generatedData.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy to Clipboard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _generateRecords(String template, int count) {
    final List<String> records = [];
    final math = Math.Random();

    try {
      final decoded = jsonDecode(template);
      if (decoded is Map && decoded.containsKey('type') && decoded['type'] == 'object') {
        // It's a schema!
        final Map<String, dynamic> schema = Map<String, dynamic>.from(decoded);
        for (int i = 0; i < count; i++) {
          final data = _generateFromSchema(schema, math);
          records.add(jsonEncode(data));
        }
        return '[\n  ${records.map((r) => _prettyPrint(r)).join(',\n  ')}\n]';
      }
    } catch (_) {}

    // Fallback to template replacement
    for (int i = 0; i < count; i++) {
      String record = template;
      record = record.replaceAll('{{uuid}}', _generateUUID());
      record = record.replaceAll('{{name}}', _generateName(math));
      record = record.replaceAll('{{email}}', _generateEmail(math));
      record = record.replaceAll('{{number}}', math.nextInt(10000).toString());
      records.add(record);
    }

    return '[\n  ${records.join(',\n  ')}\n]';
  }

  String _prettyPrint(String jsonString) {
    final dynamic obj = jsonDecode(jsonString);
    return const JsonEncoder.withIndent('  ').convert(obj);
  }

  dynamic _generateFromSchema(Map<String, dynamic> schema, Math.Random r) {
    final String type = schema['type'] ?? 'object';

    switch (type) {
      case 'string':
        if (schema['format'] == 'email') return _generateEmail(r);
        if (schema['format'] == 'date-time') return DateTime.now().subtract(Duration(days: r.nextInt(365))).toIso8601String();
        if (schema['format'] == 'uuid') return _generateUUID();
        return ['Alpha', 'Beta', 'Gamma', 'Delta'][r.nextInt(4)] + '_' + r.nextInt(100).toString();
      case 'integer':
      case 'number':
        final int min = schema['minimum']?.toInt() ?? 0;
        final int max = schema['maximum']?.toInt() ?? 1000;
        return min + r.nextInt(max - min + 1);
      case 'boolean':
        return r.nextBool();
      case 'array':
        final itemSchema = schema['items'] ?? {};
        return List.generate(2, (_) => _generateFromSchema(itemSchema, r));
      case 'object':
      default:
        final Map<String, dynamic> result = {};
        if (schema.containsKey('properties')) {
          final Map<String, dynamic> properties = schema['properties'];
          properties.forEach((key, value) {
            result[key] = _generateFromSchema(value as Map<String, dynamic>, r);
          });
        }
        return result;
    }
  }

  String _generateUUID() {
    final math = Math.Random();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(RegExp(r'[xy]'), (match) {
      final r = math.nextInt(16);
      final v = match.group(0) == 'x' ? r : (r & 0x3 | 0x8);
      return v.toRadixString(16);
    });
  }

  String _generateName(Math.Random r) {
    const firstNames = ['John', 'Jane', 'Alice', 'Bob', 'Charlie', 'Diana', 'Edward', 'Fiona'];
    const lastNames = ['Doe', 'Smith', 'Johnson', 'Brown', 'Williams', 'Miller', 'Davis', 'Wilson'];
    return '${firstNames[r.nextInt(firstNames.length)]} ${lastNames[r.nextInt(lastNames.length)]}';
  }

  String _generateEmail(Math.Random r) {
    const domains = ['example.com', 'test.io', 'tracely.ai', 'corp.net'];
    final name = _generateName(r).toLowerCase().replaceAll(' ', '.');
    return '$name@${domains[r.nextInt(domains.length)]}';
  }
}

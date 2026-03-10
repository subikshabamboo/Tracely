import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../core/app_state.dart';

class ContractTestingScreen extends StatefulWidget {
  const ContractTestingScreen({super.key});

  @override
  State<ContractTestingScreen> createState() => _ContractTestingScreenState();
}

class _ContractTestingScreenState extends State<ContractTestingScreen> {
  final TextEditingController _schemaController = TextEditingController();
  final TextEditingController _sampleController = TextEditingController();
  String _validationResult = '';
  bool _isValidating = false;
  List<dynamic> _savedContracts = [];
  bool _isLoadingContracts = true;
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _schemaController.text = _appState.lastContractSchema;
    _sampleController.text = _appState.lastContractSample;
    _validationResult = _appState.lastValidationResult;
    
    _schemaController.addListener(() => _appState.lastContractSchema = _schemaController.text);
    _sampleController.addListener(() => _appState.lastContractSample = _sampleController.text);
    
    _fetchContracts();
  }

  void _validateSchema() {
    setState(() {
      _isValidating = true;
      _validationResult = '';
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      
      final schemaText = _schemaController.text;
      final sampleText = _sampleController.text;

      if (schemaText.isEmpty || sampleText.isEmpty) {
        setState(() {
          _validationResult = 'Error: Schema and Sample Response are required.';
          _isValidating = false;
        });
        return;
      }

      try {
        final schema = jsonDecode(schemaText);
        final sample = jsonDecode(sampleText);
        
        final errors = <String>[];
        _validateJsonAgainstSchema(schema, sample, 'root', errors);
        
        setState(() {
          if (errors.isEmpty) {
            _validationResult = '✅ Success: Sample response matches the schema definition.';
          } else {
            _validationResult = '❌ Failure (${errors.length} errors found):\n${errors.join('\n')}';
          }
          _appState.lastValidationResult = _validationResult;
          _isValidating = false;
        });
      } catch (e) {
        setState(() {
          _validationResult = '❌ Failure: Invalid JSON format in schema or sample.';
          _isValidating = false;
        });
      }
    });
  }

  void _validateJsonAgainstSchema(dynamic schema, dynamic data, String path, List<String> errors) {
    if (schema is! Map) return;

    // 1. Type Validation
    if (schema.containsKey('type')) {
      final String type = schema['type'];
      bool typeMatch = true;
      switch (type) {
        case 'string': if (data is! String) typeMatch = false; break;
        case 'integer': if (data is! int) typeMatch = false; break;
        case 'number': if (data is! num) typeMatch = false; break;
        case 'boolean': if (data is! bool) typeMatch = false; break;
        case 'object': if (data is! Map) typeMatch = false; break;
        case 'array': if (data is! List) typeMatch = false; break;
      }
      if (!typeMatch) {
         errors.add("• field '$path' expected type $type but got ${data.runtimeType}");
         return; // Don't validate constraints if type is wrong
      }
    }

    // 2. Enum Validation
    if (schema.containsKey('enum')) {
      final List options = schema['enum'];
      if (!options.contains(data)) {
        errors.add("• field '$path' value '$data' is not one of: $options");
      }
    }

    // 3. Numeric Constraints
    if (data is num) {
      if (schema.containsKey('minimum')) {
        final num min = schema['minimum'];
        if (data < min) errors.add("• field '$path' is $data, less than min $min");
      }
      if (schema.containsKey('maximum')) {
        final num max = schema['maximum'];
        if (data > max) errors.add("• field '$path' is $data, more than max $max");
      }
    }

    // 4. Object Properties and Required Fields
    if (data is Map && schema.containsKey('properties')) {
      final Map properties = schema['properties'];
      
      // Check Required
      if (schema.containsKey('required')) {
        final List requiredFields = schema['required'];
        for (final field in requiredFields) {
          if (!data.containsKey(field)) {
            errors.add("• missing required field '$field'");
          }
        }
      }

      // Validate each property recursively
      for (final key in data.keys) {
        if (properties.containsKey(key)) {
          _validateJsonAgainstSchema(properties[key], data[key], '$path.$key', errors);
        }
      }
    }

    // 5. Array Items
    if (data is List && schema.containsKey('items')) {
      final itemSchema = schema['items'];
      for (int i = 0; i < data.length; i++) {
        _validateJsonAgainstSchema(itemSchema, data[i], '$path[$i]', errors);
      }
    }
  }


  Future<void> _fetchContracts() async {
    try {
      final api = ApiService();
      final result = await api.getContractTests(null);
      if (mounted && result.isSuccess) {
        setState(() {
          _savedContracts = result.data;
          _isLoadingContracts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingContracts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contract & Schema Testing')),
      body: Row(
        children: [
          // Left Side: Active Contracts List
          Container(
            width: 300,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white10)),
            ),
            child: _isLoadingContracts 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savedContracts.length,
                  itemBuilder: (context, index) {
                    final c = _savedContracts[index];
                    return Card(
                      color: TracelyTheme.surfaceColor,
                      child: ListTile(
                        title: Text(c['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(c['status'].toString().toUpperCase(), 
                          style: TextStyle(color: c['status'] == 'passed' ? Colors.greenAccent : Colors.redAccent, fontSize: 10)),
                        onTap: () {
                          // Load details would go here
                        },
                      ),
                    );
                  },
                ),
          ),
          // Right Side: Validation Tool
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildInputArea('JSON Schema / OpenAPI', _schemaController)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildInputArea('Sample Response', _sampleController)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_validationResult.isNotEmpty)
                    _buildResultContainer(),
                  _buildActionRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: _validationResult.contains('Success') ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _validationResult.contains('Success') ? Colors.green : Colors.redAccent, width: 1),
      ),
      child: Text(_validationResult, style: TextStyle(color: _validationResult.contains('Success') ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: _isValidating ? null : _validateSchema,
          icon: _isValidating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
          label: const Text('Run Validation'),
        ),
      ],
    );
  }

  Widget _buildInputArea(String title, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 12),
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              fillColor: TracelyTheme.surfaceColor,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
      ],
    );
  }
}


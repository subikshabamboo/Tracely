import 'package:flutter/foundation.dart';

class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // Test Data Generator State
  String lastDataSchema = '';
  String lastGeneratedData = '';

  // Contract Testing State
  String lastContractSchema = '';
  String lastContractSample = '';
  String lastValidationResult = '';

  // Request Studio State
  String lastMethod = 'GET';
  String lastUrl = 'http://localhost:8080/api/v1/health';
  String lastRequestBody = '';
  Map<String, dynamic>? lastResponse;

  // Global Refreshers
  final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);
  
  void triggerRefresh() {
    refreshNotifier.value++;
  }
}

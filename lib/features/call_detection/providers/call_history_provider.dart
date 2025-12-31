/// Call history provider for state management
import 'package:flutter/foundation.dart';
import '../services/call_risk_service.dart';

class CallHistoryProvider extends ChangeNotifier {
  final CallRiskService _callRiskService = CallRiskService();

  List<CallRiskResult> _callHistory = [];
  List<CallRiskResult> get callHistory => _callHistory;

  CallRiskResult? _currentCall;
  CallRiskResult? get currentCall => _currentCall;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  CallHistoryProvider() {
    _initialize();
  }

  void _initialize() {
    _callRiskService.initialize();

    // Listen to call state changes
    _callRiskService.callStateStream.listen((result) {
      _currentCall = result;
      _addToHistory(result);
      notifyListeners();
    });
  }

  void _addToHistory(CallRiskResult result) {
    _callHistory.insert(0, result);
    // Keep only last 50 calls
    if (_callHistory.length > 50) {
      _callHistory = _callHistory.sublist(0, 50);
    }
  }

  Future<void> startMonitoring() async {
    _isMonitoring = await _callRiskService.startMonitoring();
    notifyListeners();
  }

  Future<void> stopMonitoring() async {
    await _callRiskService.stopMonitoring();
    _isMonitoring = false;
    notifyListeners();
  }

  void clearHistory() {
    _callHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _callRiskService.dispose();
    super.dispose();
  }
}

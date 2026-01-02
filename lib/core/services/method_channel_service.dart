import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

/// Callback types for native events
typedef CallStateCallback = void Function(String phoneNumber, bool isIncoming);
typedef CallEndedCallback = void Function();
typedef RecordingStartedCallback = void Function(String filePath);
typedef RecordingStoppedCallback = void Function(String filePath);
typedef ContactSavedCallback =
    void Function(
      String phoneNumber,
      String name,
      String? email,
      String? category,
    );
typedef ContactUpdatedCallback =
    void Function(
      String phoneNumber,
      String name,
      String? email,
      String? category,
    );

class MethodChannelService {
  static const MethodChannel _channel = MethodChannel(
    AppConstants.methodChannelName,
  );

  // Singleton instance
  static final MethodChannelService _instance =
      MethodChannelService._internal();
  factory MethodChannelService() => _instance;
  MethodChannelService._internal();

  // Callbacks
  CallStateCallback? _onCallStateChanged;
  CallEndedCallback? _onCallEnded;
  RecordingStartedCallback? _onRecordingStarted;
  RecordingStoppedCallback? _onRecordingStopped;
  ContactSavedCallback? _onContactSaved;
  ContactUpdatedCallback? _onContactUpdated;

  /// Initialize method channel and set up listeners
  void initialize({
    required CallStateCallback onCallStateChanged,
    required CallEndedCallback onCallEnded,
    RecordingStartedCallback? onRecordingStarted,
    RecordingStoppedCallback? onRecordingStopped,
    ContactSavedCallback? onContactSaved,
    ContactUpdatedCallback? onContactUpdated,
  }) {
    _onCallStateChanged = onCallStateChanged;
    _onCallEnded = onCallEnded;
    _onRecordingStarted = onRecordingStarted;
    _onRecordingStopped = onRecordingStopped;
    _onContactSaved = onContactSaved;
    _onContactUpdated = onContactUpdated;

    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handle incoming method calls from native
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCallStateChanged':
        final args = call.arguments as Map<dynamic, dynamic>;
        final phoneNumber = args['phoneNumber'] as String? ?? '';
        final isIncoming = args['isIncoming'] as bool? ?? true;
        _onCallStateChanged?.call(phoneNumber, isIncoming);
        break;
      case 'onCallEnded':
        _onCallEnded?.call();
        break;
      case 'onRecordingStarted':
        final args = call.arguments as Map<dynamic, dynamic>;
        final filePath = args['filePath'] as String? ?? '';
        _onRecordingStarted?.call(filePath);
        break;
      case 'onRecordingStopped':
        final args = call.arguments as Map<dynamic, dynamic>;
        final filePath = args['filePath'] as String? ?? '';
        _onRecordingStopped?.call(filePath);
        break;
      case 'onContactSaved':
        final args = call.arguments as Map<dynamic, dynamic>;
        final phoneNumber = args['phoneNumber'] as String? ?? '';
        final name = args['name'] as String? ?? '';
        final email = args['email'] as String?;
        final category = args['category'] as String?;
        _onContactSaved?.call(phoneNumber, name, email, category);
        break;
      case 'onContactUpdated':
        final args = call.arguments as Map<dynamic, dynamic>;
        final phoneNumber = args['phoneNumber'] as String? ?? '';
        final name = args['name'] as String? ?? '';
        final email = args['email'] as String?;
        final category = args['category'] as String?;
        _onContactUpdated?.call(phoneNumber, name, email, category);
        break;
      default:
        throw MissingPluginException('Method ${call.method} not implemented');
    }
  }

  /// Start the call monitoring service
  Future<bool> startCallMonitoringService() async {
    try {
      final result = await _channel.invokeMethod<bool>('startCallMonitoring');
      return result ?? false;
    } on PlatformException catch (e) {
      _log('Failed to start call monitoring: ${e.message}');
      return false;
    }
  }

  /// Stop the call monitoring service
  Future<bool> stopCallMonitoringService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopCallMonitoring');
      return result ?? false;
    } on PlatformException catch (e) {
      _log('Failed to stop call monitoring: ${e.message}');
      return false;
    }
  }

  /// Show risk overlay during call
  Future<bool> showRiskOverlay({
    required int riskScore,
    required String riskLevel,
    required String explanation,
    required String phoneNumber,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('showRiskOverlay', {
        'riskScore': riskScore,
        'riskLevel': riskLevel,
        'explanation': explanation,
        'phoneNumber': phoneNumber,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _log('Failed to show overlay: ${e.message}');
      return false;
    }
  }

  /// Update AI analysis result in overlay
  Future<bool> updateAIResult({
    required double probability,
    required bool isSynthetic,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('updateAIResult', {
        'probability': probability,
        'isSynthetic': isSynthetic,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _log('Failed to update AI result: ${e.message}');
      return false;
    }
  }

  /// Hide risk overlay
  Future<bool> hideRiskOverlay() async {
    try {
      final result = await _channel.invokeMethod<bool>('hideRiskOverlay');
      return result ?? false;
    } on PlatformException catch (e) {
      _log('Failed to hide overlay: ${e.message}');
      return false;
    }
  }

  /// Get current recording path
  Future<String?> getCurrentRecordingPath() async {
    try {
      final result = await _channel.invokeMethod<String>(
        'getCurrentRecordingPath',
      );
      return result;
    } on PlatformException catch (e) {
      _log('Failed to get recording path: ${e.message}');
      return null;
    }
  }

  /// Check if overlay permission is granted
  Future<bool> checkOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'checkOverlayPermission',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      _log('Failed to check overlay permission: ${e.message}');
      return false;
    }
  }

  /// Request overlay permission
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      _log('Failed to request overlay permission: ${e.message}');
    }
  }

  /// Get call history from native
  Future<List<Map<String, dynamic>>> getRecentCalls({int limit = 20}) async {
    try {
      final result = await _channel.invokeMethod<List>('getRecentCalls', {
        'limit': limit,
      });
      return result?.cast<Map<String, dynamic>>() ?? [];
    } on PlatformException catch (e) {
      _log('Failed to get recent calls: ${e.message}');
      return [];
    }
  }

  /// Analyze phone number for risk
  Future<Map<String, dynamic>> analyzePhoneNumber(String phoneNumber) async {
    try {
      final result = await _channel.invokeMethod<Map>('analyzePhoneNumber', {
        'phoneNumber': phoneNumber,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      _log('Failed to analyze phone number: ${e.message}');
      return {};
    }
  }

  /// Check if protection is enabled (from saved state)
  Future<bool> isProtectionEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isProtectionEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      _log('Failed to check protection state: ${e.message}');
      return false;
    }
  }

  /// Check if battery optimization is enabled
  /// Returns true if app IS being optimized (needs exemption)
  /// Returns false if app is NOT being optimized (already exempted)
  Future<bool> checkBatteryOptimization() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'checkBatteryOptimization',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      _log('Failed to check battery optimization: ${e.message}');
      return false;
    }
  }

  /// Request battery optimization exemption
  Future<void> requestBatteryOptimizationExemption() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimizationExemption');
    } on PlatformException catch (e) {
      _log('Failed to request battery optimization exemption: ${e.message}');
    }
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[MethodChannelService] $message');
  }
}

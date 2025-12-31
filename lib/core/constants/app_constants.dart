/// Application-wide constants
class AppConstants {
  // App Info
  static const String appName = 'RiskGuard';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'AI-Powered Digital Protection';

  // API Endpoints (Configure for your backend)
  static const String baseUrl = 'http://localhost:8000';
  static const String apiVersion = 'v1';

  // API Routes
  static String get apiBase => '$baseUrl/api/$apiVersion';
  static String get voiceAnalysisEndpoint => '$apiBase/analyze/voice';
  static String get textAnalysisEndpoint => '$apiBase/analyze/text';
  static String get riskScoringEndpoint => '$apiBase/score/calculate';
  static String get videoAnalysisEndpoint => '$apiBase/analyze/video';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 10);
  static const Duration analysisTimeout = Duration(seconds: 30);
  static const Duration overlayDisplayDuration = Duration(seconds: 5);

  // Analysis Thresholds
  static const int minVoiceSampleDuration = 3; // seconds
  static const int maxVoiceSampleDuration = 30; // seconds
  static const int minTextLength = 10; // characters
  static const int maxTextLength = 5000; // characters

  // Scoring Weights (sum should be 1.0)
  static const double callMetadataWeight = 0.25;
  static const double voiceAnalysisWeight = 0.30;
  static const double contentAnalysisWeight = 0.30;
  static const double historyWeight = 0.15;

  // Storage Keys
  static const String themeKey = 'app_theme';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String callHistoryKey = 'call_history';
  static const String analysisHistoryKey = 'analysis_history';

  // Method Channel
  static const String methodChannelName = 'com.riskguard.app/channel';

  // Notification Channel
  static const String notificationChannelId = 'riskguard_service';
  static const String notificationChannelName = 'RiskGuard Service';
  static const String notificationChannelDesc =
      'Notifications for call monitoring service';

  // Feature Flags
  static const bool enableVoiceAnalysis = true;
  static const bool enableVideoAnalysis = true;
  static const bool enableCloudAnalysis = true;
  static const bool enableOfflineMode = true;
}

/// Animation durations for consistent UX
class AnimationDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);
}

/// Spacing constants for consistent layouts
class Spacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Border radius constants
class BorderRadii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double round = 100.0;
}

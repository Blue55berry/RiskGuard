/// Message Analyzer Service - NLP-based phishing and scam detection
import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';

/// Types of message threats
enum ThreatType {
  phishing,
  urgency,
  fakeOffer,
  suspiciousLink,
  impersonation,
  financialScam,
  socialEngineering,
  safe,
}

extension ThreatTypeExtension on ThreatType {
  String get label {
    switch (this) {
      case ThreatType.phishing:
        return 'Phishing Attempt';
      case ThreatType.urgency:
        return 'Urgency Manipulation';
      case ThreatType.fakeOffer:
        return 'Fake Offer';
      case ThreatType.suspiciousLink:
        return 'Suspicious Link';
      case ThreatType.impersonation:
        return 'Impersonation';
      case ThreatType.financialScam:
        return 'Financial Scam';
      case ThreatType.socialEngineering:
        return 'Social Engineering';
      case ThreatType.safe:
        return 'Safe';
    }
  }

  String get icon {
    switch (this) {
      case ThreatType.phishing:
        return '🎣';
      case ThreatType.urgency:
        return '⚠️';
      case ThreatType.fakeOffer:
        return '🎁';
      case ThreatType.suspiciousLink:
        return '🔗';
      case ThreatType.impersonation:
        return '🎭';
      case ThreatType.financialScam:
        return '💰';
      case ThreatType.socialEngineering:
        return '🕵️';
      case ThreatType.safe:
        return '✅';
    }
  }
}

/// Result of message analysis
class MessageAnalysisResult {
  final int riskScore;
  final List<ThreatType> detectedThreats;
  final List<String> suspiciousPatterns;
  final List<String> extractedUrls;
  final String explanation;
  final bool isSafe;
  final DateTime analyzedAt;

  MessageAnalysisResult({
    required this.riskScore,
    required this.detectedThreats,
    required this.suspiciousPatterns,
    required this.extractedUrls,
    required this.explanation,
    required this.isSafe,
    required this.analyzedAt,
  });

  factory MessageAnalysisResult.safe() {
    return MessageAnalysisResult(
      riskScore: 0,
      detectedThreats: [],
      suspiciousPatterns: [],
      extractedUrls: [],
      explanation: 'No threats detected. This message appears safe.',
      isSafe: true,
      analyzedAt: DateTime.now(),
    );
  }
}

/// Service for analyzing text messages
class MessageAnalyzerService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.analysisTimeout,
    ),
  );

  // Common phishing patterns
  static const List<String> _urgencyPatterns = [
    'urgent',
    'immediately',
    'act now',
    'limited time',
    'expires today',
    'last chance',
    'don\'t miss',
    'hurry',
    'within 24 hours',
    'account suspended',
    'account blocked',
    'verify immediately',
  ];

  static const List<String> _phishingPatterns = [
    'verify your account',
    'confirm your identity',
    'update your payment',
    'click here to login',
    'reset your password',
    'suspicious activity',
    'unauthorized access',
    'security alert',
    'we noticed unusual',
    'your account has been',
  ];

  static const List<String> _fakeOfferPatterns = [
    'you have won',
    'congratulations',
    'selected winner',
    'claim your prize',
    'free gift',
    'lottery winner',
    'million dollars',
    'exclusive offer',
    'only for you',
    'limited offer',
  ];

  static const List<String> _financialScamPatterns = [
    'bank account',
    'credit card',
    'transfer money',
    'send money',
    'wire transfer',
    'bitcoin',
    'investment opportunity',
    'double your money',
    'guaranteed returns',
    'make money fast',
  ];

  static const List<String> _suspiciousDomains = [
    'bit.ly',
    'tinyurl',
    'goo.gl',
    't.co',
    'ow.ly',
    'is.gd',
    'buff.ly',
    'adf.ly',
    'bc.vc',
    's.id',
  ];

  /// Analyze a message for threats
  Future<MessageAnalysisResult> analyzeMessage(String message) async {
    if (message.trim().isEmpty || message.length < AppConstants.minTextLength) {
      return MessageAnalysisResult.safe();
    }

    try {
      // Try cloud analysis first
      if (AppConstants.enableCloudAnalysis) {
        try {
          return await _cloudAnalysis(message);
        } catch (e) {
          print('Cloud analysis failed, using local: $e');
        }
      }

      // Local analysis
      return _localAnalysis(message);
    } catch (e) {
      print('Message analysis error: $e');
      return MessageAnalysisResult.safe();
    }
  }

  /// Cloud-based NLP analysis
  Future<MessageAnalysisResult> _cloudAnalysis(String message) async {
    final response = await _dio.post(
      AppConstants.textAnalysisEndpoint,
      data: {'text': message},
    );

    if (response.statusCode == 200) {
      final data = response.data;
      return MessageAnalysisResult(
        riskScore: data['riskScore'] ?? 0,
        detectedThreats:
            (data['threats'] as List?)
                ?.map(
                  (t) => ThreatType.values.firstWhere(
                    (e) => e.name == t,
                    orElse: () => ThreatType.safe,
                  ),
                )
                .toList() ??
            [],
        suspiciousPatterns: List<String>.from(data['patterns'] ?? []),
        extractedUrls: List<String>.from(data['urls'] ?? []),
        explanation: data['explanation'] ?? '',
        isSafe: data['isSafe'] ?? true,
        analyzedAt: DateTime.now(),
      );
    }

    throw Exception('Cloud analysis failed');
  }

  /// Local pattern-based analysis
  MessageAnalysisResult _localAnalysis(String message) {
    final lowerMessage = message.toLowerCase();
    int riskScore = 0;
    final detectedThreats = <ThreatType>[];
    final suspiciousPatterns = <String>[];
    final extractedUrls = <String>[];

    // Extract URLs
    final urlRegex = RegExp(
      r'https?://[^\s]+|www\.[^\s]+',
      caseSensitive: false,
    );
    extractedUrls.addAll(urlRegex.allMatches(message).map((m) => m.group(0)!));

    // Check for suspicious shortened URLs
    for (final url in extractedUrls) {
      for (final domain in _suspiciousDomains) {
        if (url.toLowerCase().contains(domain)) {
          riskScore += 25;
          suspiciousPatterns.add('Shortened URL detected: $domain');
          if (!detectedThreats.contains(ThreatType.suspiciousLink)) {
            detectedThreats.add(ThreatType.suspiciousLink);
          }
        }
      }
    }

    // Check urgency patterns
    for (final pattern in _urgencyPatterns) {
      if (lowerMessage.contains(pattern)) {
        riskScore += 15;
        suspiciousPatterns.add('Urgency: "$pattern"');
        if (!detectedThreats.contains(ThreatType.urgency)) {
          detectedThreats.add(ThreatType.urgency);
        }
      }
    }

    // Check phishing patterns
    for (final pattern in _phishingPatterns) {
      if (lowerMessage.contains(pattern)) {
        riskScore += 20;
        suspiciousPatterns.add('Phishing: "$pattern"');
        if (!detectedThreats.contains(ThreatType.phishing)) {
          detectedThreats.add(ThreatType.phishing);
        }
      }
    }

    // Check fake offer patterns
    for (final pattern in _fakeOfferPatterns) {
      if (lowerMessage.contains(pattern)) {
        riskScore += 20;
        suspiciousPatterns.add('Fake offer: "$pattern"');
        if (!detectedThreats.contains(ThreatType.fakeOffer)) {
          detectedThreats.add(ThreatType.fakeOffer);
        }
      }
    }

    // Check financial scam patterns
    for (final pattern in _financialScamPatterns) {
      if (lowerMessage.contains(pattern)) {
        riskScore += 15;
        suspiciousPatterns.add('Financial: "$pattern"');
        if (!detectedThreats.contains(ThreatType.financialScam)) {
          detectedThreats.add(ThreatType.financialScam);
        }
      }
    }

    // Clamp risk score
    riskScore = riskScore.clamp(0, 100);

    // Generate explanation
    final explanation = _generateExplanation(
      riskScore,
      detectedThreats,
      suspiciousPatterns,
    );

    return MessageAnalysisResult(
      riskScore: riskScore,
      detectedThreats: detectedThreats,
      suspiciousPatterns: suspiciousPatterns,
      extractedUrls: extractedUrls,
      explanation: explanation,
      isSafe: riskScore < 30,
      analyzedAt: DateTime.now(),
    );
  }

  String _generateExplanation(
    int score,
    List<ThreatType> threats,
    List<String> patterns,
  ) {
    if (score == 0) {
      return 'This message appears safe. No suspicious patterns detected.';
    }

    if (score < 30) {
      return 'Low risk detected. Some minor patterns found but likely safe.';
    }

    if (score < 60) {
      final threatStr = threats.map((t) => t.label).join(', ');
      return 'Moderate risk detected. Found indicators of: $threatStr. '
          'Be cautious and verify the sender.';
    }

    final threatStr = threats.map((t) => t.label).join(', ');
    return 'High risk detected! This message shows strong indicators of: $threatStr. '
        'Do not click any links or provide personal information.';
  }
}

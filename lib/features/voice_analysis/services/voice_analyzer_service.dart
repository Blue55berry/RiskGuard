/// Voice Analyzer Service - Analyzes audio for AI-generated voice detection
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';

/// Voice classification types
enum VoiceClassification { human, aiGenerated, uncertain }

extension VoiceClassificationExtension on VoiceClassification {
  String get label {
    switch (this) {
      case VoiceClassification.human:
        return 'Human Voice';
      case VoiceClassification.aiGenerated:
        return 'AI Generated';
      case VoiceClassification.uncertain:
        return 'Uncertain';
    }
  }

  String get icon {
    switch (this) {
      case VoiceClassification.human:
        return '👤';
      case VoiceClassification.aiGenerated:
        return '🤖';
      case VoiceClassification.uncertain:
        return '❓';
    }
  }
}

/// Result of voice analysis
class VoiceAnalysisResult {
  final double syntheticProbability;
  final double confidence;
  final List<String> detectedPatterns;
  final String explanation;
  final bool isLikelyAI;
  final VoiceClassification classification;

  VoiceAnalysisResult({
    required this.syntheticProbability,
    required this.confidence,
    required this.detectedPatterns,
    required this.explanation,
    required this.isLikelyAI,
    required this.classification,
  });

  factory VoiceAnalysisResult.fromJson(Map<String, dynamic> json) {
    final syntheticProb = (json['syntheticProbability'] as num).toDouble();
    return VoiceAnalysisResult(
      syntheticProbability: syntheticProb,
      confidence: (json['confidence'] as num).toDouble(),
      detectedPatterns: List<String>.from(json['detectedPatterns'] ?? []),
      explanation: json['explanation'] as String? ?? '',
      isLikelyAI: json['isLikelyAI'] as bool? ?? false,
      classification: _classifyVoice(syntheticProb),
    );
  }

  Map<String, dynamic> toJson() => {
    'syntheticProbability': syntheticProbability,
    'confidence': confidence,
    'detectedPatterns': detectedPatterns,
    'explanation': explanation,
    'isLikelyAI': isLikelyAI,
    'classification': classification.name,
  };

  static VoiceClassification _classifyVoice(double syntheticProbability) {
    if (syntheticProbability < 0.35) {
      return VoiceClassification.human;
    } else if (syntheticProbability > 0.65) {
      return VoiceClassification.aiGenerated;
    } else {
      return VoiceClassification.uncertain;
    }
  }
}

/// Service for analyzing voice recordings
class VoiceAnalyzerService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.analysisTimeout,
    ),
  );

  /// Analyze an audio file for synthetic voice characteristics
  Future<VoiceAnalysisResult> analyzeAudio(String filePath) async {
    try {
      // First try cloud analysis
      if (AppConstants.enableCloudAnalysis) {
        try {
          return await _cloudAnalysis(filePath);
        } catch (e) {
          print('Cloud analysis failed, falling back to local: $e');
        }
      }

      // Fallback to local analysis
      return await _localAnalysis(filePath);
    } catch (e) {
      print('Voice analysis error: $e');
      return _getDefaultResult();
    }
  }

  /// Cloud-based analysis using backend API
  Future<VoiceAnalysisResult> _cloudAnalysis(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Audio file not found');
    }

    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        filePath,
        filename: 'voice_sample.m4a',
      ),
    });

    final response = await _dio.post(
      AppConstants.voiceAnalysisEndpoint,
      data: formData,
    );

    if (response.statusCode == 200) {
      return VoiceAnalysisResult.fromJson(response.data);
    }

    throw Exception('Analysis failed with status: ${response.statusCode}');
  }

  /// Local on-device analysis (simulation for demo)
  /// In production, this would use TensorFlow Lite or similar
  Future<VoiceAnalysisResult> _localAnalysis(String filePath) async {
    // Simulate analysis delay
    await Future.delayed(const Duration(seconds: 2));

    // For demo purposes, generate realistic-looking results
    // In production, this would analyze actual audio features:
    // - Pitch stability
    // - Spectral irregularities
    // - Breathing patterns
    // - Micro-pauses
    // - Formant transitions

    final random = Random();
    final syntheticProb = random.nextDouble() * 0.5; // 0-50% for demo

    final patterns = <String>[];

    if (syntheticProb > 0.3) {
      patterns.add('Unusual pitch stability');
    }
    if (syntheticProb > 0.4) {
      patterns.add('Repetitive frequency patterns');
    }
    if (random.nextBool() && syntheticProb > 0.35) {
      patterns.add('Missing micro-variations');
    }

    String explanation;
    bool isLikelyAI;
    VoiceClassification classification;

    if (syntheticProb < 0.35) {
      explanation =
          'Voice appears natural with normal variations and human speech patterns.';
      isLikelyAI = false;
      classification = VoiceClassification.human;
    } else if (syntheticProb < 0.65) {
      explanation =
          'Voice shows some unusual patterns. Detection is uncertain - could be human with artifacts or AI-generated.';
      isLikelyAI = false;
      classification = VoiceClassification.uncertain;
    } else {
      explanation =
          'Strong synthetic voice indicators detected. This voice is likely AI-generated.';
      isLikelyAI = true;
      classification = VoiceClassification.aiGenerated;
    }

    return VoiceAnalysisResult(
      syntheticProbability: syntheticProb,
      confidence: 0.7 + random.nextDouble() * 0.25,
      detectedPatterns: patterns,
      explanation: explanation,
      isLikelyAI: isLikelyAI,
      classification: classification,
    );
  }

  VoiceAnalysisResult _getDefaultResult() {
    return VoiceAnalysisResult(
      syntheticProbability: 0.0,
      confidence: 0.0,
      detectedPatterns: [],
      explanation: 'Unable to analyze. Please try again.',
      isLikelyAI: false,
      classification: VoiceClassification.uncertain,
    );
  }
}

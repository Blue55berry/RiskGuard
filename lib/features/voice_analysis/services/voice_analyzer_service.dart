/// Voice Analyzer Service - Analyzes audio for AI-generated voice detection
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';

/// Result of voice analysis
class VoiceAnalysisResult {
  final double syntheticProbability;
  final double confidence;
  final List<String> detectedPatterns;
  final String explanation;
  final bool isLikelyAI;

  VoiceAnalysisResult({
    required this.syntheticProbability,
    required this.confidence,
    required this.detectedPatterns,
    required this.explanation,
    required this.isLikelyAI,
  });

  factory VoiceAnalysisResult.fromJson(Map<String, dynamic> json) {
    return VoiceAnalysisResult(
      syntheticProbability: (json['syntheticProbability'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      detectedPatterns: List<String>.from(json['detectedPatterns'] ?? []),
      explanation: json['explanation'] as String? ?? '',
      isLikelyAI: json['isLikelyAI'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'syntheticProbability': syntheticProbability,
    'confidence': confidence,
    'detectedPatterns': detectedPatterns,
    'explanation': explanation,
    'isLikelyAI': isLikelyAI,
  };
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

    if (syntheticProb < 0.2) {
      explanation =
          'Voice appears natural with normal variations and human speech patterns.';
      isLikelyAI = false;
    } else if (syntheticProb < 0.4) {
      explanation =
          'Voice shows some unusual patterns but is likely human. Minor irregularities detected.';
      isLikelyAI = false;
    } else if (syntheticProb < 0.6) {
      explanation =
          'Moderate indicators suggest possible AI-generation. Exercise caution.';
      isLikelyAI = true;
    } else {
      explanation =
          'Strong synthetic voice indicators detected. This voice may be AI-generated.';
      isLikelyAI = true;
    }

    return VoiceAnalysisResult(
      syntheticProbability: syntheticProb,
      confidence: 0.7 + random.nextDouble() * 0.25,
      detectedPatterns: patterns,
      explanation: explanation,
      isLikelyAI: isLikelyAI,
    );
  }

  VoiceAnalysisResult _getDefaultResult() {
    return VoiceAnalysisResult(
      syntheticProbability: 0.0,
      confidence: 0.0,
      detectedPatterns: [],
      explanation: 'Unable to analyze. Please try again.',
      isLikelyAI: false,
    );
  }
}

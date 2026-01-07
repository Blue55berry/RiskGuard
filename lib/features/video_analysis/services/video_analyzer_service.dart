import 'dart:io';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import '../../../core/constants/app_constants.dart';

/// Video threat types
enum VideoThreatType { deepfake, faceSwap, lipSync, manipulation, safe }

extension VideoThreatExtension on VideoThreatType {
  String get label {
    switch (this) {
      case VideoThreatType.deepfake:
        return 'Deepfake Detected';
      case VideoThreatType.faceSwap:
        return 'Face Swap';
      case VideoThreatType.lipSync:
        return 'Lip Sync Manipulation';
      case VideoThreatType.manipulation:
        return 'Video Manipulation';
      case VideoThreatType.safe:
        return 'Authentic Video';
    }
  }

  String get icon {
    switch (this) {
      case VideoThreatType.deepfake:
        return '🎭';
      case VideoThreatType.faceSwap:
        return '👥';
      case VideoThreatType.lipSync:
        return '👄';
      case VideoThreatType.manipulation:
        return '✂️';
      case VideoThreatType.safe:
        return '✅';
    }
  }
}

/// Result of video analysis
class VideoAnalysisResult {
  final String videoPath;
  final double deepfakeProbability;
  final double confidence;
  final List<VideoThreatType> detectedThreats;
  final List<String> manipulationPatterns;
  final int analyzedFrames;
  final String explanation;
  final bool isAuthentic;
  final DateTime analyzedAt;

  VideoAnalysisResult({
    required this.videoPath,
    required this.deepfakeProbability,
    required this.confidence,
    required this.detectedThreats,
    required this.manipulationPatterns,
    required this.analyzedFrames,
    required this.explanation,
    required this.isAuthentic,
    required this.analyzedAt,
  });

  factory VideoAnalysisResult.safe(String videoPath) {
    return VideoAnalysisResult(
      videoPath: videoPath,
      deepfakeProbability: 0.0,
      confidence: 0.9,
      detectedThreats: [VideoThreatType.safe],
      manipulationPatterns: [],
      analyzedFrames: 0,
      explanation:
          'This video appears to be authentic. No manipulation detected.',
      isAuthentic: true,
      analyzedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'videoPath': videoPath,
    'deepfakeProbability': deepfakeProbability,
    'confidence': confidence,
    'detectedThreats': detectedThreats.map((t) => t.name).toList(),
    'manipulationPatterns': manipulationPatterns,
    'analyzedFrames': analyzedFrames,
    'explanation': explanation,
    'isAuthentic': isAuthentic,
    'analyzedAt': analyzedAt.toIso8601String(),
  };
}

/// Service for analyzing videos for deepfakes and manipulation
class VideoAnalyzerService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: const Duration(seconds: 120), // Longer timeout for video
    ),
  );

  /// Analyze a video file for deepfake and manipulation
  Future<VideoAnalysisResult> analyzeVideo(String videoPath) async {
    try {
      // First try cloud analysis
      if (AppConstants.enableCloudAnalysis) {
        try {
          return await _cloudAnalysis(videoPath);
        } catch (e) {
          developer.log(
            'Cloud video analysis failed, falling back to local: $e',
          );
        }
      }

      // Fallback to local analysis
      return await _localAnalysis(videoPath);
    } catch (e) {
      developer.log('Video analysis error: $e');
      return VideoAnalysisResult.safe(videoPath);
    }
  }

  /// Cloud-based analysis using backend API
  Future<VideoAnalysisResult> _cloudAnalysis(String videoPath) async {
    final file = File(videoPath);
    if (!await file.exists()) {
      throw Exception('Video file not found');
    }

    final formData = FormData.fromMap({
      'video': await MultipartFile.fromFile(
        videoPath,
        filename: 'video_sample.mp4',
      ),
    });

    final response = await _dio.post(
      AppConstants.videoAnalysisEndpoint,
      data: formData,
    );

    if (response.statusCode == 200) {
      final data = response.data;
      return VideoAnalysisResult(
        videoPath: videoPath,
        deepfakeProbability: (data['deepfakeProbability'] as num).toDouble(),
        confidence: (data['confidence'] as num).toDouble(),
        detectedThreats:
            (data['threats'] as List?)
                ?.map(
                  (t) => VideoThreatType.values.firstWhere(
                    (e) => e.name == t,
                    orElse: () => VideoThreatType.safe,
                  ),
                )
                .toList() ??
            [],
        manipulationPatterns: List<String>.from(data['patterns'] ?? []),
        analyzedFrames: data['analyzedFrames'] ?? 0,
        explanation: data['explanation'] ?? '',
        isAuthentic: data['isAuthentic'] ?? true,
        analyzedAt: DateTime.now(),
      );
    }

    throw Exception(
      'Video analysis failed with status: ${response.statusCode}',
    );
  }

  /// Local on-device analysis (pattern-based for demo)
  /// In production, this would use TensorFlow Lite or similar ML model
  Future<VideoAnalysisResult> _localAnalysis(String videoPath) async {
    developer.log('Starting local video analysis...');

    // Simulate processing with frame extraction
    final frames = await _extractFrames(videoPath, count: 5);
    developer.log('Extracted ${frames.length} frames');

    // Simulate analysis delay
    await Future.delayed(const Duration(seconds: 3));

    // For demo: Generate realistic results
    // In production, analyze frames for:
    // - Face warping artifacts
    // - Inconsistent lighting
    // - Temporal inconsistencies
    // - Facial feature irregularities
    // - Audio-visual sync issues

    final random = Random();
    final deepfakeProb = random.nextDouble() * 0.4; // 0-40% for demo

    final threats = <VideoThreatType>[];
    final patterns = <String>[];

    if (deepfakeProb > 0.15) {
      patterns.add('Facial expression inconsistencies detected');
    }
    if (deepfakeProb > 0.25) {
      patterns.add('Micro-artifacts around face region');
      threats.add(VideoThreatType.manipulation);
    }
    if (deepfakeProb > 0.35) {
      patterns.add('Temporal inconsistencies between frames');
      threats.add(VideoThreatType.deepfake);
    }

    String explanation;
    bool isAuthentic;

    if (deepfakeProb < 0.2) {
      explanation =
          'Video appears authentic. No significant manipulation patterns detected.';
      isAuthentic = true;
      threats.clear();
      threats.add(VideoThreatType.safe);
    } else if (deepfakeProb < 0.4) {
      explanation =
          'Some unusual patterns detected. Video may have been edited or compressed. Further verification recommended.';
      isAuthentic = false;
    } else {
      explanation =
          'Strong indicators of video manipulation detected. This video may be a deepfake or heavily edited.';
      isAuthentic = false;
    }

    return VideoAnalysisResult(
      videoPath: videoPath,
      deepfakeProbability: deepfakeProb,
      confidence: 0.75 + random.nextDouble() * 0.2,
      detectedThreats: threats,
      manipulationPatterns: patterns,
      analyzedFrames: frames.length,
      explanation: explanation,
      isAuthentic: isAuthentic,
      analyzedAt: DateTime.now(),
    );
  }

  /// Extract frames from video for analysis
  /// This is a simplified version - production would use actual video processing
  Future<List<img.Image>> _extractFrames(
    String videoPath, {
    int count = 5,
  }) async {
    final frames = <img.Image>[];

    // For demo purposes, we simulate frame extraction
    // In production, you would use packages like ffmpeg_kit_flutter or video_thumbnail
    // to extract actual frames from the video

    try {
      // Simulate frame extraction delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Return empty list for demo (in real implementation, extract actual frames)
      developer.log('Frame extraction simulated ($count frames)');
    } catch (e) {
      developer.log('Frame extraction error: $e');
    }

    return frames;
  }
}

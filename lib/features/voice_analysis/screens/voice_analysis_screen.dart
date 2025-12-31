import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/voice_analysis_provider.dart';
import '../services/voice_recorder_service.dart';
import '../services/voice_analyzer_service.dart';

class VoiceAnalysisScreen extends StatelessWidget {
  const VoiceAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceAnalysisProvider(),
      child: const _VoiceAnalysisContent(),
    );
  }
}

class _VoiceAnalysisContent extends StatelessWidget {
  const _VoiceAnalysisContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Analysis'), centerTitle: true),
      body: Consumer<VoiceAnalysisProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Info Card
                _buildInfoCard().animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 32),

                // Waveform Visualizer
                _WaveformVisualizer(
                  amplitude: provider.currentAmplitude,
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                const SizedBox(height: 32),

                // Recording Button
                _RecordButton(
                  state: provider.recordingState,
                  isAnalyzing: provider.isAnalyzing,
                  onStart: () => provider.startRecording(),
                  onStop: () => provider.stopAndAnalyze(),
                  onCancel: () => provider.cancelRecording(),
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                const SizedBox(height: 24),

                // Status Text
                _buildStatusText(provider),

                const SizedBox(height: 32),

                // Result Card
                if (provider.lastResult != null)
                  _ResultCard(result: provider.lastResult!)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0),

                // Error Message
                if (provider.errorMessage != null)
                  _buildErrorCard(provider.errorMessage!),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline, color: AppColors.info),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Voice Detection',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap the button to record and analyze a voice for AI-generated characteristics.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText(VoiceAnalysisProvider provider) {
    String text;
    Color color;

    if (provider.isAnalyzing) {
      text = 'Analyzing voice patterns...';
      color = AppColors.info;
    } else {
      switch (provider.recordingState) {
        case RecordingState.recording:
          text = 'Recording... Speak clearly';
          color = AppColors.error;
        case RecordingState.paused:
          text = 'Recording paused';
          color = AppColors.warning;
        case RecordingState.stopped:
          text = 'Recording stopped';
          color = AppColors.success;
        case RecordingState.idle:
          text = 'Tap to start recording';
          color = AppColors.textSecondaryDark;
      }
    }

    return Text(
      text,
      style: AppTypography.bodyMedium.copyWith(color: color),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Waveform visualizer widget
class _WaveformVisualizer extends StatelessWidget {
  final double amplitude;

  const _WaveformVisualizer({required this.amplitude});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        painter: _WaveformPainter(amplitude: amplitude),
        size: const Size(double.infinity, 120),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double amplitude;

  _WaveformPainter({required this.amplitude});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    const barCount = 40;
    final barWidth = size.width / barCount;

    final random = Random(42); // Fixed seed for consistent pattern

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final baseHeight = random.nextDouble() * 0.3 + 0.1;
      final animatedHeight = baseHeight + (amplitude * 0.7);
      final height = (size.height * 0.4) * animatedHeight;

      canvas.drawLine(
        Offset(x, centerY - height),
        Offset(x, centerY + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.amplitude != amplitude;
  }
}

/// Record button widget
class _RecordButton extends StatelessWidget {
  final RecordingState state;
  final bool isAnalyzing;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const _RecordButton({
    required this.state,
    required this.isAnalyzing,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (isAnalyzing) {
      return _buildAnalyzingIndicator();
    }

    final isRecording = state == RecordingState.recording;

    return Column(
      children: [
        GestureDetector(
          onTap: isRecording ? onStop : onStart,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isRecording ? 80 : 100,
            height: isRecording ? 80 : 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isRecording
                    ? [AppColors.error, AppColors.error.withOpacity(0.8)]
                    : [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isRecording ? AppColors.error : AppColors.primary)
                      .withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              isRecording ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: isRecording ? 32 : 40,
            ),
          ),
        ),
        if (isRecording) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalyzingIndicator() {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Analyzing...',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }
}

/// Result card widget
class _ResultCard extends StatelessWidget {
  final VoiceAnalysisResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.isLikelyAI ? AppColors.error : AppColors.success;
    final percentage = (result.syntheticProbability * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  result.isLikelyAI ? Icons.warning_amber : Icons.check_circle,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.isLikelyAI
                          ? 'Possibly AI Voice'
                          : 'Likely Human Voice',
                      style: AppTypography.headlineSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Confidence: ${(result.confidence * 100).toInt()}%',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Probability meter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Synthetic Voice Probability',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: AppTypography.headlineSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: result.syntheticProbability,
                  backgroundColor: AppColors.surfaceDark,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 8,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Explanation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              result.explanation,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ),

          // Detected patterns
          if (result.detectedPatterns.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.detectedPatterns.map((pattern) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    pattern,
                    style: AppTypography.labelSmall.copyWith(color: color),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

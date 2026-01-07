/// Message Analysis Screen - UI for analyzing text messages
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/message_analysis_provider.dart';
import '../services/message_analyzer_service.dart';

class MessageAnalysisScreen extends StatelessWidget {
  const MessageAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MessageAnalysisProvider(),
      child: const _MessageAnalysisContent(),
    );
  }
}

class _MessageAnalysisContent extends StatefulWidget {
  const _MessageAnalysisContent();

  @override
  State<_MessageAnalysisContent> createState() =>
      _MessageAnalysisContentState();
}

class _MessageAnalysisContentState extends State<_MessageAnalysisContent> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            onPressed: _pasteFromClipboard,
            tooltip: 'Paste',
          ),
        ],
      ),
      body: Consumer<MessageAnalysisProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                _buildInfoCard().animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 24),

                // Text Input
                _buildTextInput(
                  provider,
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                const SizedBox(height: 16),

                // Analyze Button
                _buildAnalyzeButton(
                  provider,
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                const SizedBox(height: 24),

                // Result
                if (provider.isAnalyzing) _buildLoadingIndicator(),

                if (provider.lastResult != null && !provider.isAnalyzing)
                  _ResultCard(result: provider.lastResult!)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),

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
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.security, color: AppColors.warning),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phishing & Scam Detection',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paste or type a suspicious message to check for phishing, scams, or fraudulent content.',
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

  Widget _buildTextInput(MessageAnalysisProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _textController,
        maxLines: 6,
        minLines: 4,
        onChanged: provider.setMessage,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        decoration: InputDecoration(
          hintText: 'Paste suspicious message here...',
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.cardDark,
          suffixIcon: _textController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  color: AppColors.textSecondaryDark,
                  onPressed: () {
                    _textController.clear();
                    provider.clearResult();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton(MessageAnalysisProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: provider.isAnalyzing
            ? null
            : () => provider.analyzeMessage(_textController.text),
        icon: Icon(provider.isAnalyzing ? Icons.hourglass_empty : Icons.search),
        label: Text(provider.isAnalyzing ? 'Analyzing...' : 'Analyze Message'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Analyzing message patterns...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
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

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && mounted) {
      _textController.text = data!.text!;
      context.read<MessageAnalysisProvider>().setMessage(data.text!);
    }
  }
}

/// Result card widget
class _ResultCard extends StatelessWidget {
  final MessageAnalysisResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.isSafe
        ? AppColors.success
        : (result.riskScore > 60 ? AppColors.error : AppColors.warning);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    result.riskScore.toString(),
                    style: AppTypography.headlineMedium.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.isSafe
                          ? 'Appears Safe'
                          : (result.riskScore > 60
                                ? 'High Risk Detected!'
                                : 'Suspicious'),
                      style: AppTypography.headlineSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Risk Score: ${result.riskScore}/100',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                result.isSafe
                    ? Icons.verified_user
                    : Icons.warning_amber_rounded,
                color: color,
                size: 32,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Risk meter
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.riskScore / 100,
              backgroundColor: AppColors.surfaceDark,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
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

          // Detected threats
          if (result.detectedThreats.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Detected Threats',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.detectedThreats.map((threat) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(threat.icon),
                      const SizedBox(width: 6),
                      Text(
                        threat.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Suspicious patterns
          if (result.suspiciousPatterns.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Suspicious Patterns Found',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 12),
            ...result.suspiciousPatterns.take(5).map((pattern) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pattern,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (result.suspiciousPatterns.length > 5)
              Text(
                '+ ${result.suspiciousPatterns.length - 5} more patterns',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
          ],

          // Extracted URLs
          if (result.extractedUrls.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'URLs in Message',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 12),
            ...result.extractedUrls.map((url) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        url,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.info,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

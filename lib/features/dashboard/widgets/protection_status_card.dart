/// Protection Status Card widget
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../call_detection/providers/call_history_provider.dart';

class ProtectionStatusCard extends StatelessWidget {
  const ProtectionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallHistoryProvider>(
      builder: (context, provider, _) {
        final isActive = provider.isMonitoring;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive
                  ? [AppColors.primary, AppColors.primaryDark]
                  : [AppColors.cardDark, AppColors.surfaceDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isActive ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive ? Icons.shield : Icons.shield_outlined,
                      color: isActive
                          ? Colors.white
                          : AppColors.textSecondaryDark,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isActive ? 'Protection Active' : 'Protection Off',
                          style: AppTypography.headlineMedium.copyWith(
                            color: isActive
                                ? Colors.white
                                : AppColors.textPrimaryDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isActive
                              ? 'You\'re protected from scams'
                              : 'Enable protection to stay safe',
                          style: AppTypography.bodyMedium.copyWith(
                            color: isActive
                                ? Colors.white.withOpacity(0.8)
                                : AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (isActive) {
                      provider.stopMonitoring();
                    } else {
                      provider.startMonitoring();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive
                        ? Colors.white
                        : AppColors.primary,
                    foregroundColor: isActive
                        ? AppColors.primary
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isActive ? 'Pause Protection' : 'Enable Protection',
                    style: AppTypography.labelLarge,
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      'Calls Analyzed',
                      '${provider.callHistory.length}',
                    ),
                    _buildStat('Threats Blocked', '0'),
                    _buildStat('Risk Score', 'Low'),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

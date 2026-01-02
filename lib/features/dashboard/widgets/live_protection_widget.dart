import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Live protection status widget for dashboard
class LiveProtectionWidget extends StatefulWidget {
  const LiveProtectionWidget({Key? key}) : super(key: key);

  @override
  State<LiveProtectionWidget> createState() => _LiveProtectionWidgetState();
}

class _LiveProtectionWidgetState extends State<LiveProtectionWidget> {
  bool _isProtectionEnabled = true;
  int _threatsBlockedToday = 0;
  int _activeCalls = 0;

  @override
  void initState() {
    super.initState();
    _loadProtectionStatus();
  }

  Future<void> _loadProtectionStatus() async {
    // TODO: Load actual values from service
    setState(() {
      _threatsBlockedToday = 3;
      _activeCalls = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isProtectionEnabled
              ? [AppColors.success, AppColors.success.withOpacity(0.8)]
              : [
                  AppColors.textSecondaryLight,
                  AppColors.textSecondaryLight.withOpacity(0.7),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                (_isProtectionEnabled
                        ? AppColors.success
                        : AppColors.textSecondaryLight)
                    .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status and toggle
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isProtectionEnabled ? 'Protection Active' : 'Protection Off',
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: _isProtectionEnabled,
                onChanged: _toggleProtection,
                activeColor: Colors.white,
                activeTrackColor: Colors.white.withOpacity(0.3),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Statistics
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.security,
                  label: 'Active Calls',
                  value: '$_activeCalls',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.block,
                  label: 'Blocked Today',
                  value: '$_threatsBlockedToday',
                ),
              ),
            ],
          ),

          if (!_isProtectionEnabled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your device is not protected from scam calls',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.statNumber.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleProtection(bool value) {
    setState(() {
      _isProtectionEnabled = value;
    });

    // TODO: Update protection status via MethodChannel

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? 'Protection enabled' : 'Protection disabled'),
        backgroundColor: value ? AppColors.success : AppColors.error,
      ),
    );
  }
}

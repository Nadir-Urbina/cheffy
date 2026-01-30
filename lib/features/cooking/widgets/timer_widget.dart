import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../models/cooking_session.dart';

/// Widget displaying an active cooking timer
class TimerWidget extends StatelessWidget {
  final CookingTimer timer;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;
  final VoidCallback onAddTime;

  const TimerWidget({
    super.key,
    required this.timer,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onDismiss,
    required this.onAddTime,
  });

  @override
  Widget build(BuildContext context) {
    if (timer.isCompleted) {
      return _buildCompletedTimer();
    }
    return _buildActiveTimer();
  }

  Widget _buildActiveTimer() {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: timer.isRunning 
              ? AppColors.primary.withValues(alpha: 0.5)
              : Colors.white24,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Timer display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer,
                color: timer.isRunning ? AppColors.primary : Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                timer.formattedRemaining,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: timer.progress,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 2,
            ),
          ),
          const SizedBox(height: 6),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play/Pause
              _TimerIconButton(
                icon: timer.isRunning ? Icons.pause : Icons.play_arrow,
                onTap: timer.isRunning ? onPause : onResume,
              ),
              const SizedBox(width: 6),
              // Add 1 minute
              _TimerIconButton(
                icon: Icons.add,
                onTap: onAddTime,
              ),
              const SizedBox(width: 6),
              // Cancel
              _TimerIconButton(
                icon: Icons.close,
                onTap: onCancel,
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedTimer() {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.alarm_on,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Done!',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onDismiss();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Dismiss',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _TimerIconButton({
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red.shade300 : Colors.white70,
          size: 14,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../models/cooking_session.dart';
import '../services/timer_service.dart';

/// Card displaying a single cooking step
class StepCard extends StatelessWidget {
  final int stepNumber;
  final String instruction;
  final List<ParsedTime> parsedTimes;
  final Function(ParsedTime) onCreateTimer;
  final VoidCallback onReadAloud;
  final bool isSpeaking;
  final List<CookingTimer> activeTimers;

  const StepCard({
    super.key,
    required this.stepNumber,
    required this.instruction,
    required this.parsedTimes,
    required this.onCreateTimer,
    required this.onReadAloud,
    required this.isSpeaking,
    this.activeTimers = const [],
  });

  /// Check if a timer with similar duration is already running
  bool _isTimerActive(ParsedTime time) {
    return activeTimers.any((t) => 
      !t.isCompleted && 
      (t.totalDuration.inSeconds - time.duration.inSeconds).abs() < 5
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step number badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Step $stepNumber',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Instruction text
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        instruction,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                // Timer buttons (if times detected and not already running)
                if (parsedTimes.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: parsedTimes.map((time) {
                      final isActive = _isTimerActive(time);
                      if (isActive) {
                        return _TimerButtonActive(time: time);
                      }
                      return _TimerButton(
                        time: time,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onCreateTimer(time);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                  // Read aloud button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onReadAloud,
                      icon: Icon(
                        isSpeaking ? Icons.stop : Icons.volume_up,
                        size: 20,
                      ),
                      label: Text(isSpeaking ? 'Stop Reading' : 'Read Aloud'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerButton extends StatelessWidget {
  final ParsedTime time;
  final VoidCallback onTap;

  const _TimerButton({
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Start ${time.formattedDuration} timer',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows when a timer is already running
class _TimerButtonActive extends StatelessWidget {
  final ParsedTime time;

  const _TimerButtonActive({required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Text(
            '${time.formattedDuration} timer running',
            style: GoogleFonts.poppins(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

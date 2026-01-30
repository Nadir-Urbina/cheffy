import '../../../core/models/recipe_model.dart';

/// Represents an active cooking session
class CookingSession {
  final Recipe recipe;
  final int currentStepIndex;
  final List<bool> completedSteps;
  final List<CookingTimer> activeTimers;
  final DateTime startedAt;

  CookingSession({
    required this.recipe,
    this.currentStepIndex = 0,
    List<bool>? completedSteps,
    this.activeTimers = const [],
    DateTime? startedAt,
  })  : completedSteps = completedSteps ?? 
            List.filled(recipe.instructions.length, false),
        startedAt = startedAt ?? DateTime.now();

  int get totalSteps => recipe.instructions.length;
  
  bool get isFirstStep => currentStepIndex == 0;
  
  bool get isLastStep => currentStepIndex >= totalSteps - 1;
  
  String get currentInstruction => 
      recipe.instructions.isNotEmpty && currentStepIndex < recipe.instructions.length
          ? recipe.instructions[currentStepIndex]
          : '';

  double get progress => totalSteps > 0 
      ? (currentStepIndex + 1) / totalSteps 
      : 0;

  CookingSession copyWith({
    Recipe? recipe,
    int? currentStepIndex,
    List<bool>? completedSteps,
    List<CookingTimer>? activeTimers,
    DateTime? startedAt,
  }) {
    return CookingSession(
      recipe: recipe ?? this.recipe,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      completedSteps: completedSteps ?? List.from(this.completedSteps),
      activeTimers: activeTimers ?? this.activeTimers,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  /// Move to next step
  CookingSession nextStep() {
    if (isLastStep) return this;
    final newCompleted = List<bool>.from(completedSteps);
    newCompleted[currentStepIndex] = true;
    return copyWith(
      currentStepIndex: currentStepIndex + 1,
      completedSteps: newCompleted,
    );
  }

  /// Move to previous step
  CookingSession previousStep() {
    if (isFirstStep) return this;
    return copyWith(currentStepIndex: currentStepIndex - 1);
  }

  /// Jump to specific step
  CookingSession goToStep(int index) {
    if (index < 0 || index >= totalSteps) return this;
    return copyWith(currentStepIndex: index);
  }
}

/// Represents a cooking timer
class CookingTimer {
  final String id;
  final String label;
  final Duration totalDuration;
  final Duration remainingDuration;
  final bool isRunning;
  final bool isCompleted;
  final int? stepIndex; // Which step this timer is associated with

  const CookingTimer({
    required this.id,
    required this.label,
    required this.totalDuration,
    required this.remainingDuration,
    this.isRunning = false,
    this.isCompleted = false,
    this.stepIndex,
  });

  double get progress => totalDuration.inSeconds > 0
      ? 1 - (remainingDuration.inSeconds / totalDuration.inSeconds)
      : 0;

  String get formattedRemaining {
    final minutes = remainingDuration.inMinutes;
    final seconds = remainingDuration.inSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  CookingTimer copyWith({
    String? id,
    String? label,
    Duration? totalDuration,
    Duration? remainingDuration,
    bool? isRunning,
    bool? isCompleted,
    int? stepIndex,
  }) {
    return CookingTimer(
      id: id ?? this.id,
      label: label ?? this.label,
      totalDuration: totalDuration ?? this.totalDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      isRunning: isRunning ?? this.isRunning,
      isCompleted: isCompleted ?? this.isCompleted,
      stepIndex: stepIndex ?? this.stepIndex,
    );
  }

  CookingTimer tick() {
    if (!isRunning || isCompleted) return this;
    final newRemaining = remainingDuration - const Duration(seconds: 1);
    if (newRemaining.inSeconds <= 0) {
      return copyWith(
        remainingDuration: Duration.zero,
        isRunning: false,
        isCompleted: true,
      );
    }
    return copyWith(remainingDuration: newRemaining);
  }
}

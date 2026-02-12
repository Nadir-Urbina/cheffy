import 'dart:async';
import 'package:flutter/services.dart';
import '../models/cooking_session.dart';

/// Service for managing cooking timers
class TimerService {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  Timer? _tickTimer;
  
  final _timersController = StreamController<List<CookingTimer>>.broadcast();
  Stream<List<CookingTimer>> get timersStream => _timersController.stream;
  
  List<CookingTimer> _timers = [];
  List<CookingTimer> get timers => List.unmodifiable(_timers);

  /// Start the tick timer if not already running
  void _ensureTickTimer() {
    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Stop the tick timer if no timers are running
  void _checkStopTickTimer() {
    if (!_timers.any((t) => t.isRunning)) {
      _tickTimer?.cancel();
      _tickTimer = null;
    }
  }

  /// Process one tick for all timers
  void _tick() {
    bool anyCompleted = false;
    _timers = _timers.map((timer) {
      if (!timer.isRunning || timer.isCompleted) return timer;
      final updated = timer.tick();
      if (updated.isCompleted && !timer.isCompleted) {
        anyCompleted = true;
      }
      return updated;
    }).toList();
    
    _timersController.add(_timers);
    
    if (anyCompleted) {
      _onTimerComplete();
    }
    
    _checkStopTickTimer();
  }

  /// Called when a timer completes
  Future<void> _onTimerComplete() async {
    // Strong haptic pattern to alert the user
    HapticFeedback.heavyImpact();
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      HapticFeedback.heavyImpact();
    }
  }

  /// Create a new timer
  CookingTimer createTimer({
    required Duration duration,
    required String label,
    int? stepIndex,
    bool autoStart = true,
  }) {
    final timer = CookingTimer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      totalDuration: duration,
      remainingDuration: duration,
      isRunning: autoStart,
      stepIndex: stepIndex,
    );
    
    _timers.add(timer);
    _timersController.add(_timers);
    
    if (autoStart) {
      _ensureTickTimer();
    }
    
    return timer;
  }

  /// Start a timer
  void startTimer(String timerId) {
    _timers = _timers.map((t) {
      if (t.id == timerId && !t.isCompleted) {
        return t.copyWith(isRunning: true);
      }
      return t;
    }).toList();
    _timersController.add(_timers);
    _ensureTickTimer();
  }

  /// Pause a timer
  void pauseTimer(String timerId) {
    _timers = _timers.map((t) {
      if (t.id == timerId) {
        return t.copyWith(isRunning: false);
      }
      return t;
    }).toList();
    _timersController.add(_timers);
    _checkStopTickTimer();
  }

  /// Cancel/remove a timer
  void cancelTimer(String timerId) {
    _timers.removeWhere((t) => t.id == timerId);
    _timersController.add(_timers);
    _checkStopTickTimer();
  }

  /// Reset a timer to its original duration
  void resetTimer(String timerId) {
    _timers = _timers.map((t) {
      if (t.id == timerId) {
        return t.copyWith(
          remainingDuration: t.totalDuration,
          isRunning: false,
          isCompleted: false,
        );
      }
      return t;
    }).toList();
    _timersController.add(_timers);
  }

  /// Add extra time to a timer
  void addTime(String timerId, Duration extra) {
    _timers = _timers.map((t) {
      if (t.id == timerId) {
        return t.copyWith(
          remainingDuration: t.remainingDuration + extra,
          isCompleted: false,
        );
      }
      return t;
    }).toList();
    _timersController.add(_timers);
  }

  /// Clear all timers
  void clearAllTimers() {
    _timers.clear();
    _timersController.add(_timers);
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  /// Dismiss completed timer notification
  void dismissCompletedTimer(String timerId) {
    _timers.removeWhere((t) => t.id == timerId && t.isCompleted);
    _timersController.add(_timers);
  }

  /// Parse time durations from text
  /// Returns list of (duration, label) pairs found in text
  static List<ParsedTime> parseTimesFromText(String text) {
    final results = <ParsedTime>[];
    
    // Patterns to match various time formats
    final patterns = [
      // "25 minutes", "25 mins", "25 min", "25-30 minutes"
      RegExp(r'(\d+)(?:\s*-\s*\d+)?\s*(?:minutes?|mins?|min)\b', caseSensitive: false),
      // "1 hour", "2 hours", "1-2 hours"
      RegExp(r'(\d+)(?:\s*-\s*\d+)?\s*(?:hours?|hrs?|hr)\b', caseSensitive: false),
      // "30 seconds", "30 secs", "30 sec"
      RegExp(r'(\d+)(?:\s*-\s*\d+)?\s*(?:seconds?|secs?|sec)\b', caseSensitive: false),
      // "1 hour 30 minutes" or "1h 30m"
      RegExp(r'(\d+)\s*(?:hours?|hrs?|h)\s*(?:and\s*)?(\d+)\s*(?:minutes?|mins?|m)\b', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        Duration? duration;
        String label = match.group(0) ?? '';
        
        if (pattern.pattern.contains('hours?|hrs?|h') && pattern.pattern.contains('minutes?|mins?|m')) {
          // Combined hours and minutes
          final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
          final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
          duration = Duration(hours: hours, minutes: minutes);
        } else if (pattern.pattern.contains('hours?|hrs?|hr')) {
          final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
          duration = Duration(hours: hours);
        } else if (pattern.pattern.contains('minutes?|mins?|min')) {
          final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
          duration = Duration(minutes: minutes);
        } else if (pattern.pattern.contains('seconds?|secs?|sec')) {
          final seconds = int.tryParse(match.group(1) ?? '0') ?? 0;
          duration = Duration(seconds: seconds);
        }

        if (duration != null && duration.inSeconds > 0) {
          // Avoid duplicates
          if (!results.any((r) => r.duration == duration)) {
            results.add(ParsedTime(duration: duration, label: label));
          }
        }
      }
    }

    return results;
  }

  void dispose() {
    _tickTimer?.cancel();
    _timersController.close();
  }
}

/// Represents a parsed time from instruction text
class ParsedTime {
  final Duration duration;
  final String label;

  const ParsedTime({required this.duration, required this.label});

  String get formattedDuration {
    if (duration.inHours > 0) {
      final mins = duration.inMinutes % 60;
      return mins > 0 
          ? '${duration.inHours}h ${mins}m'
          : '${duration.inHours}h';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes} min';
    }
    return '${duration.inSeconds} sec';
  }
}

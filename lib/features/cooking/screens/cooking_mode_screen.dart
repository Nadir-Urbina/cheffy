import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/models/recipe_model.dart';
import '../../../core/services/recipe_history_service.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/cooking_session.dart';
import '../services/ingredient_query_service.dart';
import '../services/timer_service.dart';
import '../widgets/ingredients_drawer.dart';
import '../widgets/step_card.dart';
import '../widgets/timer_widget.dart';

/// Full-screen cooking mode with step-by-step guidance
class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;

  const CookingModeScreen({super.key, required this.recipe});

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> 
    with TickerProviderStateMixin {
  late CookingSession _session;
  late IngredientQueryService _queryService;
  final TimerService _timerService = TimerService();
  final VoiceService _voiceService = VoiceService();
  final RecipeHistoryService _historyService = RecipeHistoryService();
  
  final PageController _pageController = PageController();
  
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _conversationalMode = false;
  bool _quickCommandExecuted = false;
  
  StreamSubscription<List<CookingTimer>>? _timerSubscription;
  List<CookingTimer> _activeTimers = [];

  @override
  void initState() {
    super.initState();
    _session = CookingSession(recipe: widget.recipe);
    _queryService = IngredientQueryService(widget.recipe);
    
    // Keep screen awake while cooking
    WakelockPlus.enable();
    
    // Initialize voice service
    _initVoiceService();
    
    // Listen to timer updates
    _timerSubscription = _timerService.timersStream.listen((timers) {
      if (mounted) {
        setState(() => _activeTimers = timers);
        
        // Check for completed timers and announce
        for (final timer in timers) {
          if (timer.isCompleted) {
            _announceTimerComplete(timer);
          }
        }
      }
    });
  }

  Future<void> _initVoiceService() async {
    await _voiceService.initialize();
  }

  @override
  void dispose() {
    _voiceService.stop();
    _voiceService.stopListening();
    WakelockPlus.disable();
    _timerSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int index) {
    if (index < 0 || index >= _session.totalSteps) return;
    
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _session = _session.goToStep(index);
    });
  }

  void _nextStep() {
    if (_session.isLastStep) return;
    _goToStep(_session.currentStepIndex + 1);
  }

  void _previousStep() {
    if (_session.isFirstStep) return;
    _goToStep(_session.currentStepIndex - 1);
  }

  Future<void> _readCurrentStep() async {
    if (_isSpeaking) {
      await _voiceService.stop();
      setState(() => _isSpeaking = false);
      return;
    }
    
    // Delegate to conversational cycle if active
    if (_conversationalMode) {
      _readCurrentStepConversational();
      return;
    }
    
    setState(() => _isSpeaking = true);
    
    final stepText = "Step ${_session.currentStepIndex + 1}. ${_session.currentInstruction}";
    await _voiceService.speak(stepText);
    
    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  // ==================== CONVERSATIONAL MODE ====================

  /// Toggle conversational mode on/off.
  /// When ON: reads the current step aloud, then listens for commands,
  /// creating a continuous read → listen → act → read cycle.
  void _toggleConversationalMode() {
    HapticFeedback.mediumImpact();
    final enabling = !_conversationalMode;

    setState(() {
      _conversationalMode = enabling;
    });

    if (enabling) {
      // Kick off the read → listen cycle
      _readCurrentStepConversational();
    } else {
      // Stop everything cleanly
      _voiceService.stop();
      _voiceService.stopListening();
      setState(() {
        _isSpeaking = false;
        _isListening = false;
      });
    }
  }

  /// Read the current step aloud, then start listening when done.
  Future<void> _readCurrentStepConversational() async {
    if (!_conversationalMode || !mounted) return;

    // Stop any current speech/listening for a clean start
    if (_isListening) await _voiceService.stopListening();
    if (_isSpeaking) await _voiceService.stop();

    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });

    final stepText = "Step ${_session.currentStepIndex + 1}. ${_session.currentInstruction}";
    await _voiceService.speak(stepText);

    if (mounted) {
      setState(() => _isSpeaking = false);
      // Brief pause so the mic doesn't pick up speaker echo
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && _conversationalMode) {
        _startListeningConversational();
      }
    }
  }

  /// Start listening with quick command matching on partial results.
  Future<void> _startListeningConversational() async {
    if (!_voiceService.isSttAvailable || !_conversationalMode || !mounted) return;

    _quickCommandExecuted = false;
    setState(() => _isListening = true);

    // Partial results → instant command matching
    _voiceService.onPartialSpeechResult = (text) {
      if (_quickCommandExecuted) return;
      final command = _matchQuickCommand(text);
      if (command != null) {
        _quickCommandExecuted = true;
        // Detach callbacks to prevent interference, then cancel
        _voiceService.onSpeechEnd = null;
        _voiceService.onSpeechResult = null;
        _voiceService.cancelListening();
        if (mounted) {
          setState(() => _isListening = false);
          _executeQuickCommand(command);
        }
      }
    };

    // Final result fallback (if no partial matched a command)
    _voiceService.onSpeechResult = (text) {
      if (_quickCommandExecuted) return;
      // Try matching the final result too
      final command = _matchQuickCommand(text);
      if (command != null) {
        _quickCommandExecuted = true;
        if (mounted) {
          setState(() => _isListening = false);
          _executeQuickCommand(command);
        }
      } else {
        // Unrecognized — just restart listening
        if (mounted) {
          setState(() => _isListening = false);
          _restartListeningAfterDelay();
        }
      }
    };

    _voiceService.onError = (error) {
      if (mounted && !_quickCommandExecuted) {
        setState(() => _isListening = false);
        // Longer delay on errors (e.g. silence/no-match) to avoid rapid cycling
        if (_conversationalMode) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted && _conversationalMode && !_isSpeaking && !_isListening) {
              _startListeningConversational();
            }
          });
        }
      }
    };

    _voiceService.onSpeechEnd = () {
      if (mounted && !_quickCommandExecuted) {
        setState(() => _isListening = false);
        _restartListeningAfterDelay();
      }
    };

    await _voiceService.startListeningForCommands();
  }

  /// Speak a response, then restart listening if in conversational mode.
  Future<void> _speakAndContinue(String text) async {
    if (_isListening) await _voiceService.stopListening();
    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });
    await _voiceService.speak(text);
    if (mounted) {
      setState(() => _isSpeaking = false);
      _restartListeningAfterDelay();
    }
  }

  /// Restart listening after a brief delay (conversational mode only).
  void _restartListeningAfterDelay() {
    if (!_conversationalMode || !mounted) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _conversationalMode && !_isSpeaking && !_isListening) {
        _startListeningConversational();
      }
    });
  }

  /// Check if recognized text matches a known quick voice command.
  /// Returns the command name or null if no match.
  String? _matchQuickCommand(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return null;

    // Next: "next", "next step", "keep going", "continue"
    if (lower.contains('next') || lower.contains('keep going') || lower == 'continue') {
      return 'next';
    }
    // Back: "back", "go back", "previous"
    if (lower.contains('back') || lower.contains('previous')) {
      return 'back';
    }
    // Stop: "stop", "pause", "turn off"
    if (lower.contains('stop') || lower.contains('pause') || lower.contains('turn off')) {
      return 'stop';
    }
    // Repeat: "repeat", "read again", "read it"
    if (lower.contains('repeat') || lower.contains('read')) {
      return 'repeat';
    }
    // Finish: "finish", "done", "i'm done"
    if (lower.contains('finish') || lower.contains('done')) {
      return 'finish';
    }

    return null;
  }

  /// Execute a matched quick command immediately.
  void _executeQuickCommand(String command) {
    switch (command) {
      case 'next':
        if (_session.isLastStep) {
          _speakAndContinue("You're on the last step. Say 'finish' when you're done!");
        } else {
          _nextStep(); // onPageChanged handles the conversational cycle
        }
        break;
      case 'back':
        if (!_session.isFirstStep) {
          _previousStep(); // onPageChanged handles the conversational cycle
        } else {
          _restartListeningAfterDelay();
        }
        break;
      case 'stop':
        _toggleConversationalMode();
        break;
      case 'repeat':
        _readCurrentStepConversational();
        break;
      case 'finish':
        if (_session.isLastStep) {
          _toggleConversationalMode();
          _finishCooking();
        } else {
          _restartListeningAfterDelay();
        }
        break;
      default:
        _restartListeningAfterDelay();
    }
  }

  void _createTimer(ParsedTime time) {
    HapticFeedback.mediumImpact();
    _timerService.createTimer(
      duration: time.duration,
      label: time.label,
      stepIndex: _session.currentStepIndex,
    );
  }

  void _announceTimerComplete(CookingTimer timer) async {
    if (_conversationalMode) {
      // Use speakAndContinue to resume listening after announcement
      await _speakAndContinue("Timer complete! ${timer.label}");
    } else {
      await _voiceService.speak("Timer complete! ${timer.label}");
    }
  }

  void _showIngredientsDrawer() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IngredientsDrawer(
        ingredients: widget.recipe.ingredients,
        onIngredientTap: (ingredient) {
          Navigator.pop(context);
          _voiceService.speak(_queryService.answerQuery(ingredient.name) ?? ingredient.formatted);
        },
      ),
    );
  }

  void _confirmExit() {
    HapticFeedback.mediumImpact();
    // Pause conversational mode while dialog is shown
    if (_conversationalMode) {
      _voiceService.stop();
      _voiceService.stopListening();
      setState(() {
        _isSpeaking = false;
        _isListening = false;
      });
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Exit Cooking Mode?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          _activeTimers.isNotEmpty
              ? 'You have active timers running. Are you sure you want to exit?'
              : 'Your progress will be lost. Are you sure?',
          style: GoogleFonts.poppins(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Resume conversational mode if it was active
              if (_conversationalMode) {
                _restartListeningAfterDelay();
              }
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_conversationalMode) _toggleConversationalMode();
              _timerService.clearAllTimers();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit cooking mode
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Exit', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _finishCooking() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _FinishCookingDialog(
        recipeName: widget.recipe.name,
        onFinish: (rating) async {
          // Save to history
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await _historyService.saveToHistory(
              odUserId: user.uid,
              recipe: widget.recipe,
              rating: rating,
            );
          }
          
          _timerService.clearAllTimers();
          if (mounted) {
            Navigator.pop(dialogContext); // Close dialog
            Navigator.pop(context); // Exit cooking mode
          }
        },
        onSkip: () {
          _timerService.clearAllTimers();
          Navigator.pop(dialogContext); // Close dialog
          Navigator.pop(context); // Exit cooking mode
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildProgressBar(),
                Expanded(child: _buildStepContent()),
                if (_activeTimers.isNotEmpty) _buildTimersBar(),
                if (_conversationalMode) _buildConversationalIndicator(),
                _buildBottomControls(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _confirmExit,
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipe.name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Step ${_session.currentStepIndex + 1} of ${_session.totalSteps}',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showIngredientsDrawer,
            icon: const Icon(Icons.list_alt, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
            tooltip: 'View Ingredients',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_session.totalSteps, (index) {
          final isCompleted = index < _session.currentStepIndex;
          final isCurrent = index == _session.currentStepIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => _goToStep(index),
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.primary
                      : isCurrent
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _session.totalSteps,
      onPageChanged: (index) {
        // Stop any active TTS/STT on step transition
        if (_isSpeaking) _voiceService.stop();
        if (_isListening) _voiceService.stopListening();

        setState(() {
          _session = _session.goToStep(index);
          _isSpeaking = false;
          _isListening = false;
        });

        // In conversational mode, read the new step after animation settles
        if (_conversationalMode) {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted && _conversationalMode) {
              _readCurrentStepConversational();
            }
          });
        }
      },
      itemBuilder: (context, index) {
        final instruction = widget.recipe.instructions[index];
        final parsedTimes = TimerService.parseTimesFromText(instruction);
        
        return StepCard(
          stepNumber: index + 1,
          instruction: instruction,
          parsedTimes: parsedTimes,
          onCreateTimer: _createTimer,
          onReadAloud: _readCurrentStep,
          isSpeaking: _isSpeaking,
          activeTimers: _activeTimers,
        );
      },
    );
  }

  Widget _buildTimersBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _activeTimers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final timer = _activeTimers[index];
          return TimerWidget(
            timer: timer,
            onPause: () => _timerService.pauseTimer(timer.id),
            onResume: () => _timerService.startTimer(timer.id),
            onCancel: () => _timerService.cancelTimer(timer.id),
            onDismiss: () => _timerService.dismissCompletedTimer(timer.id),
            onAddTime: () => _timerService.addTime(timer.id, const Duration(minutes: 1)),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Previous button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _session.isFirstStep ? null : _previousStep,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: _session.isFirstStep ? Colors.white24 : Colors.white54,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledForegroundColor: Colors.white24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Conversational mode toggle
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _conversationalMode
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: _conversationalMode ? 0.6 : 0.3,
                  ),
                  blurRadius: _conversationalMode ? 24 : 12,
                  spreadRadius: _conversationalMode ? 6 : 2,
                ),
                if (_conversationalMode)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
              ],
            ),
            child: IconButton(
              onPressed: _toggleConversationalMode,
              icon: Icon(
                _conversationalMode
                    ? Icons.record_voice_over
                    : Icons.mic_none,
                color: Colors.white,
                size: 28,
              ),
              padding: const EdgeInsets.all(16),
              tooltip: _conversationalMode
                  ? 'Stop Conversational Mode'
                  : 'Conversational Mode',
            ),
          ),
          const SizedBox(width: 12),
          // Next/Finish button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _session.isLastStep ? _finishCooking : _nextStep,
              icon: Icon(_session.isLastStep ? Icons.check : Icons.arrow_forward),
              label: Text(_session.isLastStep ? 'Finish' : 'Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationalIndicator() {
    String statusText;
    IconData statusIcon;

    if (_isSpeaking) {
      statusText = 'Reading step aloud...';
      statusIcon = Icons.volume_up;
    } else if (_isListening) {
      statusText = 'Listening... say "next", "back", or "stop"';
      statusIcon = Icons.mic;
    } else {
      statusText = 'Conversational Mode';
      statusIcon = Icons.record_voice_over;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, color: AppColors.primary, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                statusText,
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _toggleConversationalMode,
              child: Text(
                'Stop',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Dialog shown when finishing cooking
class _FinishCookingDialog extends StatefulWidget {
  final String recipeName;
  final Function(int?) onFinish;
  final VoidCallback onSkip;

  const _FinishCookingDialog({
    required this.recipeName,
    required this.onFinish,
    required this.onSkip,
  });

  @override
  State<_FinishCookingDialog> createState() => _FinishCookingDialogState();
}

class _FinishCookingDialogState extends State<_FinishCookingDialog> {
  int? _rating;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Celebration icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Text('🎉', style: TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 16),
          Text(
            'Well Done!',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve completed',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            widget.recipeName,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          // Rating section
          Text(
            'How did it turn out?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final isSelected = _rating != null && starValue <= _rating!;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _rating = starValue);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 36,
                    color: isSelected ? Colors.amber : AppColors.textHint,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _rating == null 
                ? 'Tap to rate (optional)'
                : _getRatingText(_rating!),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _rating == null ? AppColors.textHint : AppColors.primary,
              fontWeight: _rating == null ? FontWeight.normal : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () async {
                setState(() => _isSaving = true);
                await widget.onFinish(_rating);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      'Save to My Recipes',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSaving ? null : widget.onSkip,
            child: Text(
              'Skip',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1: return 'Not great';
      case 2: return 'Could be better';
      case 3: return 'Pretty good';
      case 4: return 'Really good!';
      case 5: return 'Amazing! 🌟';
      default: return '';
    }
  }
}

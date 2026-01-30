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
  String? _voiceQuery;
  String? _voiceResponse;
  bool _showVoiceOverlay = false;
  
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
    
    setState(() => _isSpeaking = true);
    
    final stepText = "Step ${_session.currentStepIndex + 1}. ${_session.currentInstruction}";
    await _voiceService.speak(stepText);
    
    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  Future<void> _startListening() async {
    if (!_voiceService.isSttAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Voice input not available'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    
    HapticFeedback.mediumImpact();
    setState(() {
      _isListening = true;
      _showVoiceOverlay = true;
      _voiceQuery = null;
      _voiceResponse = null;
    });
    
    // Set up callbacks before starting
    _voiceService.onSpeechResult = (text) {
      _handleVoiceResult(text);
    };
    _voiceService.onError = (error) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _voiceResponse = "I didn't catch that. Try again.";
        });
      }
    };
    _voiceService.onSpeechEnd = () {
      if (mounted) {
        setState(() => _isListening = false);
      }
    };
    
    await _voiceService.startListening();
  }

  void _stopListening() {
    _voiceService.stopListening();
    setState(() => _isListening = false);
  }

  Future<void> _handleVoiceResult(String text) async {
    setState(() {
      _isListening = false;
      _voiceQuery = text;
    });
    
    // Check for navigation commands
    final lowerText = text.toLowerCase();
    
    if (lowerText.contains('next step') || lowerText.contains('next')) {
      _nextStep();
      setState(() {
        _voiceResponse = "Moving to next step";
        _showVoiceOverlay = false;
      });
      return;
    }
    
    if (lowerText.contains('previous step') || lowerText.contains('go back') || lowerText.contains('back')) {
      _previousStep();
      setState(() {
        _voiceResponse = "Going back";
        _showVoiceOverlay = false;
      });
      return;
    }
    
    if (lowerText.contains('read') || lowerText.contains('repeat')) {
      setState(() => _showVoiceOverlay = false);
      _readCurrentStep();
      return;
    }
    
    // Check for timer commands
    if (lowerText.contains('start timer') || lowerText.contains('set timer')) {
      final times = TimerService.parseTimesFromText(_session.currentInstruction);
      if (times.isNotEmpty) {
        _createTimer(times.first);
        setState(() {
          _voiceResponse = "Starting ${times.first.formattedDuration} timer";
        });
        await _voiceService.speak("Timer started for ${times.first.formattedDuration}");
      } else {
        setState(() {
          _voiceResponse = "No timer found in this step";
        });
      }
      _dismissVoiceOverlayDelayed();
      return;
    }
    
    // Try to answer ingredient question
    final answer = _queryService.answerQuery(text);
    if (answer != null) {
      setState(() => _voiceResponse = answer);
      await _voiceService.speak(answer);
      _dismissVoiceOverlayDelayed();
      return;
    }
    
    // Unknown query
    setState(() {
      _voiceResponse = "I'm not sure about that. Try asking about an ingredient.";
    });
    _dismissVoiceOverlayDelayed();
  }

  void _dismissVoiceOverlayDelayed() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showVoiceOverlay) {
        setState(() => _showVoiceOverlay = false);
      }
    });
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
    await _voiceService.speak("Timer complete! ${timer.label}");
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
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
                _buildBottomControls(),
              ],
            ),
            if (_showVoiceOverlay) _buildVoiceOverlay(),
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
        setState(() {
          _session = _session.goToStep(index);
        });
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
          // Voice/Ask button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              onPressed: _isListening ? _stopListening : _startListening,
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 28,
              ),
              padding: const EdgeInsets.all(16),
              tooltip: 'Ask Chefsito',
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

  Widget _buildVoiceOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Listening indicator
              if (_isListening) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic,
                    color: AppColors.primary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Listening...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask about ingredients or say "next step"',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              // Query result
              if (!_isListening && _voiceQuery != null) ...[
                Icon(
                  Icons.format_quote,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  '"$_voiceQuery"',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_voiceResponse != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _voiceResponse!,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => _showVoiceOverlay = false),
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.poppins(color: Colors.white70),
                ),
              ),
            ],
          ),
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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/user_preferences.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cheffy_orb.dart';
import '../../scan/screens/recipe_results_screen.dart' show RecipeResultsScreen, StringExtension;

class ChatIngredientsScreen extends StatefulWidget {
  const ChatIngredientsScreen({super.key});

  @override
  State<ChatIngredientsScreen> createState() => _ChatIngredientsScreenState();
}

class _ChatIngredientsScreenState extends State<ChatIngredientsScreen> 
    with SingleTickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _aiService = AIService();
  final _preferencesService = PreferencesService();
  final _voiceService = VoiceService();
  
  final List<_ChatMessage> _messages = [];
  final List<String> _ingredients = [];
  
  bool _isTyping = false;
  bool _isSearching = false;
  bool _isListening = false;
  bool _readAloudEnabled = true; // TTS toggle
  
  // Animation for mic button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initVoice();
    _initAnimations();
    _addCheffyGreeting();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  Future<void> _initVoice() async {
    await _voiceService.initialize();
    
    _voiceService.onSpeechResult = (text) {
      if (text.isNotEmpty) {
        _messageController.text = text;
        // Auto-send after speech recognition completes
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _messageController.text.isNotEmpty) {
            _sendMessage();
          }
        });
      }
    };
    
    _voiceService.onSpeechStart = () {
      if (mounted) setState(() => _isListening = true);
    };
    
    _voiceService.onSpeechEnd = () {
      if (mounted) setState(() => _isListening = false);
    };
    
    _voiceService.onTtsComplete = () {
      // TTS finished speaking
    };
    
    _voiceService.onError = (error) {
      if (mounted) {
        setState(() => _isListening = false);
        _showSnackBar(error);
      }
    };
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _voiceService.stop();
    _voiceService.stopListening();
    super.dispose();
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Add a Cheffy message and optionally speak it
  void _addCheffyMessage(String text, {bool speak = true}) {
    _messages.add(_ChatMessage(text: text, isUser: false));
    
    if (speak && _readAloudEnabled) {
      // Remove emojis for cleaner TTS
      final cleanText = text.replaceAll(RegExp(r'[^\x00-\x7F]+'), '').trim();
      if (cleanText.isNotEmpty) {
        _voiceService.speak(cleanText);
      }
    }
  }

  /// Toggle voice input
  Future<void> _toggleVoiceInput() async {
    HapticFeedback.mediumImpact();
    
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
    } else {
      // Stop TTS if speaking
      await _voiceService.stop();
      
      setState(() => _isListening = true);
      await _voiceService.startListening(
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  /// Toggle read aloud
  void _toggleReadAloud() {
    HapticFeedback.selectionClick();
    setState(() {
      _readAloudEnabled = !_readAloudEnabled;
      if (!_readAloudEnabled) {
        _voiceService.stop();
      }
    });
    _showSnackBar(_readAloudEnabled 
        ? '🔊 Read aloud enabled' 
        : '🔇 Read aloud disabled');
  }

  void _addCheffyGreeting() {
    _messages.add(_ChatMessage(
      text: "Hey there! 👋 I'm Cheffy, your cooking buddy!",
      isUser: false,
    ));
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: "Tell me what ingredients you have, and I'll find delicious recipes for you! 🍳\n\nJust type them one by one or list them all at once.",
            isUser: false,
          ));
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messageController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    // Parse ingredients from message
    _parseIngredients(text);
  }

  void _parseIngredients(String text) {
    // Split by common delimiters
    final newIngredients = text
        .split(RegExp(r'[,\n;]|and|&'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty && s.length > 1)
        .toList();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      setState(() {
        _isTyping = false;
        
        if (newIngredients.isEmpty) {
          _addCheffyMessage(
            "Hmm, I didn't quite catch that. Could you tell me what ingredients you have? For example: \"chicken, rice, tomatoes\" 🤔"
          );
        } else {
          // Add new ingredients (avoid duplicates)
          for (final ing in newIngredients) {
            if (!_ingredients.contains(ing)) {
              _ingredients.add(ing);
            }
          }

          // Respond with acknowledgment
          final response = _getCheffyResponse(newIngredients);
          _addCheffyMessage(response);
        }
      });
      _scrollToBottom();
    });
  }

  String _getCheffyResponse(List<String> newIngredients) {
    final total = _ingredients.length;
    
    if (newIngredients.length == 1) {
      final responses = [
        "Got it! ${newIngredients.first.capitalize()} added! 📝 What else do you have?",
        "Nice! ${newIngredients.first.capitalize()} is on the list! Anything else? 🍴",
        "Perfect! Added ${newIngredients.first}! Keep 'em coming! 😊",
      ];
      return responses[total % responses.length];
    } else {
      final responses = [
        "Awesome! I've added ${newIngredients.length} ingredients! 🎉 You now have $total items. Anything else?",
        "Great haul! ${newIngredients.length} more ingredients added! That's $total total. What else? 🛒",
        "Love it! Got ${newIngredients.length} new items! Keep going or tap 'Find Recipes' when ready! 👨‍🍳",
      ];
      return responses[total % responses.length];
    }
  }

  Future<void> _findRecipes() async {
    // Stop listening if active
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
    }
    
    if (_ingredients.isEmpty) {
      setState(() {
        _addCheffyMessage(
          "Oops! You haven't told me any ingredients yet. What do you have in your kitchen? 🏠"
        );
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _isSearching = true;
      _messages.add(_ChatMessage(
        text: "Finding recipes...",
        isUser: true,
        isAction: true,
      ));
      _addCheffyMessage(
        "Let me search for the best recipes with your ${_ingredients.length} ingredients... 🔍✨"
      );
    });
    _scrollToBottom();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Please sign in');

      UserPreferences? preferences = await _preferencesService.getPreferences(user.uid);
      preferences ??= UserPreferences.newUser(user.uid);

      final result = await _aiService.suggestRecipes(
        availableIngredients: _ingredients,
        preferences: preferences,
        numberOfRecipes: 3,
      );

      setState(() => _isSearching = false);

      if (mounted) {
        if (result.hasRecipes) {
          // Announce before navigating
          if (_readAloudEnabled) {
            _voiceService.speak("I found ${result.recipes.length} delicious recipes for you!");
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeResultsScreen(result: result),
            ),
          );
        } else {
          setState(() {
            _addCheffyMessage(
              "Hmm, I couldn't find any recipes with those ingredients. Try adding a few more! 🤷‍♂️"
            );
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _addCheffyMessage(
          "Oops! Something went wrong: ${e.toString()} 😅"
        );
      });
      _scrollToBottom();
    }
  }

  void _clearIngredients() {
    setState(() {
      _ingredients.clear();
      _messages.add(_ChatMessage(
        text: "Clear list",
        isUser: true,
        isAction: true,
      ));
      _addCheffyMessage(
        "All cleared! 🧹 Let's start fresh. What ingredients do you have?"
      );
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Container(
        decoration: AppColors.freshGradientDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // Ingredients summary chip
              if (_ingredients.isNotEmpty) _buildIngredientsSummary(),
              // Chat messages
              Expanded(child: _buildChatList()),
              // Input area
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText() {
    if (_isListening) return 'Listening... 🎤';
    if (_isTyping) return 'typing...';
    if (_voiceService.isSpeaking) return 'Speaking...';
    return 'Your cooking assistant';
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
        onPressed: () {
          _voiceService.stop();
          Navigator.pop(context);
        },
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          const CheffyOrb(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cheffy',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                Text(
                  _getStatusText(),
                  style: GoogleFonts.poppins(
                    color: _isTyping || _isListening 
                        ? AppColors.primary 
                        : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Read aloud toggle
        IconButton(
          icon: Icon(
            _readAloudEnabled ? Icons.volume_up : Icons.volume_off,
            color: _readAloudEnabled ? AppColors.primary : AppColors.textSecondary,
          ),
          onPressed: _toggleReadAloud,
          tooltip: _readAloudEnabled ? 'Mute Cheffy' : 'Unmute Cheffy',
        ),
        if (_ingredients.isNotEmpty)
          TextButton(
            onPressed: _clearIngredients,
            child: Text(
              'Clear',
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIngredientsSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_basket, 
              size: 18, color: AppColors.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _ingredients.take(5).map((e) => e.capitalize()).join(', ') +
                  (_ingredients.length > 5 ? '...' : ''),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_ingredients.length}',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return _TypingIndicator();
        }
        return _ChatBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildInputArea() {
    final bool hasText = _messageController.text.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Listening indicator
            if (_isListening)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Listening... speak your ingredients',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Find Recipes button
            if (_ingredients.isNotEmpty && !_isListening)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSearching ? null : _findRecipes,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 20),
                    label: Text(
                      _isSearching
                          ? 'Searching...'
                          : 'Find Recipes (${_ingredients.length} ingredients)',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ),
            // Text input
            Row(
              children: [
                // Mic button
                GestureDetector(
                  onTap: _toggleVoiceInput,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isListening ? _pulseAnimation.value * 0.9 + 0.1 : 1.0,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _isListening 
                                ? AppColors.error
                                : AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: _isListening ? Colors.white : AppColors.primary,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: _isListening 
                            ? 'Listening...' 
                            : 'Type or tap mic to speak...',
                        hintStyle: GoogleFonts.poppins(
                          color: AppColors.textHint,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isListening,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: hasText ? _sendMessage : null,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: hasText 
                          ? AppColors.primary 
                          : AppColors.primary.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      boxShadow: hasText ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ] : null,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat message model
class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isAction;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isAction = false,
  }) : timestamp = DateTime.now();
}

/// Chat bubble widget
class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isAction) {
      return _ActionBubble(text: message.text);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: CheffyOrb(size: 36),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? AppColors.primary.withValues(alpha: 0.9) 
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: GoogleFonts.poppins(
                  color: message.isUser ? Colors.white : AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 46),
        ],
      ),
    );
  }
}

/// Action bubble (for system actions like "Clear list")
class _ActionBubble extends StatelessWidget {
  final String text;

  const _ActionBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// Typing indicator
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: CheffyOrb(size: 36),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final delay = index * 0.2;
                    final value = ((_controller.value + delay) % 1.0);
                    final opacity = (value < 0.5 ? value : 1 - value) * 2;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Opacity(
                        opacity: 0.3 + (opacity * 0.7),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


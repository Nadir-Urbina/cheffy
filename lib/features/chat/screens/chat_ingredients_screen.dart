import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/user_preferences.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/theme/app_colors.dart';
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
  bool _readAloudEnabled = true;
  
  late AnimationController _pulseController;

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
    )..repeat(reverse: true);
  }

  Future<void> _initVoice() async {
    await _voiceService.initialize();
    
    _voiceService.onSpeechResult = (text) {
      if (text.isNotEmpty && mounted) {
        setState(() => _messageController.text = text);
      }
    };
    
    _voiceService.onSpeechStart = () {
      if (mounted) setState(() => _isListening = true);
    };
    
    _voiceService.onSpeechEnd = () {
      if (mounted) setState(() => _isListening = false);
    };
    
    _voiceService.onTtsComplete = () {};
    
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
        content: Text(message, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _addCheffyMessage(String text, {bool speak = true}) {
    _messages.add(_ChatMessage(text: text, isUser: false));
    
    if (speak && _readAloudEnabled) {
      final cleanText = text.replaceAll(RegExp(r'[^\x00-\x7F]+'), '').trim();
      if (cleanText.isNotEmpty) {
        _voiceService.speak(cleanText);
      }
    }
  }

  Future<void> _toggleVoiceInput() async {
    HapticFeedback.mediumImpact();
    
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
    } else {
      await _voiceService.stop();
      setState(() => _isListening = true);
      await _voiceService.startListening(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
      );
    }
  }

  void _toggleReadAloud() {
    HapticFeedback.selectionClick();
    setState(() {
      _readAloudEnabled = !_readAloudEnabled;
      if (!_readAloudEnabled) _voiceService.stop();
    });
  }

  void _addCheffyGreeting() {
    _messages.add(_ChatMessage(
      text: "Hi! I'm Chefsito. Tell me what ingredients you have and I'll find recipes for you.\n\nYou can list them all at once or one by one.",
      isUser: false,
    ));
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

    _parseIngredients(text);
  }

  void _parseIngredients(String text) {
    final cleanedText = _extractIngredientsFromSpeech(text);
    debugPrint('Cleaned text: "$cleanedText"');
    
    var parts = cleanedText
        .split(RegExp(r'[,\n;]|\band\b|&'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    
    if (parts.length == 1 && parts.first.split(' ').length > 3) {
      parts = _smartSplitIngredients(parts.first);
    }
    
    final newIngredients = parts
        .where((s) => s.isNotEmpty && s.length > 1 && !_isFillerWord(s))
        .toList();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      setState(() {
        _isTyping = false;
        
        if (newIngredients.isEmpty) {
          _addCheffyMessage(
            "I didn't catch any ingredients. Try something like: chicken, rice, tomatoes"
          );
        } else {
          for (final ing in newIngredients) {
            if (!_ingredients.contains(ing)) {
              _ingredients.add(ing);
            }
          }
          final response = _getCheffyResponse(newIngredients);
          _addCheffyMessage(response);
        }
      });
      _scrollToBottom();
    });
  }

  String _extractIngredientsFromSpeech(String text) {
    String cleaned = text.toLowerCase();
    
    final phrasesToRemove = [
      r"hey (cheffy|jeffy|chef|siri|alexa|google)",
      r"hi (cheffy|jeffy|chef)",
      r"so i have basically", r"i have basically", r"i basically have",
      r"i've basically got", r"i've got", r"i have got", r"i got", r"i have",
      r"we have", r"we've got", r"there is", r"there's", r"basically",
      r"um+", r"uh+", r"like\s+", r"you know", r"let me see", r"let's see",
      r"a lot of", r"lots of", r"a few", r"a little bit of", r"a little",
      r"a bit of", r"i think", r"i guess", r"kind of", r"sort of",
    ];
    
    for (final phrase in phrasesToRemove) {
      cleaned = cleaned.replaceAll(RegExp(phrase, caseSensitive: false), ' ');
    }
    
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _smartSplitIngredients(String text) {
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return [];
    
    const multiWordSuffixes = {
      'breast', 'thigh', 'wing', 'leg', 'oil', 'cream', 'sauce', 'cheese',
      'pepper', 'beans', 'rice', 'flour', 'sugar', 'powder', 'juice',
      'leaves', 'seed', 'seeds', 'butter', 'milk', 'stock', 'broth',
      'paste', 'vinegar',
    };
    
    const multiWordPrefixes = {
      'chicken', 'beef', 'pork', 'turkey', 'ground', 'fresh', 'frozen',
      'olive', 'vegetable', 'coconut', 'sesame', 'canola', 'sour', 'heavy',
      'whipping', 'cream', 'soy', 'hot', 'tomato', 'fish', 'oyster',
      'bell', 'black', 'white', 'red', 'green', 'yellow', 'brown',
      'powdered', 'granulated', 'lemon', 'lime', 'orange', 'apple',
      'bay', 'basil', 'dried', 'peanut', 'almond', 'cashew', 'balsamic', 'wine',
    };
    
    final ingredients = <String>[];
    int i = 0;
    
    while (i < words.length) {
      final word = words[i].toLowerCase();
      
      if (i + 1 < words.length) {
        final nextWord = words[i + 1].toLowerCase();
        
        if (multiWordPrefixes.contains(word) && 
            (multiWordSuffixes.contains(nextWord) || multiWordPrefixes.contains(nextWord))) {
          ingredients.add('$word $nextWord');
          i += 2;
          continue;
        }
        
        if (multiWordSuffixes.contains(nextWord)) {
          ingredients.add('$word $nextWord');
          i += 2;
          continue;
        }
      }
      
      if (!_isFillerWord(word) && word.length > 1) {
        ingredients.add(word);
      }
      i++;
    }
    
    return ingredients;
  }

  bool _isFillerWord(String word) {
    const fillerWords = {
      'a', 'an', 'the', 'some', 'any', 'few', 'little', 'bit',
      'i', 'we', 'you', 'have', 'has', 'got', 'get', 'also',
      'basically', 'actually', 'really', 'just', 'only', 'maybe',
      'probably', 'think', 'guess', 'so', 'then', 'too',
      'oh', 'ah', 'um', 'uh', 'hmm', 'well', 'like',
      'yes', 'no', 'yeah', 'yep', 'nope', 'ok', 'okay', 'sure', 
      'right', 'here', 'there', 'this', 'that', 'it', 'its',
    };
    return fillerWords.contains(word.toLowerCase());
  }

  String _getCheffyResponse(List<String> newIngredients) {
    final total = _ingredients.length;
    
    if (newIngredients.length == 1) {
      final responses = [
        "Got it, ${newIngredients.first} added. What else?",
        "${newIngredients.first.capitalize()} is on the list. Anything else?",
        "Added ${newIngredients.first}. Keep going!",
      ];
      return responses[total % responses.length];
    } else {
      final responses = [
        "Added ${newIngredients.length} ingredients. You now have $total total. What else?",
        "Great! ${newIngredients.length} more added. That's $total items now.",
        "Got ${newIngredients.length} new items. Tap 'Find Recipes' when you're ready!",
      ];
      return responses[total % responses.length];
    }
  }

  Future<void> _findRecipes() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
    }
    
    if (_ingredients.isEmpty) {
      setState(() {
        _addCheffyMessage("You haven't added any ingredients yet. What do you have?");
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _isSearching = true;
      _addCheffyMessage("Searching for recipes with your ${_ingredients.length} ingredients...", speak: false);
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
          if (_readAloudEnabled) {
            _voiceService.speak("I found ${result.recipes.length} recipes for you!");
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeResultsScreen(result: result),
            ),
          );
        } else {
          setState(() {
            _addCheffyMessage("Couldn't find recipes with those ingredients. Try adding a few more.");
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _addCheffyMessage("Something went wrong. Please try again.");
      });
      _scrollToBottom();
    }
  }

  void _clearIngredients() {
    setState(() {
      _ingredients.clear();
      _addCheffyMessage("List cleared. What ingredients do you have?");
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_ingredients.isNotEmpty) _buildIngredientsSummary(),
          Expanded(child: _buildChatList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
        onPressed: () {
          _voiceService.stop();
          Navigator.pop(context);
        },
      ),
      title: Text(
        'My Chefsito',
        style: GoogleFonts.inter(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            _readAloudEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: _readAloudEnabled ? AppColors.primary : Colors.grey,
            size: 22,
          ),
          onPressed: _toggleReadAloud,
        ),
        if (_ingredients.isNotEmpty)
          TextButton(
            onPressed: _clearIngredients,
            child: Text(
              'Clear',
              style: GoogleFonts.inter(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIngredientsSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_basket_outlined, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _ingredients.take(4).map((e) => e.capitalize()).join(', ') +
                  (_ingredients.length > 4 ? ' +${_ingredients.length - 4} more' : ''),
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_ingredients.length}',
              style: GoogleFonts.inter(
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return _buildTypingIndicator();
        }
        return _ChatBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final delay = i * 0.2;
                    final value = ((_pulseController.value + delay) % 1.0);
                    final opacity = (value < 0.5 ? value : 1 - value) * 2;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400.withValues(alpha: 0.4 + opacity * 0.6),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final bool hasText = _messageController.text.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Find Recipes button
            if (_ingredients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSearching ? null : _findRecipes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            'Find Recipes (${_ingredients.length})',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),
            // Input row
            Container(
              constraints: const BoxConstraints(maxHeight: 180), // ~9 lines
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Mic button
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: IconButton(
                      onPressed: _toggleVoiceInput,
                      icon: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: _isListening ? Colors.red : Colors.grey.shade600,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isListening 
                            ? Colors.red.withValues(alpha: 0.1) 
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                      minLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Listening...' : 'Message',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade500,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isListening,
                    ),
                  ),
                  // Send button
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 4),
                    child: IconButton(
                      onPressed: hasText ? _sendMessage : null,
                      icon: Icon(
                        Icons.arrow_upward_rounded,
                        color: hasText ? Colors.white : Colors.grey.shade400,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: hasText 
                            ? Colors.black87 
                            : Colors.grey.shade300,
                        minimumSize: const Size(32, 32),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ),
                ],
              ),
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
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
  }) : timestamp = DateTime.now();
}

/// Chat bubble widget - ChatGPT style
class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: message.isUser ? _buildUserMessage() : _buildAssistantMessage(),
    );
  }

  Widget _buildUserMessage() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(width: 48),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              message.text,
              style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantMessage() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            message.text,
            style: GoogleFonts.inter(
              color: Colors.black87,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

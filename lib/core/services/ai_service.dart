import 'dart:convert';
import 'dart:io';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/recipe_model.dart';
import '../models/user_preferences.dart';
import 'spoonacular_service.dart';

/// AI Service for ingredient analysis and recipe suggestions
/// 
/// Architecture:
/// - GPT-4o Vision: Analyzes images to detect ingredients (safe - just identification)
/// - Spoonacular API: Provides verified, tested recipes (safe - real recipes)
/// 
/// This hybrid approach ensures:
/// 1. Smart ingredient detection via AI
/// 2. Safe, verified recipes from a trusted database
class AIService {
  static const String _model = 'gpt-4o';
  
  final SpoonacularService _spoonacularService = SpoonacularService();
  bool _initialized = false;

  /// Initialize the OpenAI client
  void initialize() {
    if (_initialized) return;
    
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_openai_api_key_here') {
      throw Exception('OpenAI API key not configured. Please add it to .env file.');
    }
    
    OpenAI.apiKey = apiKey;
    _initialized = true;
  }

  /// Analyze images and extract ingredients using GPT-4o Vision
  /// This is safe - we're only identifying what's in the images
  Future<IngredientScanResult> analyzeIngredients({
    required List<File> images,
    List<String> additionalItems = const [],
  }) async {
    initialize();
    
    try {
      // Convert images to base64
      final imageContents = <OpenAIChatCompletionChoiceMessageContentItemModel>[];
      
      // Add the text prompt first
      imageContents.add(
        OpenAIChatCompletionChoiceMessageContentItemModel.text(
          '''Analyze these images of a kitchen/refrigerator/pantry and identify all visible food ingredients.

Rules:
- List ONLY food items that can be used as cooking ingredients
- Be specific (e.g., "chicken breast" not just "meat")
- Include quantities if clearly visible (e.g., "2 tomatoes", "1 bunch of cilantro")
- Include condiments, sauces, and spices if visible
- Ignore non-food items, packaging without clear food content
- If an item is partially visible or unclear, make your best educated guess
- Use common ingredient names that would be found in recipes

Respond ONLY with a JSON object in this exact format:
{
  "ingredients": ["ingredient 1", "ingredient 2", ...],
  "confidence": "high" | "medium" | "low",
  "notes": "any relevant observations"
}''',
        ),
      );

      // Add images
      for (final image in images) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        imageContents.add(
          OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(
            'data:image/jpeg;base64,$base64Image',
          ),
        );
      }

      final response = await OpenAI.instance.chat.create(
        model: _model,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: imageContents,
          ),
        ],
        maxTokens: 1000,
        temperature: 0.3, // Lower temperature for more consistent results
      );

      final content = response.choices.first.message.content;
      if (content == null || content.isEmpty) {
        throw Exception('No response from AI');
      }

      // Parse the JSON response
      final jsonStr = _extractJson(content.first.text ?? '');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final ingredients = List<String>.from(data['ingredients'] ?? []);

      debugPrint('AI detected ${ingredients.length} ingredients');

      return IngredientScanResult(
        detectedIngredients: ingredients,
        additionalItems: additionalItems,
        rawAnalysis: content.first.text,
      );
    } catch (e) {
      debugPrint('Error analyzing ingredients: $e');
      rethrow;
    }
  }

  /// Get recipe suggestions from Spoonacular based on ingredients
  /// These are REAL, VERIFIED recipes - not AI generated
  Future<RecipeSuggestionResult> suggestRecipes({
    required List<String> availableIngredients,
    required UserPreferences preferences,
    int numberOfRecipes = 3,
  }) async {
    try {
      debugPrint('Fetching verified recipes from Spoonacular...');
      
      final recipes = await _spoonacularService.findByIngredients(
        ingredients: availableIngredients,
        preferences: preferences,
        numberOfRecipes: numberOfRecipes,
      );

      debugPrint('Found ${recipes.length} verified recipes');

      return RecipeSuggestionResult(
        recipes: recipes,
        availableIngredients: availableIngredients,
      );
    } catch (e) {
      debugPrint('Error fetching recipes: $e');
      return RecipeSuggestionResult(
        recipes: [],
        availableIngredients: availableIngredients,
        error: e.toString(),
      );
    }
  }

  /// Combined: Analyze images and suggest recipes in one flow
  /// 
  /// Flow:
  /// 1. GPT-4o analyzes images → extracts ingredient list
  /// 2. Spoonacular finds real recipes → returns verified recipes
  Future<RecipeSuggestionResult> analyzeAndSuggest({
    required List<File> images,
    List<String> additionalItems = const [],
    required UserPreferences preferences,
    int numberOfRecipes = 3,
  }) async {
    // Step 1: Analyze images with AI (safe - just identification)
    final scanResult = await analyzeIngredients(
      images: images,
      additionalItems: additionalItems,
    );

    debugPrint('Total ingredients: ${scanResult.allIngredients.length}');
    debugPrint('Ingredients: ${scanResult.allIngredients.join(", ")}');

    // Step 2: Get REAL recipes from Spoonacular (safe - verified recipes)
    return suggestRecipes(
      availableIngredients: scanResult.allIngredients,
      preferences: preferences,
      numberOfRecipes: numberOfRecipes,
    );
  }

  /// Extract JSON from a response that might contain markdown or other text
  String _extractJson(String text) {
    // Try to find JSON in markdown code blocks
    final codeBlockPattern = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final codeBlockMatch = codeBlockPattern.firstMatch(text);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)?.trim() ?? text;
    }

    // Try to find JSON object directly
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final jsonMatch = jsonPattern.firstMatch(text);
    if (jsonMatch != null) {
      return jsonMatch.group(0) ?? text;
    }

    return text;
  }
}

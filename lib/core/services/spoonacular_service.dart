import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/recipe_model.dart';
import '../models/user_preferences.dart';

/// Service for fetching verified recipes from Spoonacular API
/// https://spoonacular.com/food-api/docs
class SpoonacularService {
  static const String _baseUrl = 'https://api.spoonacular.com';
  
  String get _apiKey {
    final key = dotenv.env['SPOONACULAR_API_KEY'];
    if (key == null || key.isEmpty || key == 'your-spoonacular-key-here') {
      throw Exception('Spoonacular API key not configured. Please add it to .env file.');
    }
    return key;
  }

  /// Search for recipes by ingredients
  /// Returns real, verified recipes from Spoonacular's database
  Future<List<Recipe>> findByIngredients({
    required List<String> ingredients,
    required UserPreferences preferences,
    int numberOfRecipes = 3,
  }) async {
    try {
      // Step 1: Find recipes by ingredients
      final ingredientList = ingredients.join(',');
      final searchUrl = Uri.parse(
        '$_baseUrl/recipes/findByIngredients'
        '?apiKey=$_apiKey'
        '&ingredients=$ingredientList'
        '&number=${numberOfRecipes * 2}' // Get extra to filter
        '&ranking=2' // Maximize used ingredients
        '&ignorePantry=false',
      );

      debugPrint('Searching recipes with ingredients: $ingredientList');
      
      final searchResponse = await http.get(searchUrl);
      
      if (searchResponse.statusCode != 200) {
        throw Exception('Spoonacular API error: ${searchResponse.statusCode}');
      }

      final searchResults = jsonDecode(searchResponse.body) as List<dynamic>;
      
      if (searchResults.isEmpty) {
        return [];
      }

      // Step 2: Get detailed information for each recipe
      final recipeIds = searchResults
          .take(numberOfRecipes * 2)
          .map((r) => r['id'].toString())
          .join(',');

      final detailsUrl = Uri.parse(
        '$_baseUrl/recipes/informationBulk'
        '?apiKey=$_apiKey'
        '&ids=$recipeIds'
        '&includeNutrition=true',
      );

      final detailsResponse = await http.get(detailsUrl);
      
      if (detailsResponse.statusCode != 200) {
        throw Exception('Spoonacular API error: ${detailsResponse.statusCode}');
      }

      final detailsResults = jsonDecode(detailsResponse.body) as List<dynamic>;

      // Step 3: Convert to our Recipe model and filter by preferences
      final recipes = <Recipe>[];
      
      for (final recipeJson in detailsResults) {
        final recipe = _parseSpoonacularRecipe(
          recipeJson as Map<String, dynamic>,
          searchResults,
          ingredients,
          preferences,
        );
        
        // Filter by dietary restrictions
        if (_matchesDietaryRestrictions(recipeJson, preferences)) {
          recipes.add(recipe);
        }
      }

      // Sort by match percentage and return top results
      recipes.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
      
      return recipes.take(numberOfRecipes).toList();
    } catch (e) {
      debugPrint('Error fetching recipes from Spoonacular: $e');
      rethrow;
    }
  }

  /// Parse Spoonacular recipe response into our Recipe model
  Recipe _parseSpoonacularRecipe(
    Map<String, dynamic> json,
    List<dynamic> searchResults,
    List<String> availableIngredients,
    UserPreferences preferences,
  ) {
    // Find the search result for this recipe to get used/missed ingredients
    final searchResult = searchResults.firstWhere(
      (r) => r['id'] == json['id'],
      orElse: () => <String, dynamic>{},
    );

    final usedIngredients = (searchResult['usedIngredients'] as List<dynamic>?) ?? [];
    final missedIngredients = (searchResult['missedIngredients'] as List<dynamic>?) ?? [];
    
    // Calculate match percentage
    final totalNeeded = usedIngredients.length + missedIngredients.length;
    final matchPercentage = totalNeeded > 0 
        ? ((usedIngredients.length / totalNeeded) * 100).round()
        : 0;

    // Parse ingredients
    final extendedIngredients = json['extendedIngredients'] as List<dynamic>? ?? [];
    final ingredients = extendedIngredients.map((ing) {
      final ingName = (ing['name'] ?? '').toString().toLowerCase();
      final isAvailable = availableIngredients.any(
        (available) => available.toLowerCase().contains(ingName) ||
            ingName.contains(available.toLowerCase()),
      );
      
      return RecipeIngredient(
        name: ing['name'] ?? '',
        quantity: (ing['amount'] ?? 0).toDouble(),
        unit: ing['unit'] ?? '',
        isOptional: false,
        isAvailable: isAvailable,
      );
    }).toList();

    // Parse instructions
    final analyzedInstructions = json['analyzedInstructions'] as List<dynamic>? ?? [];
    final instructions = <String>[];
    
    for (final section in analyzedInstructions) {
      final steps = section['steps'] as List<dynamic>? ?? [];
      for (final step in steps) {
        instructions.add(step['step'] ?? '');
      }
    }

    // If no analyzed instructions, try summary
    if (instructions.isEmpty && json['instructions'] != null) {
      // Strip HTML tags from instructions
      final rawInstructions = json['instructions'].toString();
      final stripped = rawInstructions.replaceAll(RegExp(r'<[^>]*>'), '');
      instructions.addAll(stripped.split(RegExp(r'\.\s+')).where((s) => s.trim().isNotEmpty));
    }

    // Parse nutrition if available
    NutritionInfo? nutrition;
    if (json['nutrition'] != null) {
      final nutrients = json['nutrition']['nutrients'] as List<dynamic>? ?? [];
      
      int getIntNutrient(String name) {
        final nutrient = nutrients.firstWhere(
          (n) => n['name'] == name,
          orElse: () => {'amount': 0},
        );
        return (nutrient['amount'] ?? 0).round();
      }
      
      nutrition = NutritionInfo(
        calories: getIntNutrient('Calories'),
        proteinGrams: getIntNutrient('Protein'),
        carbsGrams: getIntNutrient('Carbohydrates'),
        fatGrams: getIntNutrient('Fat'),
        fiberGrams: getIntNutrient('Fiber'),
      );
    }

    // Determine difficulty based on ready time and number of steps
    final readyInMinutes = json['readyInMinutes'] ?? 30;
    String difficulty;
    if (readyInMinutes <= 20 && instructions.length <= 5) {
      difficulty = 'easy';
    } else if (readyInMinutes <= 45 && instructions.length <= 10) {
      difficulty = 'medium';
    } else {
      difficulty = 'hard';
    }

    // Extract cuisine type
    final cuisines = json['cuisines'] as List<dynamic>? ?? [];
    final cuisineType = cuisines.isNotEmpty 
        ? cuisines.first.toString().toLowerCase() 
        : 'other';

    // Get missing ingredient names
    final missingIngredientNames = missedIngredients
        .map((m) => m['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    return Recipe(
      id: json['id'].toString(),
      name: json['title'] ?? 'Unnamed Recipe',
      description: _cleanHtml(json['summary'] ?? ''),
      cuisineType: cuisineType,
      prepTimeMinutes: json['preparationMinutes'] ?? 0,
      cookTimeMinutes: json['cookingMinutes'] ?? (json['readyInMinutes'] ?? 30),
      difficulty: difficulty,
      servings: json['servings'] ?? preferences.householdSize,
      ingredients: ingredients,
      instructions: instructions,
      matchPercentage: matchPercentage,
      missingIngredients: missingIngredientNames,
      imageUrl: json['image'],
      nutrition: nutrition,
    );
  }

  /// Check if recipe matches user's dietary restrictions
  bool _matchesDietaryRestrictions(
    Map<String, dynamic> json,
    UserPreferences preferences,
  ) {
    // If no restrictions, allow all
    if (preferences.dietaryRestrictions.isEmpty ||
        preferences.dietaryRestrictions.contains(DietaryRestriction.none)) {
      return true;
    }

    for (final restriction in preferences.dietaryRestrictions) {
      switch (restriction) {
        case DietaryRestriction.vegetarian:
          if (json['vegetarian'] != true) return false;
          break;
        case DietaryRestriction.vegan:
          if (json['vegan'] != true) return false;
          break;
        case DietaryRestriction.glutenFree:
          if (json['glutenFree'] != true) return false;
          break;
        case DietaryRestriction.dairyFree:
          if (json['dairyFree'] != true) return false;
          break;
        case DietaryRestriction.keto:
          // Check if low carb (rough approximation)
          final nutrition = json['nutrition'];
          if (nutrition != null) {
            final nutrients = nutrition['nutrients'] as List<dynamic>? ?? [];
            final carbs = nutrients.firstWhere(
              (n) => n['name'] == 'Carbohydrates',
              orElse: () => {'amount': 100},
            );
            if ((carbs['amount'] ?? 100) > 20) return false;
          }
          break;
        default:
          // For other restrictions, we can't easily filter via Spoonacular
          // They would need to be handled differently
          break;
      }
    }

    return true;
  }

  /// Clean HTML tags from text
  String _cleanHtml(String html) {
    // Remove HTML tags
    var cleaned = html.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode common HTML entities
    cleaned = cleaned
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');
    // Truncate to reasonable length for description
    if (cleaned.length > 200) {
      cleaned = '${cleaned.substring(0, 197)}...';
    }
    return cleaned.trim();
  }

  /// Get recipe by ID (for detailed view)
  Future<Recipe?> getRecipeById(String id, UserPreferences preferences) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/recipes/$id/information'
        '?apiKey=$_apiKey'
        '&includeNutrition=true',
      );

      final response = await http.get(url);
      
      if (response.statusCode != 200) {
        throw Exception('Spoonacular API error: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      
      return _parseSpoonacularRecipe(json, [], [], preferences);
    } catch (e) {
      debugPrint('Error fetching recipe details: $e');
      return null;
    }
  }
}

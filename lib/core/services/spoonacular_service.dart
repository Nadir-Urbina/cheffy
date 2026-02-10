import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/recipe_model.dart';
import '../models/user_preferences.dart';
import 'recipe_cache_service.dart';

/// Service for fetching verified recipes from Spoonacular API
/// https://spoonacular.com/food-api/docs
class SpoonacularService {
  static const String _baseUrl = 'https://api.spoonacular.com';
  
  // Cache service for reducing API calls
  final RecipeCacheService _cacheService = RecipeCacheService();
  
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
        '&number=${numberOfRecipes * 3}' // Get extra to filter and rank
        '&ranking=1' // Maximize USED ingredients (use more of what user has)
        '&ignorePantry=true', // Don't assume user has pantry staples
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
      
      // Identify the PRIMARY protein - this should be the star!
      final primaryProtein = _identifyPrimaryProtein(ingredients);
      final keyIngredients = _identifyKeyIngredients(ingredients);
      
      debugPrint('🥩 Primary protein: $primaryProtein');
      debugPrint('🥔 Secondary key ingredients: $keyIngredients');
      
      for (int i = 0; i < detailsResults.length; i++) {
        final recipeJson = detailsResults[i] as Map<String, dynamic>;
        final searchResult = searchResults.firstWhere(
          (r) => r['id'] == recipeJson['id'],
          orElse: () => <String, dynamic>{},
        );
        
        final recipe = _parseSpoonacularRecipe(
          recipeJson,
          searchResults,
          ingredients,
          preferences,
        );
        
        // Filter by dietary restrictions
        if (_matchesDietaryRestrictions(recipeJson, preferences)) {
          // Get the list of ingredients this recipe uses from user's list
          final usedIngredients = (searchResult['usedIngredients'] as List<dynamic>?) ?? [];
          final usedNames = usedIngredients
              .map((u) => (u['name'] ?? '').toString().toLowerCase())
              .toSet();
          
          // Check if recipe uses the PRIMARY PROTEIN
          bool usesProtein = false;
          if (primaryProtein != null) {
            usesProtein = usedNames.any((used) => 
                used.contains(primaryProtein.toLowerCase()) || 
                primaryProtein.toLowerCase().contains(used));
          }
          
          // Count secondary key ingredients used
          int keyIngredientsUsed = 0;
          for (final key in keyIngredients) {
            if (usedNames.any((used) => 
                used.contains(key.toLowerCase()) || 
                key.toLowerCase().contains(used))) {
              keyIngredientsUsed++;
            }
          }
          
          // SCORING: Protein is KING
          // - Recipes using the protein: +50 bonus (massive priority)
          // - Secondary key ingredients: +10 each
          // - Base match percentage
          int boostedScore = recipe.matchPercentage;
          if (usesProtein) {
            boostedScore += 50; // Protein is the star!
            debugPrint('⭐ "${recipe.name}" uses protein $primaryProtein! Score boosted to $boostedScore');
          }
          boostedScore += keyIngredientsUsed * 10;
          
          recipes.add(_RecipeWithScore(recipe, boostedScore, usesProtein ? 1 : 0));
        }
      }

      // Sort by boosted score - protein recipes should float to top
      recipes.sort((a, b) {
        final aScore = a is _RecipeWithScore ? a.score : a.matchPercentage;
        final bScore = b is _RecipeWithScore ? b.score : b.matchPercentage;
        return bScore.compareTo(aScore);
      });
      
      debugPrint('📊 Final recipe ranking:');
      for (final r in recipes.take(5)) {
        if (r is _RecipeWithScore) {
          debugPrint('  - ${r.recipe.name}: score=${r.score}, usesProtein=${r.keyIngredientsUsed > 0}');
        }
      }
      
      // Return actual Recipe objects
      return recipes
          .take(numberOfRecipes)
          .map((r) => r is _RecipeWithScore ? r.recipe : r)
          .toList();
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

    // Determine difficulty based on time, steps, and ingredient count
    final readyInMinutes = json['readyInMinutes'] ?? 30;
    final difficulty = _calculateDifficulty(
      readyInMinutes: readyInMinutes,
      stepCount: instructions.length,
      ingredientCount: ingredients.length,
    );

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
      imageUrl: _getHighResImageUrl(json['image']),
      nutrition: nutrition,
      sourceUrl: json['sourceUrl'],
      sourceName: json['sourceName'] ?? json['creditsText'],
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

  /// Identify the PRIMARY protein - this is the star of the dish
  String? _identifyPrimaryProtein(List<String> ingredients) {
    const proteins = [
      'chicken', 'beef', 'ground beef', 'pork', 'fish', 'salmon', 'tuna', 
      'shrimp', 'turkey', 'lamb', 'bacon', 'ham', 'sausage', 'steak', 
      'tofu', 'tempeh', 'meatball', 'ground turkey', 'ground pork',
      'ribeye', 'sirloin', 'tenderloin', 'chuck', 'brisket',
    ];
    
    for (final ingredient in ingredients) {
      final lower = ingredient.toLowerCase();
      if (proteins.any((p) => lower.contains(p))) {
        return ingredient;
      }
    }
    return null;
  }

  /// Identify secondary key ingredients
  List<String> _identifyKeyIngredients(List<String> ingredients) {
    const keywordPatterns = [
      // Main carbs
      'pasta', 'rice', 'noodles', 'bread', 'potato', 'quinoa',
      // Key vegetables often central to dishes
      'broccoli', 'cauliflower', 'mushroom', 'eggplant', 'zucchini',
    ];
    
    final keyIngredients = <String>[];
    for (final ingredient in ingredients) {
      final lower = ingredient.toLowerCase();
      if (keywordPatterns.any((pattern) => lower.contains(pattern))) {
        keyIngredients.add(ingredient);
      }
    }
    
    return keyIngredients;
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

  /// Convert Spoonacular image URL to highest resolution (636x393)
  /// 
  /// Spoonacular images follow the pattern:
  /// https://img.spoonacular.com/recipes/{id}-{size}.{ext}
  /// or https://spoonacular.com/recipeImages/{id}-{size}.{ext}
  /// 
  /// Available sizes: 90x90, 240x150, 312x231, 480x360, 556x370, 636x393
  String? _getHighResImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    
    // Remove trailing period if present (malformed URL)
    String cleanUrl = imageUrl.endsWith('.') 
        ? '${imageUrl}jpg'  // Add jpg extension
        : imageUrl;
    
    // Pattern to match Spoonacular image URLs with size and extension
    // e.g., https://img.spoonacular.com/recipes/716429-556x370.jpg
    final sizePattern = RegExp(r'-\d+x\d+\.(\w+)$');
    
    if (sizePattern.hasMatch(cleanUrl)) {
      // Replace existing size with max resolution
      return cleanUrl.replaceAllMapped(
        sizePattern,
        (match) => '-636x393.${match.group(1)}',
      );
    }
    
    // Some URLs might not have size, try to add it
    // e.g., https://spoonacular.com/recipeImages/716429.jpg
    final noSizePattern = RegExp(r'/(\d+)\.(\w+)$');
    if (noSizePattern.hasMatch(cleanUrl)) {
      return cleanUrl.replaceAllMapped(
        noSizePattern,
        (match) => '/${match.group(1)}-636x393.${match.group(2)}',
      );
    }
    
    // If URL has no extension at all, try adding .jpg
    if (!cleanUrl.contains(RegExp(r'\.\w+$'))) {
      // Extract recipe ID and construct proper URL
      final idMatch = RegExp(r'/recipes?/(\d+)').firstMatch(cleanUrl);
      if (idMatch != null) {
        return 'https://img.spoonacular.com/recipes/${idMatch.group(1)}-636x393.jpg';
      }
    }
    
    // Return cleaned URL if pattern doesn't match
    return cleanUrl;
  }

  /// Calculate recipe difficulty based on a weighted score of time, steps, and ingredients.
  ///
  /// Score formula:
  ///   - Time: readyInMinutes (weighted 1x)
  ///   - Steps: instruction count * 3 (weighted heavily -- more steps = more complex)
  ///   - Ingredients: ingredient count * 2 (more ingredients = more prep work)
  ///
  /// Thresholds:
  ///   - Beginner: score <= 40  (e.g., 20 min + 4 steps + 5 ingredients = 20+12+10 = 42 → intermediate)
  ///   - Intermediate: score <= 75
  ///   - Advanced: score > 75
  static String _calculateDifficulty({
    required int readyInMinutes,
    required int stepCount,
    required int ingredientCount,
  }) {
    final score = readyInMinutes + (stepCount * 3) + (ingredientCount * 2);
    if (score <= 40) return 'beginner';
    if (score <= 75) return 'intermediate';
    return 'advanced';
  }

  /// Get random/popular recipes for home screen display
  /// Returns recipes with real imagery
  /// Optional [tags] parameter for filtering (e.g., 'breakfast', 'lunch', 'dinner', 'dessert', 'appetizer', 'salad', 'soup')
  /// Set [forceRefresh] to true to bypass cache
  Future<List<Recipe>> getPopularRecipes({
    int count = 5, 
    String? tags,
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first (unless forcing refresh)
      if (!forceRefresh) {
        final cachedRecipes = await _cacheService.getCachedPopularRecipes(tag: tags);
        if (cachedRecipes != null && cachedRecipes.length >= count) {
          return cachedRecipes.take(count).toList();
        }
      }
      
      var urlString = '$_baseUrl/recipes/random'
        '?apiKey=$_apiKey'
        '&number=$count'
        '&includeNutrition=false';
      
      if (tags != null && tags.isNotEmpty) {
        urlString += '&tags=$tags';
      }
      
      final url = Uri.parse(urlString);

      debugPrint('🌐 Fetching $count popular recipes from API (tag: $tags)...');
      
      final response = await http.get(url);
      
      if (response.statusCode != 200) {
        throw Exception('Spoonacular API error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final recipesJson = data['recipes'] as List<dynamic>? ?? [];
      
      final result = recipesJson.map((json) {
        // Parse instructions
        final analyzedInstructions = json['analyzedInstructions'] as List<dynamic>? ?? [];
        final instructions = <String>[];
        
        for (final section in analyzedInstructions) {
          final steps = section['steps'] as List<dynamic>? ?? [];
          for (final step in steps) {
            instructions.add(step['step'] ?? '');
          }
        }

        // Parse ingredients
        final extendedIngredients = json['extendedIngredients'] as List<dynamic>? ?? [];
        final ingredients = extendedIngredients.map((ing) {
          return RecipeIngredient(
            name: ing['name'] ?? '',
            quantity: (ing['amount'] ?? 0).toDouble(),
            unit: ing['unit'] ?? '',
            isOptional: false,
            isAvailable: false, // Unknown for popular recipes
          );
        }).toList();

        // Determine difficulty based on time, steps, and ingredient count
        final readyInMinutes = json['readyInMinutes'] ?? 30;
        final difficulty = _calculateDifficulty(
          readyInMinutes: readyInMinutes,
          stepCount: instructions.length,
          ingredientCount: ingredients.length,
        );

        // Extract cuisine type
        final cuisines = json['cuisines'] as List<dynamic>? ?? [];
        final cuisineType = cuisines.isNotEmpty 
            ? cuisines.first.toString().toLowerCase() 
            : 'other';

        return Recipe(
          id: json['id'].toString(),
          name: json['title'] ?? 'Unnamed Recipe',
          description: _cleanHtml(json['summary'] ?? ''),
          cuisineType: cuisineType,
          prepTimeMinutes: json['preparationMinutes'] ?? 0,
          cookTimeMinutes: json['cookingMinutes'] ?? (json['readyInMinutes'] ?? 30),
          difficulty: difficulty,
          servings: json['servings'] ?? 4,
          ingredients: ingredients,
          instructions: instructions,
          matchPercentage: 0, // N/A for popular recipes
          missingIngredients: [],
          imageUrl: _getHighResImageUrl(json['image']),
          sourceUrl: json['sourceUrl'],
          sourceName: json['sourceName'] ?? json['creditsText'],
        );
      }).toList();
      
      // Cache the results for future use
      await _cacheService.cachePopularRecipes(result, tag: tags);
      
      return result;
    } catch (e) {
      debugPrint('Error fetching popular recipes: $e');
      return [];
    }
  }

  /// Search recipes by free-text query using complexSearch endpoint
  /// Returns real, verified recipes matching the search term
  /// Uses a fallback strategy: first tries with instructionsRequired=true,
  /// and if no results are found, retries without the filter.
  Future<List<Recipe>> searchRecipes({
    required String query,
    int count = 12,
  }) async {
    try {
      // First attempt: prefer recipes with instructions (better for cooking mode)
      var results = await _searchRecipesRaw(
        query: query,
        count: count,
        instructionsRequired: true,
      );

      // Fallback: if no results, retry without the instructions filter
      if (results.isEmpty) {
        debugPrint('🔄 No results with instructions filter, retrying without...');
        results = await _searchRecipesRaw(
          query: query,
          count: count,
          instructionsRequired: false,
        );
      }

      return results;
    } catch (e) {
      debugPrint('Error searching recipes: $e');
      return [];
    }
  }

  /// Raw search call to Spoonacular complexSearch endpoint
  Future<List<Recipe>> _searchRecipesRaw({
    required String query,
    required int count,
    required bool instructionsRequired,
  }) async {
    final searchUrl = Uri.parse(
      '$_baseUrl/recipes/complexSearch'
      '?apiKey=$_apiKey'
      '&query=${Uri.encodeComponent(query)}'
      '&number=$count'
      '&addRecipeInformation=true'
      '&fillIngredients=true'
      '${instructionsRequired ? '&instructionsRequired=true' : ''}',
    );

    debugPrint('🔍 Searching recipes for: "$query" (instructionsRequired: $instructionsRequired)');

    final response = await http.get(searchUrl);

    if (response.statusCode != 200) {
      throw Exception('Spoonacular API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final resultsJson = data['results'] as List<dynamic>? ?? [];

    if (resultsJson.isEmpty) {
      debugPrint('No search results for "$query" (instructionsRequired: $instructionsRequired)');
      return [];
    }

      final recipes = resultsJson.map((json) {
        // Parse instructions
        final analyzedInstructions =
            json['analyzedInstructions'] as List<dynamic>? ?? [];
        final instructions = <String>[];

        for (final section in analyzedInstructions) {
          final steps = section['steps'] as List<dynamic>? ?? [];
          for (final step in steps) {
            instructions.add(step['step'] ?? '');
          }
        }

        // Parse ingredients
        final extendedIngredients =
            json['extendedIngredients'] as List<dynamic>? ?? [];
        final ingredients = extendedIngredients.map((ing) {
          return RecipeIngredient(
            name: ing['name'] ?? '',
            quantity: (ing['amount'] ?? 0).toDouble(),
            unit: ing['unit'] ?? '',
            isOptional: false,
            isAvailable: false,
          );
        }).toList();

        // Determine difficulty based on time, steps, and ingredient count
        final readyInMinutes = json['readyInMinutes'] ?? 30;
        final difficulty = _calculateDifficulty(
          readyInMinutes: readyInMinutes,
          stepCount: instructions.length,
          ingredientCount: ingredients.length,
        );

        // Extract cuisine type
        final cuisines = json['cuisines'] as List<dynamic>? ?? [];
        final cuisineType = cuisines.isNotEmpty
            ? cuisines.first.toString().toLowerCase()
            : 'other';

        return Recipe(
          id: json['id'].toString(),
          name: json['title'] ?? 'Unnamed Recipe',
          description: _cleanHtml(json['summary'] ?? ''),
          cuisineType: cuisineType,
          prepTimeMinutes: json['preparationMinutes'] ?? 0,
          cookTimeMinutes:
              json['cookingMinutes'] ?? (json['readyInMinutes'] ?? 30),
          difficulty: difficulty,
          servings: json['servings'] ?? 4,
          ingredients: ingredients,
          instructions: instructions,
          matchPercentage: 0,
          missingIngredients: [],
          imageUrl: _getHighResImageUrl(json['image']),
          sourceUrl: json['sourceUrl'],
          sourceName: json['sourceName'] ?? json['creditsText'],
        );
      }).toList();

      debugPrint('✅ Found ${recipes.length} recipes for "$query"');
      return recipes;
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

/// Helper class to track recipe with boosted score
class _RecipeWithScore extends Recipe {
  final Recipe recipe;
  final int score;
  final int keyIngredientsUsed;
  
  _RecipeWithScore(this.recipe, this.score, this.keyIngredientsUsed) : super(
    id: recipe.id,
    name: recipe.name,
    description: recipe.description,
    cuisineType: recipe.cuisineType,
    prepTimeMinutes: recipe.prepTimeMinutes,
    cookTimeMinutes: recipe.cookTimeMinutes,
    difficulty: recipe.difficulty,
    servings: recipe.servings,
    ingredients: recipe.ingredients,
    instructions: recipe.instructions,
    matchPercentage: recipe.matchPercentage,
    missingIngredients: recipe.missingIngredients,
    imageUrl: recipe.imageUrl,
    nutrition: recipe.nutrition,
    sourceUrl: recipe.sourceUrl,
    sourceName: recipe.sourceName,
  );
}

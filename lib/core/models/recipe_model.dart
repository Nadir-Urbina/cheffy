/// A recipe generated or suggested by AI
class Recipe {
  final String id;
  final String name;
  final String description;
  final String cuisineType;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String difficulty; // beginner, intermediate, advanced
  final int servings;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;
  final int matchPercentage; // How well it matches available ingredients
  final List<String> missingIngredients;
  final String? imageUrl;
  final NutritionInfo? nutrition;
  final String? sourceUrl;
  final String? sourceName;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.cuisineType,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.difficulty,
    required this.servings,
    required this.ingredients,
    required this.instructions,
    required this.matchPercentage,
    this.missingIngredients = const [],
    this.imageUrl,
    this.nutrition,
    this.sourceUrl,
    this.sourceName,
  });

  /// Normalizes difficulty to the current naming convention.
  /// Handles legacy values (easy/medium/hard) from cached or stored data.
  String get normalizedDifficulty {
    switch (difficulty.toLowerCase()) {
      case 'easy':
      case 'beginner':
        return 'beginner';
      case 'medium':
      case 'intermediate':
        return 'intermediate';
      case 'hard':
      case 'advanced':
        return 'advanced';
      default:
        return 'intermediate';
    }
  }

  /// User-facing difficulty label -- encouraging and motivational.
  String get difficultyLabel {
    switch (normalizedDifficulty) {
      case 'beginner':
        return 'Easy-Peasy';
      case 'intermediate':
        return 'Getting Fancy';
      case 'advanced':
        return '💪🏼 Up for a Challenge';
      default:
        return 'Getting Fancy';
    }
  }

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  String get totalTimeFormatted {
    final total = totalTimeMinutes;
    if (total < 60) return '$total min';
    final hours = total ~/ 60;
    final mins = total % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? 'Unnamed Recipe',
      description: json['description'] ?? '',
      cuisineType: json['cuisineType'] ?? 'other',
      prepTimeMinutes: json['prepTimeMinutes'] ?? 0,
      cookTimeMinutes: json['cookTimeMinutes'] ?? 0,
      difficulty: json['difficulty'] ?? 'intermediate',
      servings: json['servings'] ?? 2,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: List<String>.from(json['instructions'] ?? []),
      matchPercentage: json['matchPercentage'] ?? 0,
      missingIngredients: List<String>.from(json['missingIngredients'] ?? []),
      imageUrl: json['imageUrl'],
      nutrition: json['nutrition'] != null
          ? NutritionInfo.fromJson(json['nutrition'])
          : null,
      sourceUrl: json['sourceUrl'],
      sourceName: json['sourceName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cuisineType': cuisineType,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'difficulty': difficulty,
      'servings': servings,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'instructions': instructions,
      'matchPercentage': matchPercentage,
      'missingIngredients': missingIngredients,
      'imageUrl': imageUrl,
      'nutrition': nutrition?.toJson(),
      'sourceUrl': sourceUrl,
      'sourceName': sourceName,
    };
  }
}

/// An ingredient in a recipe with quantity and unit
class RecipeIngredient {
  final String name;
  final double quantity;
  final String unit;
  final bool isOptional;
  final bool isAvailable; // Whether user has this ingredient

  RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.isOptional = false,
    this.isAvailable = true,
  });

  String get formatted {
    if (quantity == 0) return name;
    final qtyStr = quantity == quantity.toInt() 
        ? quantity.toInt().toString() 
        : quantity.toString();
    return '$qtyStr $unit $name'.trim();
  }

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      isOptional: json['isOptional'] ?? false,
      isAvailable: json['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'isOptional': isOptional,
      'isAvailable': isAvailable,
    };
  }
}

/// Nutrition information for a recipe
class NutritionInfo {
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int fiberGrams;

  NutritionInfo({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.fiberGrams,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: json['calories'] ?? 0,
      proteinGrams: json['proteinGrams'] ?? 0,
      carbsGrams: json['carbsGrams'] ?? 0,
      fatGrams: json['fatGrams'] ?? 0,
      fiberGrams: json['fiberGrams'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'fiberGrams': fiberGrams,
    };
  }
}

/// Result from ingredient scanning
class IngredientScanResult {
  final List<String> detectedIngredients;
  final List<String> additionalItems;
  final String? rawAnalysis;

  IngredientScanResult({
    required this.detectedIngredients,
    this.additionalItems = const [],
    this.rawAnalysis,
  });

  List<String> get allIngredients => [
        ...detectedIngredients,
        ...additionalItems,
      ];
}

/// Result from recipe suggestion
class RecipeSuggestionResult {
  final List<Recipe> recipes;
  final List<String> availableIngredients;
  final String? error;

  RecipeSuggestionResult({
    required this.recipes,
    required this.availableIngredients,
    this.error,
  });

  bool get hasError => error != null;
  bool get hasRecipes => recipes.isNotEmpty;
}

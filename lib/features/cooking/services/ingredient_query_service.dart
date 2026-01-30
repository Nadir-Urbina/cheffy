import '../../../core/models/recipe_model.dart';

/// Service for answering ingredient-related questions during cooking
class IngredientQueryService {
  final Recipe recipe;

  IngredientQueryService(this.recipe);

  /// Process a voice query and return an answer
  /// Returns null if the query couldn't be understood
  String? answerQuery(String query) {
    final lowerQuery = query.toLowerCase().trim();
    
    // Check for "how much" or "how many" questions
    if (lowerQuery.contains('how much') || lowerQuery.contains('how many')) {
      return _answerHowMuchQuery(lowerQuery);
    }
    
    // Check for "what" questions about ingredients
    if (lowerQuery.contains('what') && 
        (lowerQuery.contains('ingredient') || lowerQuery.contains('need'))) {
      return _listIngredients();
    }
    
    // Check for specific ingredient mention
    for (final ingredient in recipe.ingredients) {
      final ingredientName = ingredient.name.toLowerCase();
      if (lowerQuery.contains(ingredientName)) {
        return _formatIngredientAnswer(ingredient);
      }
    }
    
    // Try fuzzy matching for partial ingredient names
    final fuzzyMatch = _fuzzyMatchIngredient(lowerQuery);
    if (fuzzyMatch != null) {
      return _formatIngredientAnswer(fuzzyMatch);
    }
    
    return null;
  }

  /// Answer "how much [ingredient]" questions
  String? _answerHowMuchQuery(String query) {
    // Extract the ingredient being asked about
    for (final ingredient in recipe.ingredients) {
      final ingredientName = ingredient.name.toLowerCase();
      
      // Check various forms of the ingredient name
      final nameParts = ingredientName.split(' ');
      for (final part in nameParts) {
        if (part.length > 2 && query.contains(part)) {
          return _formatIngredientAnswer(ingredient);
        }
      }
      
      // Direct match
      if (query.contains(ingredientName)) {
        return _formatIngredientAnswer(ingredient);
      }
    }
    
    // Try fuzzy match
    final fuzzyMatch = _fuzzyMatchIngredient(query);
    if (fuzzyMatch != null) {
      return _formatIngredientAnswer(fuzzyMatch);
    }
    
    return "I couldn't find that ingredient in this recipe.";
  }

  /// Format an ingredient into a speakable answer
  String _formatIngredientAnswer(RecipeIngredient ingredient) {
    if (ingredient.quantity > 0) {
      final quantity = _formatQuantity(ingredient.quantity);
      if (ingredient.unit.isNotEmpty) {
        return "$quantity ${ingredient.unit} of ${ingredient.name}";
      } else {
        return "$quantity ${ingredient.name}";
      }
    }
    return ingredient.formatted;
  }

  /// Format quantity for speech (e.g., 2.5 -> "2 and a half")
  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    
    // Handle common fractions
    final whole = quantity.floor();
    final fraction = quantity - whole;
    
    String fractionStr = '';
    if ((fraction - 0.5).abs() < 0.01) {
      fractionStr = 'and a half';
    } else if ((fraction - 0.25).abs() < 0.01) {
      fractionStr = 'and a quarter';
    } else if ((fraction - 0.75).abs() < 0.01) {
      fractionStr = 'and three quarters';
    } else if ((fraction - 0.33).abs() < 0.05) {
      fractionStr = 'and a third';
    } else if ((fraction - 0.67).abs() < 0.05) {
      fractionStr = 'and two thirds';
    } else {
      // Just use decimal
      return quantity.toStringAsFixed(1);
    }
    
    if (whole > 0) {
      return '$whole $fractionStr';
    } else {
      return fractionStr.replaceFirst('and ', '');
    }
  }

  /// List all ingredients
  String _listIngredients() {
    if (recipe.ingredients.isEmpty) {
      return "This recipe doesn't have any ingredients listed.";
    }
    
    final count = recipe.ingredients.length;
    if (count == 1) {
      return "You need ${recipe.ingredients.first.formatted}";
    }
    
    return "You need $count ingredients: ${recipe.ingredients.map((i) => i.name).join(', ')}";
  }

  /// Fuzzy match an ingredient name from the query
  RecipeIngredient? _fuzzyMatchIngredient(String query) {
    // Common ingredient aliases/abbreviations
    final aliases = {
      'flour': ['all-purpose flour', 'all purpose flour', 'wheat flour', 'bread flour'],
      'sugar': ['granulated sugar', 'white sugar', 'caster sugar'],
      'butter': ['unsalted butter', 'salted butter'],
      'milk': ['whole milk', 'skim milk', '2% milk'],
      'egg': ['eggs', 'large egg', 'large eggs'],
      'oil': ['vegetable oil', 'olive oil', 'canola oil', 'cooking oil'],
      'salt': ['kosher salt', 'sea salt', 'table salt'],
      'pepper': ['black pepper', 'ground pepper', 'white pepper'],
      'garlic': ['garlic cloves', 'minced garlic', 'garlic powder'],
      'onion': ['onions', 'yellow onion', 'white onion', 'red onion'],
      'chicken': ['chicken breast', 'chicken thigh', 'chicken pieces'],
      'beef': ['ground beef', 'beef steak', 'beef chunks'],
    };
    
    // Check if query contains any alias
    for (final entry in aliases.entries) {
      if (query.contains(entry.key)) {
        // Find ingredient matching any of the aliases
        for (final alias in [entry.key, ...entry.value]) {
          for (final ingredient in recipe.ingredients) {
            if (ingredient.name.toLowerCase().contains(alias)) {
              return ingredient;
            }
          }
        }
      }
    }
    
    // Last resort: check if any ingredient name word appears in query
    for (final ingredient in recipe.ingredients) {
      final words = ingredient.name.toLowerCase().split(' ');
      for (final word in words) {
        if (word.length > 3 && query.contains(word)) {
          return ingredient;
        }
      }
    }
    
    return null;
  }

  /// Get suggestions for what users can ask
  List<String> getSuggestions() {
    if (recipe.ingredients.isEmpty) return [];
    
    final suggestions = <String>[];
    final sampleIngredients = recipe.ingredients.take(3).toList();
    
    for (final ing in sampleIngredients) {
      suggestions.add('How much ${ing.name}?');
    }
    
    suggestions.add('What ingredients do I need?');
    
    return suggestions;
  }
}

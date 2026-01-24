import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_preferences.dart';

/// Service for managing user preferences in Firestore
class PreferencesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reference to preferences collection
  CollectionReference<Map<String, dynamic>> get _preferencesCollection =>
      _firestore.collection('user_preferences');

  /// Get user preferences
  Future<UserPreferences?> getPreferences(String odUserId) async {
    try {
      final doc = await _preferencesCollection.doc(odUserId).get();
      if (doc.exists) {
        return UserPreferences.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting preferences: $e');
      return null;
    }
  }

  /// Create or update user preferences
  Future<void> savePreferences(UserPreferences preferences) async {
    try {
      await _preferencesCollection
          .doc(preferences.odUserId)
          .set(preferences.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving preferences: $e');
      rethrow;
    }
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding(String odUserId) async {
    final prefs = await getPreferences(odUserId);
    return prefs?.onboardingCompleted ?? false;
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding(String odUserId) async {
    await _preferencesCollection.doc(odUserId).update({
      'onboardingCompleted': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Record that user viewed a recipe
  Future<void> recordRecipeView(String odUserId, String recipeId, String? cuisineType) async {
    try {
      final docRef = _preferencesCollection.doc(odUserId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) return;
        
        final data = doc.data()!;
        final viewedRecipes = List<String>.from(data['viewedRecipeIds'] ?? []);
        final cuisineCount = Map<String, int>.from(data['cuisineInteractionCount'] ?? {});
        
        // Add recipe to viewed list (keep last 100)
        if (!viewedRecipes.contains(recipeId)) {
          viewedRecipes.add(recipeId);
          if (viewedRecipes.length > 100) {
            viewedRecipes.removeAt(0);
          }
        }
        
        // Increment cuisine count
        if (cuisineType != null) {
          cuisineCount[cuisineType] = (cuisineCount[cuisineType] ?? 0) + 1;
        }
        
        transaction.update(docRef, {
          'viewedRecipeIds': viewedRecipes,
          'cuisineInteractionCount': cuisineCount,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
    } catch (e) {
      debugPrint('Error recording recipe view: $e');
    }
  }

  /// Record that user cooked a recipe
  Future<void> recordRecipeCooked(
    String odUserId, 
    String recipeId, 
    String? cuisineType,
    List<String> ingredientsUsed,
  ) async {
    try {
      final docRef = _preferencesCollection.doc(odUserId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) return;
        
        final data = doc.data()!;
        final cookedRecipes = List<String>.from(data['cookedRecipeIds'] ?? []);
        final cuisineCount = Map<String, int>.from(data['cuisineInteractionCount'] ?? {});
        final ingredientCount = Map<String, int>.from(data['ingredientUsageCount'] ?? {});
        
        // Add recipe to cooked list
        if (!cookedRecipes.contains(recipeId)) {
          cookedRecipes.add(recipeId);
        }
        
        // Increment cuisine count (weighted more for cooked)
        if (cuisineType != null) {
          cuisineCount[cuisineType] = (cuisineCount[cuisineType] ?? 0) + 3;
        }
        
        // Increment ingredient counts
        for (final ingredient in ingredientsUsed) {
          final normalizedIngredient = ingredient.toLowerCase().trim();
          ingredientCount[normalizedIngredient] = 
              (ingredientCount[normalizedIngredient] ?? 0) + 1;
        }
        
        transaction.update(docRef, {
          'cookedRecipeIds': cookedRecipes,
          'cuisineInteractionCount': cuisineCount,
          'ingredientUsageCount': ingredientCount,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
    } catch (e) {
      debugPrint('Error recording recipe cooked: $e');
    }
  }

  /// Save/unsave a recipe
  Future<void> toggleSavedRecipe(String odUserId, String recipeId) async {
    try {
      final docRef = _preferencesCollection.doc(odUserId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) return;
        
        final data = doc.data()!;
        final savedRecipes = List<String>.from(data['savedRecipeIds'] ?? []);
        
        if (savedRecipes.contains(recipeId)) {
          savedRecipes.remove(recipeId);
        } else {
          savedRecipes.add(recipeId);
        }
        
        transaction.update(docRef, {
          'savedRecipeIds': savedRecipes,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
    } catch (e) {
      debugPrint('Error toggling saved recipe: $e');
    }
  }

  /// Get top cuisines based on user interactions
  List<CuisineType> getTopCuisines(UserPreferences prefs, {int limit = 3}) {
    if (prefs.cuisineInteractionCount.isEmpty) {
      return prefs.favoriteCuisines.take(limit).toList();
    }
    
    final sorted = prefs.cuisineInteractionCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted
        .take(limit)
        .map((e) => CuisineType.values.firstWhere(
              (c) => c.name == e.key,
              orElse: () => CuisineType.american,
            ))
        .toList();
  }

  /// Get frequently used ingredients
  List<String> getFrequentIngredients(UserPreferences prefs, {int limit = 10}) {
    if (prefs.ingredientUsageCount.isEmpty) return [];
    
    final sorted = prefs.ingredientUsageCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Save preferred Instacart retailer
  Future<void> savePreferredRetailer({
    required String odUserId,
    required String retailerId,
    required String retailerName,
    required String postalCode,
  }) async {
    try {
      await _preferencesCollection.doc(odUserId).update({
        'preferredRetailerId': retailerId,
        'preferredRetailerName': retailerName,
        'postalCode': postalCode,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      debugPrint('✅ Saved preferred retailer: $retailerName');
    } catch (e) {
      debugPrint('Error saving preferred retailer: $e');
      rethrow;
    }
  }

  /// Clear preferred retailer
  Future<void> clearPreferredRetailer(String odUserId) async {
    try {
      await _preferencesCollection.doc(odUserId).update({
        'preferredRetailerId': null,
        'preferredRetailerName': null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error clearing preferred retailer: $e');
    }
  }

  /// Get saved postal code for retailer search
  Future<String?> getSavedPostalCode(String odUserId) async {
    final prefs = await getPreferences(odUserId);
    return prefs?.postalCode;
  }
}

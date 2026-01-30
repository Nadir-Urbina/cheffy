import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/cooked_recipe.dart';
import '../models/recipe_model.dart';

/// Service for managing user's cooked recipe history
class RecipeHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reference to cooked recipes collection
  CollectionReference<Map<String, dynamic>> get _cookedRecipesCollection =>
      _firestore.collection('cooked_recipes');

  /// Save a recipe to the user's cooking history
  Future<CookedRecipe?> saveToHistory({
    required String odUserId,
    required Recipe recipe,
    int? rating,
    String? notes,
  }) async {
    try {
      final cookedRecipe = CookedRecipe(
        id: '', // Will be set by Firestore
        odUserId: odUserId,
        recipe: recipe,
        cookedAt: DateTime.now(),
        rating: rating,
        notes: notes,
      );

      final docRef = await _cookedRecipesCollection.add(cookedRecipe.toFirestore());
      
      debugPrint('✅ Recipe saved to history: ${recipe.name}');
      
      return cookedRecipe.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ Error saving to history: $e');
      return null;
    }
  }

  /// Get user's cooking history (most recent first)
  Future<List<CookedRecipe>> getHistory(String odUserId, {int limit = 50}) async {
    try {
      final snapshot = await _cookedRecipesCollection
          .where('odUserId', isEqualTo: odUserId)
          .orderBy('cookedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CookedRecipe.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting history: $e');
      return [];
    }
  }

  /// Get history as a stream for real-time updates
  Stream<List<CookedRecipe>> historyStream(String odUserId, {int limit = 50}) {
    return _cookedRecipesCollection
        .where('odUserId', isEqualTo: odUserId)
        .orderBy('cookedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CookedRecipe.fromFirestore(doc))
            .toList());
  }

  /// Check if a recipe has been cooked before
  Future<bool> hasCooked(String odUserId, String recipeId) async {
    try {
      final snapshot = await _cookedRecipesCollection
          .where('odUserId', isEqualTo: odUserId)
          .where('recipeId', isEqualTo: recipeId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking cooked status: $e');
      return false;
    }
  }

  /// Get how many times a recipe has been cooked
  Future<int> getTimesCooked(String odUserId, String recipeId) async {
    try {
      final snapshot = await _cookedRecipesCollection
          .where('odUserId', isEqualTo: odUserId)
          .where('recipeId', isEqualTo: recipeId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting times cooked: $e');
      return 0;
    }
  }

  /// Update rating for a cooked recipe
  Future<void> updateRating(String cookedRecipeId, int rating) async {
    try {
      await _cookedRecipesCollection.doc(cookedRecipeId).update({
        'rating': rating,
      });
    } catch (e) {
      debugPrint('Error updating rating: $e');
    }
  }

  /// Update notes for a cooked recipe
  Future<void> updateNotes(String cookedRecipeId, String notes) async {
    try {
      await _cookedRecipesCollection.doc(cookedRecipeId).update({
        'notes': notes,
      });
    } catch (e) {
      debugPrint('Error updating notes: $e');
    }
  }

  /// Delete a cooked recipe from history
  Future<void> deleteFromHistory(String cookedRecipeId) async {
    try {
      await _cookedRecipesCollection.doc(cookedRecipeId).delete();
    } catch (e) {
      debugPrint('Error deleting from history: $e');
    }
  }

  /// Get total recipes cooked count
  Future<int> getTotalCookedCount(String odUserId) async {
    try {
      final snapshot = await _cookedRecipesCollection
          .where('odUserId', isEqualTo: odUserId)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting total count: $e');
      return 0;
    }
  }

  /// Get recently cooked recipes (last 7 days)
  Future<List<CookedRecipe>> getRecentlyCooked(String odUserId) async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await _cookedRecipesCollection
          .where('odUserId', isEqualTo: odUserId)
          .where('cookedAt', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .orderBy('cookedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => CookedRecipe.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent recipes: $e');
      return [];
    }
  }
}

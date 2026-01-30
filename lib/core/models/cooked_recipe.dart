import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_model.dart';

/// A recipe that has been cooked by the user
class CookedRecipe {
  final String id;
  final String odUserId;
  final Recipe recipe;
  final DateTime cookedAt;
  final int? rating; // 1-5 stars (optional)
  final String? notes; // User notes about the cooking experience

  CookedRecipe({
    required this.id,
    required this.odUserId,
    required this.recipe,
    required this.cookedAt,
    this.rating,
    this.notes,
  });

  factory CookedRecipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CookedRecipe(
      id: doc.id,
      odUserId: data['odUserId'] as String,
      recipe: Recipe.fromJson(data['recipe'] as Map<String, dynamic>),
      cookedAt: (data['cookedAt'] as Timestamp).toDate(),
      rating: data['rating'] as int?,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'odUserId': odUserId,
      'recipe': recipe.toJson(),
      'cookedAt': Timestamp.fromDate(cookedAt),
      'rating': rating,
      'notes': notes,
      'recipeId': recipe.id,
      'recipeName': recipe.name, // For easier querying
    };
  }

  CookedRecipe copyWith({
    String? id,
    String? odUserId,
    Recipe? recipe,
    DateTime? cookedAt,
    int? rating,
    String? notes,
  }) {
    return CookedRecipe(
      id: id ?? this.id,
      odUserId: odUserId ?? this.odUserId,
      recipe: recipe ?? this.recipe,
      cookedAt: cookedAt ?? this.cookedAt,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
    );
  }
}

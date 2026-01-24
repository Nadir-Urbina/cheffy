import 'package:cloud_firestore/cloud_firestore.dart';

/// User dietary restrictions
enum DietaryRestriction {
  none,
  vegetarian,
  vegan,
  pescatarian,
  glutenFree,
  dairyFree,
  keto,
  paleo,
  halal,
  kosher,
}

/// Cuisine types
enum CuisineType {
  american,
  mexican,
  italian,
  chinese,
  japanese,
  indian,
  thai,
  mediterranean,
  french,
  korean,
  vietnamese,
  middleEastern,
  greek,
  spanish,
  caribbean,
}

/// Cooking skill level
enum CookingSkillLevel {
  beginner,
  intermediate,
  advanced,
}

/// Time preference for cooking
enum CookingTimePreference {
  quick, // Under 20 min
  moderate, // 20-45 min
  leisurely, // 45+ min
}

/// User preferences model - stored in Firestore
class UserPreferences {
  final String odUserId;
  final List<DietaryRestriction> dietaryRestrictions;
  final List<String> allergies;
  final List<CuisineType> favoriteCuisines;
  final List<CuisineType> dislikedCuisines;
  final CookingSkillLevel skillLevel;
  final CookingTimePreference timePreference;
  final int householdSize;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Behavioral data (grows over time)
  final List<String> viewedRecipeIds;
  final List<String> cookedRecipeIds;
  final List<String> savedRecipeIds;
  final Map<String, int> cuisineInteractionCount; // cuisine -> count
  final Map<String, int> ingredientUsageCount; // ingredient -> count

  // Instacart preferences
  final String? preferredRetailerId;
  final String? preferredRetailerName;
  final String? postalCode;

  UserPreferences({
    required this.odUserId,
    this.dietaryRestrictions = const [],
    this.allergies = const [],
    this.favoriteCuisines = const [],
    this.dislikedCuisines = const [],
    this.skillLevel = CookingSkillLevel.beginner,
    this.timePreference = CookingTimePreference.moderate,
    this.householdSize = 2,
    this.onboardingCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.viewedRecipeIds = const [],
    this.cookedRecipeIds = const [],
    this.savedRecipeIds = const [],
    this.cuisineInteractionCount = const {},
    this.ingredientUsageCount = const {},
    this.preferredRetailerId,
    this.preferredRetailerName,
    this.postalCode,
  });

  /// Create default preferences for new user
  factory UserPreferences.newUser(String odUserId) {
    final now = DateTime.now();
    return UserPreferences(
      odUserId: odUserId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create from Firestore document
  factory UserPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserPreferences(
      odUserId: doc.id,
      dietaryRestrictions: (data['dietaryRestrictions'] as List<dynamic>?)
              ?.map((e) => DietaryRestriction.values.firstWhere(
                    (r) => r.name == e,
                    orElse: () => DietaryRestriction.none,
                  ))
              .toList() ??
          [],
      allergies: List<String>.from(data['allergies'] ?? []),
      favoriteCuisines: (data['favoriteCuisines'] as List<dynamic>?)
              ?.map((e) => CuisineType.values.firstWhere(
                    (c) => c.name == e,
                    orElse: () => CuisineType.american,
                  ))
              .toList() ??
          [],
      dislikedCuisines: (data['dislikedCuisines'] as List<dynamic>?)
              ?.map((e) => CuisineType.values.firstWhere(
                    (c) => c.name == e,
                    orElse: () => CuisineType.american,
                  ))
              .toList() ??
          [],
      skillLevel: CookingSkillLevel.values.firstWhere(
        (s) => s.name == data['skillLevel'],
        orElse: () => CookingSkillLevel.beginner,
      ),
      timePreference: CookingTimePreference.values.firstWhere(
        (t) => t.name == data['timePreference'],
        orElse: () => CookingTimePreference.moderate,
      ),
      householdSize: data['householdSize'] ?? 2,
      onboardingCompleted: data['onboardingCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      viewedRecipeIds: List<String>.from(data['viewedRecipeIds'] ?? []),
      cookedRecipeIds: List<String>.from(data['cookedRecipeIds'] ?? []),
      savedRecipeIds: List<String>.from(data['savedRecipeIds'] ?? []),
      cuisineInteractionCount:
          Map<String, int>.from(data['cuisineInteractionCount'] ?? {}),
      ingredientUsageCount:
          Map<String, int>.from(data['ingredientUsageCount'] ?? {}),
      preferredRetailerId: data['preferredRetailerId'] as String?,
      preferredRetailerName: data['preferredRetailerName'] as String?,
      postalCode: data['postalCode'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'dietaryRestrictions': dietaryRestrictions.map((e) => e.name).toList(),
      'allergies': allergies,
      'favoriteCuisines': favoriteCuisines.map((e) => e.name).toList(),
      'dislikedCuisines': dislikedCuisines.map((e) => e.name).toList(),
      'skillLevel': skillLevel.name,
      'timePreference': timePreference.name,
      'householdSize': householdSize,
      'onboardingCompleted': onboardingCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'viewedRecipeIds': viewedRecipeIds,
      'cookedRecipeIds': cookedRecipeIds,
      'savedRecipeIds': savedRecipeIds,
      'cuisineInteractionCount': cuisineInteractionCount,
      'ingredientUsageCount': ingredientUsageCount,
      'preferredRetailerId': preferredRetailerId,
      'preferredRetailerName': preferredRetailerName,
      'postalCode': postalCode,
    };
  }

  /// Copy with updated fields
  UserPreferences copyWith({
    List<DietaryRestriction>? dietaryRestrictions,
    List<String>? allergies,
    List<CuisineType>? favoriteCuisines,
    List<CuisineType>? dislikedCuisines,
    CookingSkillLevel? skillLevel,
    CookingTimePreference? timePreference,
    int? householdSize,
    bool? onboardingCompleted,
    List<String>? viewedRecipeIds,
    List<String>? cookedRecipeIds,
    List<String>? savedRecipeIds,
    Map<String, int>? cuisineInteractionCount,
    Map<String, int>? ingredientUsageCount,
    String? preferredRetailerId,
    String? preferredRetailerName,
    String? postalCode,
  }) {
    return UserPreferences(
      odUserId: odUserId,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      allergies: allergies ?? this.allergies,
      favoriteCuisines: favoriteCuisines ?? this.favoriteCuisines,
      dislikedCuisines: dislikedCuisines ?? this.dislikedCuisines,
      skillLevel: skillLevel ?? this.skillLevel,
      timePreference: timePreference ?? this.timePreference,
      householdSize: householdSize ?? this.householdSize,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      viewedRecipeIds: viewedRecipeIds ?? this.viewedRecipeIds,
      cookedRecipeIds: cookedRecipeIds ?? this.cookedRecipeIds,
      savedRecipeIds: savedRecipeIds ?? this.savedRecipeIds,
      cuisineInteractionCount:
          cuisineInteractionCount ?? this.cuisineInteractionCount,
      ingredientUsageCount: ingredientUsageCount ?? this.ingredientUsageCount,
      preferredRetailerId: preferredRetailerId ?? this.preferredRetailerId,
      preferredRetailerName: preferredRetailerName ?? this.preferredRetailerName,
      postalCode: postalCode ?? this.postalCode,
    );
  }

  /// Check if a preferred retailer is set
  bool get hasPreferredRetailer => preferredRetailerId != null;
}

/// Extension for display names
extension DietaryRestrictionExtension on DietaryRestriction {
  String get displayName {
    switch (this) {
      case DietaryRestriction.none:
        return 'No restrictions';
      case DietaryRestriction.vegetarian:
        return 'Vegetarian';
      case DietaryRestriction.vegan:
        return 'Vegan';
      case DietaryRestriction.pescatarian:
        return 'Pescatarian';
      case DietaryRestriction.glutenFree:
        return 'Gluten-Free';
      case DietaryRestriction.dairyFree:
        return 'Dairy-Free';
      case DietaryRestriction.keto:
        return 'Keto';
      case DietaryRestriction.paleo:
        return 'Paleo';
      case DietaryRestriction.halal:
        return 'Halal';
      case DietaryRestriction.kosher:
        return 'Kosher';
    }
  }

  String get emoji {
    switch (this) {
      case DietaryRestriction.none:
        return '✓';
      case DietaryRestriction.vegetarian:
        return '🥬';
      case DietaryRestriction.vegan:
        return '🌱';
      case DietaryRestriction.pescatarian:
        return '🐟';
      case DietaryRestriction.glutenFree:
        return '🌾';
      case DietaryRestriction.dairyFree:
        return '🥛';
      case DietaryRestriction.keto:
        return '🥑';
      case DietaryRestriction.paleo:
        return '🍖';
      case DietaryRestriction.halal:
        return '☪️';
      case DietaryRestriction.kosher:
        return '✡️';
    }
  }
}

extension CuisineTypeExtension on CuisineType {
  String get displayName {
    switch (this) {
      case CuisineType.american:
        return 'American';
      case CuisineType.mexican:
        return 'Mexican';
      case CuisineType.italian:
        return 'Italian';
      case CuisineType.chinese:
        return 'Chinese';
      case CuisineType.japanese:
        return 'Japanese';
      case CuisineType.indian:
        return 'Indian';
      case CuisineType.thai:
        return 'Thai';
      case CuisineType.mediterranean:
        return 'Mediterranean';
      case CuisineType.french:
        return 'French';
      case CuisineType.korean:
        return 'Korean';
      case CuisineType.vietnamese:
        return 'Vietnamese';
      case CuisineType.middleEastern:
        return 'Middle Eastern';
      case CuisineType.greek:
        return 'Greek';
      case CuisineType.spanish:
        return 'Spanish';
      case CuisineType.caribbean:
        return 'Caribbean';
    }
  }

  String get emoji {
    switch (this) {
      case CuisineType.american:
        return '🍔';
      case CuisineType.mexican:
        return '🌮';
      case CuisineType.italian:
        return '🍝';
      case CuisineType.chinese:
        return '🥡';
      case CuisineType.japanese:
        return '🍣';
      case CuisineType.indian:
        return '🍛';
      case CuisineType.thai:
        return '🍜';
      case CuisineType.mediterranean:
        return '🫒';
      case CuisineType.french:
        return '🥐';
      case CuisineType.korean:
        return '🍲';
      case CuisineType.vietnamese:
        return '🍲';
      case CuisineType.middleEastern:
        return '🧆';
      case CuisineType.greek:
        return '🥙';
      case CuisineType.spanish:
        return '🥘';
      case CuisineType.caribbean:
        return '🍹';
    }
  }
}

extension CookingSkillLevelExtension on CookingSkillLevel {
  String get displayName {
    switch (this) {
      case CookingSkillLevel.beginner:
        return 'Beginner';
      case CookingSkillLevel.intermediate:
        return 'Intermediate';
      case CookingSkillLevel.advanced:
        return 'Advanced';
    }
  }

  String get description {
    switch (this) {
      case CookingSkillLevel.beginner:
        return 'I\'m just starting out';
      case CookingSkillLevel.intermediate:
        return 'I can follow most recipes';
      case CookingSkillLevel.advanced:
        return 'I love a challenge';
    }
  }

  String get emoji {
    switch (this) {
      case CookingSkillLevel.beginner:
        return '🌱';
      case CookingSkillLevel.intermediate:
        return '👨‍🍳';
      case CookingSkillLevel.advanced:
        return '⭐';
    }
  }
}

extension CookingTimePreferenceExtension on CookingTimePreference {
  String get displayName {
    switch (this) {
      case CookingTimePreference.quick:
        return 'Quick & Easy';
      case CookingTimePreference.moderate:
        return 'Moderate';
      case CookingTimePreference.leisurely:
        return 'Leisurely';
    }
  }

  String get description {
    switch (this) {
      case CookingTimePreference.quick:
        return 'Under 20 minutes';
      case CookingTimePreference.moderate:
        return '20-45 minutes';
      case CookingTimePreference.leisurely:
        return '45+ minutes';
    }
  }

  String get emoji {
    switch (this) {
      case CookingTimePreference.quick:
        return '⚡';
      case CookingTimePreference.moderate:
        return '⏱️';
      case CookingTimePreference.leisurely:
        return '🍷';
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_model.dart';

/// A meal scheduled for a specific date
class ScheduledMeal {
  final String id;
  final String odUserId;
  final Recipe recipe;
  final DateTime scheduledDate;
  final MealType mealType;
  final bool reminderEnabled;
  final DateTime? reminderTime; // When to send the reminder
  final String? notes;
  final DateTime createdAt;

  ScheduledMeal({
    required this.id,
    required this.odUserId,
    required this.recipe,
    required this.scheduledDate,
    this.mealType = MealType.dinner,
    this.reminderEnabled = false,
    this.reminderTime,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ScheduledMeal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduledMeal(
      id: doc.id,
      odUserId: data['odUserId'] as String,
      recipe: Recipe.fromJson(data['recipe'] as Map<String, dynamic>),
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      mealType: MealType.values.firstWhere(
        (e) => e.name == data['mealType'],
        orElse: () => MealType.dinner,
      ),
      reminderEnabled: data['reminderEnabled'] as bool? ?? false,
      reminderTime: data['reminderTime'] != null
          ? (data['reminderTime'] as Timestamp).toDate()
          : null,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'odUserId': odUserId,
      'recipe': recipe.toJson(),
      'recipeId': recipe.id,
      'recipeName': recipe.name,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'mealType': mealType.name,
      'reminderEnabled': reminderEnabled,
      'reminderTime': reminderTime != null 
          ? Timestamp.fromDate(reminderTime!) 
          : null,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ScheduledMeal copyWith({
    String? id,
    String? odUserId,
    Recipe? recipe,
    DateTime? scheduledDate,
    MealType? mealType,
    bool? reminderEnabled,
    DateTime? reminderTime,
    String? notes,
    DateTime? createdAt,
  }) {
    return ScheduledMeal(
      id: id ?? this.id,
      odUserId: odUserId ?? this.odUserId,
      recipe: recipe ?? this.recipe,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      mealType: mealType ?? this.mealType,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get the date portion only (no time) for grouping
  DateTime get dateOnly => DateTime(
    scheduledDate.year,
    scheduledDate.month,
    scheduledDate.day,
  );

  /// Check if scheduled for today
  bool get isToday {
    final now = DateTime.now();
    return scheduledDate.year == now.year &&
        scheduledDate.month == now.month &&
        scheduledDate.day == now.day;
  }

  /// Check if the meal is in the past
  bool get isPast => scheduledDate.isBefore(DateTime.now());
}

/// Type of meal for scheduling
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
    }
  }

  String get emoji {
    switch (this) {
      case MealType.breakfast:
        return '🌅';
      case MealType.lunch:
        return '☀️';
      case MealType.dinner:
        return '🌙';
      case MealType.snack:
        return '🍿';
    }
  }

  String get svgPath {
    switch (this) {
      case MealType.breakfast:
        return 'assets/icons/meal_type_svgs/breakfast.svg';
      case MealType.lunch:
        return 'assets/icons/meal_type_svgs/lunch.svg';
      case MealType.dinner:
        return 'assets/icons/meal_type_svgs/dinner.svg';
      case MealType.snack:
        return 'assets/icons/meal_type_svgs/snack.svg';
    }
  }
}

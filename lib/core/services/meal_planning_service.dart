import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/recipe_model.dart';
import '../models/scheduled_meal.dart';

/// Service for managing meal planning and scheduling
class MealPlanningService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reference to scheduled meals collection
  CollectionReference<Map<String, dynamic>> get _scheduledMealsCollection =>
      _firestore.collection('scheduled_meals');

  /// Schedule a meal for a specific date
  Future<ScheduledMeal?> scheduleMeal({
    required String odUserId,
    required Recipe recipe,
    required DateTime scheduledDate,
    MealType mealType = MealType.dinner,
    bool reminderEnabled = false,
    String? notes,
  }) async {
    try {
      // Calculate reminder time (24 hours before the meal)
      DateTime? reminderTime;
      if (reminderEnabled) {
        reminderTime = scheduledDate.subtract(const Duration(hours: 24));
        // If the reminder would be in the past, set it to now + 1 hour
        if (reminderTime.isBefore(DateTime.now())) {
          reminderTime = DateTime.now().add(const Duration(hours: 1));
        }
      }

      final scheduledMeal = ScheduledMeal(
        id: '',
        odUserId: odUserId,
        recipe: recipe,
        scheduledDate: scheduledDate,
        mealType: mealType,
        reminderEnabled: reminderEnabled,
        reminderTime: reminderTime,
        notes: notes,
      );

      final docRef = await _scheduledMealsCollection.add(scheduledMeal.toFirestore());
      
      debugPrint('✅ Meal scheduled: ${recipe.name} for ${scheduledDate.toLocal()}');
      
      return scheduledMeal.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ Error scheduling meal: $e');
      return null;
    }
  }

  /// Get all scheduled meals for a user within a date range
  Future<List<ScheduledMeal>> getScheduledMeals(
    String odUserId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _scheduledMealsCollection
          .where('odUserId', isEqualTo: odUserId);

      if (startDate != null) {
        query = query.where(
          'scheduledDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'scheduledDate',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      query = query.orderBy('scheduledDate', descending: false);

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => ScheduledMeal.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting scheduled meals: $e');
      return [];
    }
  }

  /// Stream of scheduled meals for real-time updates
  Stream<List<ScheduledMeal>> scheduledMealsStream(
    String odUserId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query<Map<String, dynamic>> query = _scheduledMealsCollection
        .where('odUserId', isEqualTo: odUserId);

    if (startDate != null) {
      query = query.where(
        'scheduledDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'scheduledDate',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    query = query.orderBy('scheduledDate', descending: false);

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ScheduledMeal.fromFirestore(doc)).toList());
  }

  /// Get meals scheduled for a specific date
  Future<List<ScheduledMeal>> getMealsForDate(
    String odUserId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getScheduledMeals(
      odUserId,
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// Get upcoming meals (next 7 days)
  Future<List<ScheduledMeal>> getUpcomingMeals(String odUserId) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endDate = startOfToday.add(const Duration(days: 7));

    return getScheduledMeals(
      odUserId,
      startDate: startOfToday,
      endDate: endDate,
    );
  }

  /// Get today's meals
  Future<List<ScheduledMeal>> getTodaysMeals(String odUserId) async {
    final now = DateTime.now();
    return getMealsForDate(odUserId, now);
  }

  /// Update a scheduled meal
  Future<bool> updateScheduledMeal(ScheduledMeal meal) async {
    try {
      await _scheduledMealsCollection.doc(meal.id).update(meal.toFirestore());
      debugPrint('✅ Meal updated: ${meal.recipe.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating meal: $e');
      return false;
    }
  }

  /// Delete a scheduled meal
  Future<bool> deleteScheduledMeal(String mealId) async {
    try {
      await _scheduledMealsCollection.doc(mealId).delete();
      debugPrint('✅ Meal deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting meal: $e');
      return false;
    }
  }

  /// Check if a recipe has any upcoming scheduled meals
  Future<bool> isRecipeScheduled(String odUserId, String recipeId) async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final snapshot = await _scheduledMealsCollection
          .where('odUserId', isEqualTo: odUserId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .get();

      return snapshot.docs.any((doc) {
        final data = doc.data();
        final recipeData = data['recipe'] as Map<String, dynamic>?;
        return recipeData?['id']?.toString() == recipeId;
      });
    } catch (e) {
      debugPrint('❌ Error checking recipe schedule: $e');
      return false;
    }
  }

  /// Check if a recipe is already scheduled for a specific date
  Future<bool> isRecipeScheduledForDate(
    String odUserId,
    String recipeId,
    DateTime date,
  ) async {
    final meals = await getMealsForDate(odUserId, date);
    return meals.any((meal) => meal.recipe.id == recipeId);
  }

  /// Get meals with pending reminders
  Future<List<ScheduledMeal>> getMealsWithPendingReminders(
    String odUserId,
  ) async {
    try {
      final now = DateTime.now();
      
      final snapshot = await _scheduledMealsCollection
          .where('odUserId', isEqualTo: odUserId)
          .where('reminderEnabled', isEqualTo: true)
          .where('reminderTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('reminderTime')
          .get();

      return snapshot.docs
          .map((doc) => ScheduledMeal.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting pending reminders: $e');
      return [];
    }
  }

  /// Get dates that have scheduled meals (for calendar markers)
  Future<Set<DateTime>> getScheduledDates(
    String odUserId, {
    required DateTime month,
  }) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final meals = await getScheduledMeals(
      odUserId,
      startDate: startOfMonth,
      endDate: endOfMonth,
    );

    return meals.map((meal) => meal.dateOnly).toSet();
  }
}

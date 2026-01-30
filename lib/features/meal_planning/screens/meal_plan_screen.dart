import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/scheduled_meal.dart';
import '../../../core/services/meal_planning_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../scan/screens/recipe_results_screen.dart' show RecipeDetailScreen;

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  final _mealPlanningService = MealPlanningService();
  
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  List<ScheduledMeal> _allMeals = [];
  Set<DateTime> _scheduledDates = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Load meals for the current month view (with buffer for prev/next month days shown)
      final startOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      final endOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 2, 0);

      final meals = await _mealPlanningService.getScheduledMeals(
        user.uid,
        startDate: startOfMonth,
        endDate: endOfMonth,
      );

      final scheduledDates = await _mealPlanningService.getScheduledDates(
        user.uid,
        month: _focusedMonth,
      );

      if (mounted) {
        setState(() {
          _allMeals = meals;
          _scheduledDates = scheduledDates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ScheduledMeal> get _mealsForSelectedDate {
    return _allMeals.where((meal) => _isSameDay(meal.scheduledDate, _selectedDate)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Meal Plan',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Calendar
          _buildCalendar(),
          const Divider(height: 1),
          // Selected date header
          _buildSelectedDateHeader(),
          // Meals for selected date
          Expanded(
            child: _buildMealsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  });
                  _loadMeals();
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                  });
                  _loadMeals();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Day of week headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar grid
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0
    final daysInMonth = lastDayOfMonth.day;

    final today = DateTime.now();
    final List<Widget> dayWidgets = [];

    // Empty cells for days before the first of the month
    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final isSelected = _isSameDay(date, _selectedDate);
      final isToday = _isSameDay(date, today);
      final hasMeals = _scheduledDates.any((d) => _isSameDay(d, date));
      final isPast = date.isBefore(DateTime(today.year, today.month, today.day));

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedDate = date);
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : isPast
                            ? AppColors.textHint
                            : AppColors.textPrimary,
                  ),
                ),
                if (hasMeals)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: dayWidgets,
    );
  }

  Widget _buildSelectedDateHeader() {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday ? 'Today' : DateFormat('EEEE').format(_selectedDate),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                DateFormat('MMMM d, y').format(_selectedDate),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_mealsForSelectedDate.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_mealsForSelectedDate.length} meal${_mealsForSelectedDate.length > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMealsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final meals = _mealsForSelectedDate;

    if (meals.isEmpty) {
      return _buildEmptyState();
    }

    // Group meals by type
    final mealsByType = <MealType, List<ScheduledMeal>>{};
    for (final meal in meals) {
      mealsByType.putIfAbsent(meal.mealType, () => []).add(meal);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final type in MealType.values)
          if (mealsByType.containsKey(type)) ...[
            _buildMealTypeSection(type, mealsByType[type]!),
            const SizedBox(height: 16),
          ],
      ],
    );
  }

  Widget _buildMealTypeSection(MealType type, List<ScheduledMeal> meals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              type.emoji,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Text(
              type.displayName,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...meals.map((meal) => _MealCard(
              meal: meal,
              onTap: () => _showRecipeDetail(meal),
              onDelete: () => _deleteMeal(meal),
            )),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isPast = _selectedDate.isBefore(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPast ? Icons.history : Icons.restaurant_menu,
                size: 40,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPast ? 'No meals logged' : 'No meals planned',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPast
                  ? 'No meals were scheduled for this day'
                  : 'Tap the calendar icon on any recipe to plan it',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecipeDetail(ScheduledMeal meal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: meal.recipe),
      ),
    );
  }

  Future<void> _deleteMeal(ScheduledMeal meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove from plan?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will remove "${meal.recipe.name}" from your meal plan.',
          style: GoogleFonts.poppins(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _mealPlanningService.deleteScheduledMeal(meal.id);
      _loadMeals();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meal removed from plan'),
            backgroundColor: AppColors.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// Card for displaying a scheduled meal
class _MealCard extends StatelessWidget {
  final ScheduledMeal meal;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MealCard({
    required this.meal,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Recipe image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: meal.recipe.imageUrl != null
                  ? Image.network(
                      meal.recipe.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),
            const SizedBox(width: 12),
            // Recipe info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.recipe.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        meal.recipe.totalTimeFormatted,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (meal.reminderEnabled) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.notifications_active,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reminder on',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Delete button
            IconButton(
              icon: Icon(
                Icons.close,
                size: 20,
                color: AppColors.textHint,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: AppColors.primaryLight.withValues(alpha: 0.2),
      child: Icon(
        Icons.restaurant,
        color: AppColors.primary.withValues(alpha: 0.5),
      ),
    );
  }
}

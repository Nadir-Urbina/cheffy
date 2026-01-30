import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/recipe_model.dart';
import '../../../core/models/scheduled_meal.dart';
import '../../../core/services/meal_planning_service.dart';
import '../../../core/theme/app_colors.dart';

/// Bottom sheet for scheduling a meal
class ScheduleMealSheet extends StatefulWidget {
  final Recipe recipe;

  const ScheduleMealSheet({super.key, required this.recipe});

  /// Show the schedule meal sheet
  static Future<ScheduledMeal?> show(BuildContext context, Recipe recipe) {
    return showModalBottomSheet<ScheduledMeal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleMealSheet(recipe: recipe),
    );
  }

  @override
  State<ScheduleMealSheet> createState() => _ScheduleMealSheetState();
}

class _ScheduleMealSheetState extends State<ScheduleMealSheet> {
  final _mealPlanningService = MealPlanningService();
  
  DateTime _selectedDate = DateTime.now();
  MealType _selectedMealType = MealType.dinner;
  bool _reminderEnabled = true;
  bool _isScheduling = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule Meal',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.recipe.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Date selector
              Text(
                'Select Date',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildDateSelector(),
              const SizedBox(height: 24),
              // Meal type selector
              Text(
                'Meal Type',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildMealTypeSelector(),
              const SizedBox(height: 24),
              // Reminder toggle
              _buildReminderToggle(),
              const SizedBox(height: 24),
              // Schedule button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isScheduling ? null : _scheduleMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isScheduling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          'Add to Meal Plan',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    // Show next 7 days as quick select + custom date picker
    final today = DateTime.now();
    final quickDates = List.generate(7, (i) => today.add(Duration(days: i)));

    return Column(
      children: [
        // Quick date buttons
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: quickDates.length + 1, // +1 for "More" button
            itemBuilder: (context, index) {
              if (index == quickDates.length) {
                // "More" button for custom date
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: _selectCustomDate,
                    child: Container(
                      width: 60,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textHint.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.more_horiz,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'More',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final date = quickDates[index];
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = index == 0;

              return Padding(
                padding: EdgeInsets.only(right: index < quickDates.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDate = date);
                  },
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primary 
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? AppColors.primary 
                            : AppColors.textHint.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isToday ? 'Today' : DateFormat('EEE').format(date),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isSelected 
                                ? Colors.white.withValues(alpha: 0.8) 
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('d').format(date),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected 
                                ? Colors.white 
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(date),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isSelected 
                                ? Colors.white.withValues(alpha: 0.8) 
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Show selected date if it's not in the quick dates
        if (!quickDates.any((d) => _isSameDay(d, _selectedDate))) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _selectCustomDate,
                  child: Icon(
                    Icons.edit,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMealTypeSelector() {
    return Row(
      children: MealType.values.map((type) {
        final isSelected = type == _selectedMealType;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type != MealType.values.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedMealType = type);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.primary 
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? AppColors.primary 
                        : AppColors.textHint.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    SvgPicture.asset(
                      type.svgPath,
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(
                        isSelected ? Colors.white : AppColors.textSecondary,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      type.displayName,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isSelected 
                            ? Colors.white 
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReminderToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _reminderEnabled 
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.notifications_active,
              color: _reminderEnabled 
                  ? AppColors.primary 
                  : AppColors.textHint,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '24-hour Reminder',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Get notified to prep ingredients',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _reminderEnabled,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _reminderEnabled = value);
            },
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Future<void> _selectCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _scheduleMeal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isScheduling = true);

    try {
      final scheduledMeal = await _mealPlanningService.scheduleMeal(
        odUserId: user.uid,
        recipe: widget.recipe,
        scheduledDate: _selectedDate,
        mealType: _selectedMealType,
        reminderEnabled: _reminderEnabled,
      );

      if (scheduledMeal != null && mounted) {
        Navigator.pop(context, scheduledMeal);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Meal scheduled for ${DateFormat('EEEE, MMM d').format(_selectedDate)}',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule meal: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScheduling = false);
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

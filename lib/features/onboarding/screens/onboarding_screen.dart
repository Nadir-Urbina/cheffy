import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  final String odUserId;
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.odUserId,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _preferencesService = PreferencesService();
  final _pageController = PageController();
  
  int _currentPage = 0;
  bool _isLoading = false;

  // User selections
  List<DietaryRestriction> _selectedDiets = [];
  List<String> _allergies = [];
  List<CuisineType> _selectedCuisines = [];
  CookingSkillLevel _skillLevel = CookingSkillLevel.beginner;
  CookingTimePreference _timePreference = CookingTimePreference.moderate;
  int _householdSize = 2;

  final _allergyController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _allergyController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);

    try {
      final preferences = UserPreferences(
        odUserId: widget.odUserId,
        dietaryRestrictions: _selectedDiets,
        allergies: _allergies,
        favoriteCuisines: _selectedCuisines,
        dislikedCuisines: [],
        skillLevel: _skillLevel,
        timePreference: _timePreference,
        householdSize: _householdSize,
        onboardingCompleted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _preferencesService.savePreferences(preferences);
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.freshGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: List.generate(5, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= _currentPage
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [
                    _DietaryPage(
                      selectedDiets: _selectedDiets,
                      onChanged: (diets) => setState(() => _selectedDiets = diets),
                    ),
                    _AllergiesPage(
                      allergies: _allergies,
                      controller: _allergyController,
                      onChanged: (allergies) => setState(() => _allergies = allergies),
                    ),
                    _CuisinePage(
                      selectedCuisines: _selectedCuisines,
                      onChanged: (cuisines) => setState(() => _selectedCuisines = cuisines),
                    ),
                    _SkillLevelPage(
                      skillLevel: _skillLevel,
                      timePreference: _timePreference,
                      onSkillChanged: (level) => setState(() => _skillLevel = level),
                      onTimeChanged: (time) => setState(() => _timePreference = time),
                    ),
                    _HouseholdPage(
                      householdSize: _householdSize,
                      onChanged: (size) => setState(() => _householdSize = size),
                    ),
                  ],
                ),
              ),
              // Navigation buttons
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: _previousPage,
                        child: Text(
                          'Back',
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              _currentPage < 4 ? 'Continue' : 'Get Started',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page 1: Dietary Restrictions
class _DietaryPage extends StatelessWidget {
  final List<DietaryRestriction> selectedDiets;
  final ValueChanged<List<DietaryRestriction>> onChanged;

  const _DietaryPage({
    required this.selectedDiets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      emoji: '🥗',
      title: 'Any dietary preferences?',
      subtitle: 'Select all that apply. We\'ll personalize your recipes.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: DietaryRestriction.values.map((diet) {
          final isSelected = selectedDiets.contains(diet);
          return _SelectableChip(
            label: '${diet.emoji} ${diet.displayName}',
            isSelected: isSelected,
            onTap: () {
              final newList = List<DietaryRestriction>.from(selectedDiets);
              if (diet == DietaryRestriction.none) {
                newList.clear();
                if (!isSelected) newList.add(diet);
              } else {
                newList.remove(DietaryRestriction.none);
                if (isSelected) {
                  newList.remove(diet);
                } else {
                  newList.add(diet);
                }
              }
              onChanged(newList);
            },
          );
        }).toList(),
      ),
    );
  }
}

/// Page 2: Allergies
class _AllergiesPage extends StatelessWidget {
  final List<String> allergies;
  final TextEditingController controller;
  final ValueChanged<List<String>> onChanged;

  const _AllergiesPage({
    required this.allergies,
    required this.controller,
    required this.onChanged,
  });

  void _addAllergy() {
    final text = controller.text.trim();
    if (text.isNotEmpty && !allergies.contains(text.toLowerCase())) {
      onChanged([...allergies, text.toLowerCase()]);
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      emoji: '⚠️',
      title: 'Any food allergies?',
      subtitle: 'We\'ll make sure to avoid these ingredients.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'e.g., peanuts, shellfish...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _addAllergy(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _addAllergy,
                icon: const Icon(Icons.add_circle),
                color: AppColors.primary,
                iconSize: 40,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allergies.map((allergy) {
              return Chip(
                label: Text(allergy),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  onChanged(allergies.where((a) => a != allergy).toList());
                },
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                labelStyle: GoogleFonts.poppins(color: AppColors.textPrimary),
              );
            }).toList(),
          ),
          if (allergies.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No allergies? Just tap Continue!',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Page 3: Favorite Cuisines
class _CuisinePage extends StatelessWidget {
  final List<CuisineType> selectedCuisines;
  final ValueChanged<List<CuisineType>> onChanged;

  const _CuisinePage({
    required this.selectedCuisines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      emoji: '🌍',
      title: 'What cuisines do you love?',
      subtitle: 'Pick your favorites. We\'ll suggest more of these!',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: CuisineType.values.map((cuisine) {
          final isSelected = selectedCuisines.contains(cuisine);
          return _SelectableChip(
            label: '${cuisine.emoji} ${cuisine.displayName}',
            isSelected: isSelected,
            onTap: () {
              final newList = List<CuisineType>.from(selectedCuisines);
              if (isSelected) {
                newList.remove(cuisine);
              } else {
                newList.add(cuisine);
              }
              onChanged(newList);
            },
          );
        }).toList(),
      ),
    );
  }
}

/// Page 4: Skill Level & Time
class _SkillLevelPage extends StatelessWidget {
  final CookingSkillLevel skillLevel;
  final CookingTimePreference timePreference;
  final ValueChanged<CookingSkillLevel> onSkillChanged;
  final ValueChanged<CookingTimePreference> onTimeChanged;

  const _SkillLevelPage({
    required this.skillLevel,
    required this.timePreference,
    required this.onSkillChanged,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      emoji: '👨‍🍳',
      title: 'How do you cook?',
      subtitle: 'Help us match recipes to your style.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cooking skill level',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...CookingSkillLevel.values.map((level) {
            return _SelectableOption(
              emoji: level.emoji,
              title: level.displayName,
              subtitle: level.description,
              isSelected: skillLevel == level,
              onTap: () => onSkillChanged(level),
            );
          }),
          const SizedBox(height: 24),
          Text(
            'How much time do you usually have?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...CookingTimePreference.values.map((time) {
            return _SelectableOption(
              emoji: time.emoji,
              title: time.displayName,
              subtitle: time.description,
              isSelected: timePreference == time,
              onTap: () => onTimeChanged(time),
            );
          }),
        ],
      ),
    );
  }
}

/// Page 5: Household Size
class _HouseholdPage extends StatelessWidget {
  final int householdSize;
  final ValueChanged<int> onChanged;

  const _HouseholdPage({
    required this.householdSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      emoji: '👨‍👩‍👧‍👦',
      title: 'How many people are you cooking for?',
      subtitle: 'We\'ll adjust portion sizes for you.',
      child: Column(
        children: [
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: householdSize > 1
                    ? () => onChanged(householdSize - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 48,
                color: AppColors.primary,
              ),
              const SizedBox(width: 24),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$householdSize',
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: householdSize < 10
                    ? () => onChanged(householdSize + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 48,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            householdSize == 1 ? 'Just me!' : '$householdSize people',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable page layout
class _OnboardingPageLayout extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Widget child;

  const _OnboardingPageLayout({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

/// Selectable chip widget
class _SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Selectable option (radio-style)
class _SelectableOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

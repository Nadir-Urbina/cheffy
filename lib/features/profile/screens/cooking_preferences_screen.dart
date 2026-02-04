import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/user_preferences.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_colors.dart';

class CookingPreferencesScreen extends StatefulWidget {
  final UserPreferences? userPreferences;

  const CookingPreferencesScreen({super.key, this.userPreferences});

  @override
  State<CookingPreferencesScreen> createState() => _CookingPreferencesScreenState();
}

class _CookingPreferencesScreenState extends State<CookingPreferencesScreen> {
  final _preferencesService = PreferencesService();
  final _allergyController = TextEditingController();

  late List<DietaryRestriction> _selectedDiets;
  late List<String> _allergies;
  late List<CuisineType> _selectedCuisines;
  late CookingSkillLevel _skillLevel;
  late CookingTimePreference _timePreference;

  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current preferences or defaults
    final prefs = widget.userPreferences;
    _selectedDiets = List.from(prefs?.dietaryRestrictions ?? []);
    _allergies = List.from(prefs?.allergies ?? []);
    _selectedCuisines = List.from(prefs?.favoriteCuisines ?? []);
    _skillLevel = prefs?.skillLevel ?? CookingSkillLevel.beginner;
    _timePreference = prefs?.timePreference ?? CookingTimePreference.moderate;
  }

  @override
  void dispose() {
    _allergyController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _savePreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final updatedPrefs = widget.userPreferences?.copyWith(
        dietaryRestrictions: _selectedDiets,
        allergies: _allergies,
        favoriteCuisines: _selectedCuisines,
        skillLevel: _skillLevel,
        timePreference: _timePreference,
      ) ?? UserPreferences(
        odUserId: user.uid,
        dietaryRestrictions: _selectedDiets,
        allergies: _allergies,
        favoriteCuisines: _selectedCuisines,
        skillLevel: _skillLevel,
        timePreference: _timePreference,
        onboardingCompleted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _preferencesService.savePreferences(updatedPrefs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preferences saved'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addAllergy() {
    final text = _allergyController.text.trim();
    if (text.isNotEmpty && !_allergies.contains(text.toLowerCase())) {
      setState(() {
        _allergies.add(text.toLowerCase());
        _allergyController.clear();
      });
      _markChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Cooking Preferences',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isSaving ? null : _savePreferences,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Dietary Restrictions
          _buildSectionHeader('Dietary Preferences', '🥗'),
          const SizedBox(height: 12),
          _buildDietarySection(),
          const SizedBox(height: 28),

          // Allergies
          _buildSectionHeader('Food Allergies', '⚠️'),
          const SizedBox(height: 12),
          _buildAllergiesSection(),
          const SizedBox(height: 28),

          // Favorite Cuisines
          _buildSectionHeader('Favorite Cuisines', '🌍'),
          const SizedBox(height: 12),
          _buildCuisinesSection(),
          const SizedBox(height: 28),

          // Skill Level
          _buildSectionHeader('Cooking Skill Level', '👨‍🍳'),
          const SizedBox(height: 12),
          _buildSkillLevelSection(),
          const SizedBox(height: 28),

          // Time Preference
          _buildSectionHeader('Cooking Time', '⏱️'),
          const SizedBox(height: 12),
          _buildTimePreferenceSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String emoji) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDietarySection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DietaryRestriction.values.map((diet) {
        final isSelected = _selectedDiets.contains(diet);
        return _SelectableChip(
          label: '${diet.emoji} ${diet.displayName}',
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (diet == DietaryRestriction.none) {
                _selectedDiets.clear();
                if (!isSelected) _selectedDiets.add(diet);
              } else {
                _selectedDiets.remove(DietaryRestriction.none);
                if (isSelected) {
                  _selectedDiets.remove(diet);
                } else {
                  _selectedDiets.add(diet);
                }
              }
            });
            _markChanged();
          },
        );
      }).toList(),
    );
  }

  Widget _buildAllergiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _allergyController,
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Add an allergy (e.g., peanuts)',
                  hintStyle: GoogleFonts.poppins(
                    color: AppColors.textHint,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _addAllergy(),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _addAllergy,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
        if (_allergies.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allergies.map((allergy) {
              return Chip(
                label: Text(
                  allergy,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() => _allergies.remove(allergy));
                  _markChanged();
                },
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCuisinesSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CuisineType.values.map((cuisine) {
        final isSelected = _selectedCuisines.contains(cuisine);
        return _SelectableChip(
          label: '${cuisine.emoji} ${cuisine.displayName}',
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _selectedCuisines.remove(cuisine);
              } else {
                _selectedCuisines.add(cuisine);
              }
            });
            _markChanged();
          },
        );
      }).toList(),
    );
  }

  Widget _buildSkillLevelSection() {
    return Column(
      children: CookingSkillLevel.values.map((level) {
        final isSelected = _skillLevel == level;
        return _SelectableOption(
          emoji: level.emoji,
          title: level.displayName,
          subtitle: level.description,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _skillLevel = level);
            _markChanged();
          },
        );
      }).toList(),
    );
  }

  Widget _buildTimePreferenceSection() {
    return Column(
      children: CookingTimePreference.values.map((time) {
        final isSelected = _timePreference == time;
        return _SelectableOption(
          emoji: time.emoji,
          title: time.displayName,
          subtitle: time.description,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _timePreference = time);
            _markChanged();
          },
        );
      }).toList(),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
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
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

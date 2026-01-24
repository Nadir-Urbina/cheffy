import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/recipe_model.dart';
import '../../../core/models/video_recipe_models.dart';
import '../../../core/services/instacart_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../instacart/widgets/retailer_selector.dart';

class VideoRecipeResultScreen extends StatefulWidget {
  final VideoRecipeResult result;

  const VideoRecipeResultScreen({super.key, required this.result});

  @override
  State<VideoRecipeResultScreen> createState() => _VideoRecipeResultScreenState();
}

class _VideoRecipeResultScreenState extends State<VideoRecipeResultScreen> {
  final _instacartService = InstacartService();
  final _preferencesService = PreferencesService();
  bool _isLoadingInstacart = false;
  String? _preferredRetailerName;

  VideoRecipeResult get result => widget.result;
  Recipe get recipe => result.recipe!;
  VideoInfo get videoInfo => result.videoInfo;

  @override
  void initState() {
    super.initState();
    _loadPreferredRetailer();
  }

  Future<void> _loadPreferredRetailer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await _preferencesService.getPreferences(user.uid);
    if (mounted && prefs?.preferredRetailerName != null) {
      setState(() => _preferredRetailerName = prefs!.preferredRetailerName);
    }
  }

  Future<void> _openYouTubeVideo() async {
    final url = Uri.parse(videoInfo.watchUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shopOnInstacart() async {
    HapticFeedback.mediumImpact();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if user has a preferred retailer
    final prefs = await _preferencesService.getPreferences(user.uid);

    if (prefs == null || !prefs.hasPreferredRetailer) {
      // Show retailer selector first
      final selectedRetailer = await RetailerSelectorSheet.show(
        context,
        initialPostalCode: prefs?.postalCode,
      );

      if (selectedRetailer == null || !mounted) return;

      // Save the selected retailer
      await _preferencesService.savePreferredRetailer(
        odUserId: user.uid,
        retailerId: selectedRetailer.id,
        retailerName: selectedRetailer.name,
        postalCode: selectedRetailer.postalCode ?? '',
      );

      setState(() => _preferredRetailerName = selectedRetailer.name);
    }

    setState(() => _isLoadingInstacart = true);

    try {
      final instacartResult = await _instacartService.shopRecipeIngredients(recipe);

      if (!instacartResult.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(instacartResult.error ?? 'Failed to open Instacart'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingInstacart = false);
      }
    }
  }

  Future<void> _changeRetailer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await _preferencesService.getPreferences(user.uid);

    final selectedRetailer = await RetailerSelectorSheet.show(
      context,
      initialPostalCode: prefs?.postalCode,
    );

    if (selectedRetailer == null || !mounted) return;

    await _preferencesService.savePreferredRetailer(
      odUserId: user.uid,
      retailerId: selectedRetailer.id,
      retailerName: selectedRetailer.name,
      postalCode: selectedRetailer.postalCode ?? '',
    );

    setState(() => _preferredRetailerName = selectedRetailer.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          // App bar with video thumbnail
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    size: 18, color: AppColors.textPrimary),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            expandedHeight: 250,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Video thumbnail
                  Image.network(
                    videoInfo.highQualityThumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primaryLight.withValues(alpha: 0.3),
                            const Color(0xFFFFFDF8),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Text('🎬', style: TextStyle(fontSize: 80)),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                  // Play button to open video
                  Center(
                    child: GestureDetector(
                      onTap: _openYouTubeVideo,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  // Source badge
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            result.usedVisionFallback
                                ? 'AI Vision Extracted'
                                : 'Transcript Extracted',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recipe title
                    Text(
                      recipe.name,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Description
                    Text(
                      recipe.description,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Video source info
                    GestureDetector(
                      onTap: _openYouTubeVideo,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    videoInfo.channelName ?? 'YouTube Video',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Tap to watch original video',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Quick stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _QuickStat(
                          icon: Icons.schedule,
                          value: recipe.totalTimeFormatted,
                          label: 'Total Time',
                        ),
                        _QuickStat(
                          icon: Icons.restaurant,
                          value: recipe.difficulty.capitalize(),
                          label: 'Difficulty',
                        ),
                        _QuickStat(
                          icon: Icons.people,
                          value: '${recipe.servings}',
                          label: 'Servings',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Ingredients
                    Text(
                      'Ingredients',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...recipe.ingredients.map((ing) => _IngredientItem(ingredient: ing)),
                    const SizedBox(height: 24),
                    // Instructions
                    Text(
                      'Instructions',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...recipe.instructions.asMap().entries.map(
                          (entry) => _InstructionStep(
                            stepNumber: entry.key + 1,
                            instruction: entry.value,
                          ),
                        ),
                    const SizedBox(height: 100), // Space for bottom buttons
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Bottom action buttons
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preferred retailer indicator
              if (_preferredRetailerName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.store,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Shopping at $_preferredRetailerName',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _changeRetailer,
                        child: Text(
                          'Change',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF43B02A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  // Shop on Instacart button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingInstacart ? null : _shopOnInstacart,
                      icon: _isLoadingInstacart
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.shopping_cart, size: 20),
                      label: Text(
                        _isLoadingInstacart
                            ? 'Opening...'
                            : _preferredRetailerName != null
                                ? 'Shop Ingredients'
                                : 'Choose Store',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF43B02A), // Instacart green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Start Cooking button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Cooking mode coming soon!'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow, size: 22),
                      label: Text(
                        'Start Cooking',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _IngredientItem extends StatelessWidget {
  final RecipeIngredient ingredient;

  const _IngredientItem({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ingredient.formatted,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final int stepNumber;
  final String instruction;

  const _InstructionStep({
    required this.stepNumber,
    required this.instruction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$stepNumber',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension for capitalizing strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

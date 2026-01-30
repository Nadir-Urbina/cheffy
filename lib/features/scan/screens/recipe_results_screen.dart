import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/recipe_model.dart';
import '../../../core/services/instacart_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/recipe_history_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../cooking/screens/cooking_mode_screen.dart';
import '../../instacart/widgets/retailer_selector.dart';
import '../../meal_planning/widgets/schedule_meal_sheet.dart';

class RecipeResultsScreen extends StatelessWidget {
  final RecipeSuggestionResult result;

  const RecipeResultsScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Recipe Suggestions',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: AppColors.freshGradientDecoration,
        child: SafeArea(
          child:
              result.hasError
                  ? _ErrorView(error: result.error!)
                  : result.hasRecipes
                  ? _RecipeList(
                    recipes: result.recipes,
                    ingredients: result.availableIngredients,
                  )
                  : const _EmptyView(),
        ),
      ),
    );
  }
}

class _RecipeList extends StatefulWidget {
  final List<Recipe> recipes;
  final List<String> ingredients;

  const _RecipeList({required this.recipes, required this.ingredients});

  @override
  State<_RecipeList> createState() => _RecipeListState();
}

class _RecipeListState extends State<_RecipeList> {
  bool _isIngredientsExpanded = false;

  List<Recipe> get recipes => widget.recipes;
  List<String> get ingredients => widget.ingredients;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Expandable ingredients card
        _buildIngredientsCard(),
        // Recipe count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Top ${recipes.length} Recipes',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                'AI Picks',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Recipe cards
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              return _RecipeCard(recipe: recipes[index], rank: index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsCard() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _isIngredientsExpanded = !_isIngredientsExpanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row (always visible)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🥗', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ingredients.length} ingredients detected',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      if (!_isIngredientsExpanded)
                        Text(
                          ingredients.take(4).join(', ') +
                              (ingredients.length > 4 ? '...' : ''),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _isIngredientsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          ingredients.map((ingredient) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                ingredient,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to collapse',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState:
                  _isIngredientsExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeCard extends StatefulWidget {
  final Recipe recipe;
  final int rank;

  const _RecipeCard({required this.recipe, required this.rank});

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  final _instacartService = InstacartService();
  final _preferencesService = PreferencesService();
  bool _isLoadingInstacart = false;
  String? _preferredRetailerName;

  Recipe get recipe => widget.recipe;
  int get rank => widget.rank;

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
      final result = await _instacartService.shopRecipeIngredients(recipe);

      if (!result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to open Instacart'),
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
    return GestureDetector(
      onTap: () => _showRecipeDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with rank badge
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: _getGradientColor(),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Stack(
                children: [
                  // Recipe image or emoji fallback
                  if (recipe.imageUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: Image.network(
                        recipe.imageUrl!,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Center(
                              child: Text(
                                _getCuisineEmoji(),
                                style: const TextStyle(fontSize: 56),
                              ),
                            ),
                      ),
                    )
                  else
                    Center(
                      child: Text(
                        _getCuisineEmoji(),
                        style: const TextStyle(fontSize: 56),
                      ),
                    ),
                  // Rank badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (rank == 1)
                            const Text('👑', style: TextStyle(fontSize: 14)),
                          if (rank == 1) const SizedBox(width: 4),
                          Text(
                            '#$rank',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Match percentage
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getMatchColor(),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${recipe.matchPercentage}% match',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.schedule,
                        label: recipe.totalTimeFormatted,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        icon: Icons.restaurant,
                        label: recipe.difficulty.capitalize(),
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        icon: Icons.people,
                        label: '${recipe.servings} servings',
                      ),
                    ],
                  ),
                  // Missing ingredients warning
                  if (recipe.missingIngredients.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            size: 18,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Missing: ${recipe.missingIngredients.join(", ")}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.warning,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Shop on Instacart button
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isLoadingInstacart ? null : _shopOnInstacart,
                          icon:
                              _isLoadingInstacart
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Icon(Icons.shopping_cart, size: 18),
                          label: Text(
                            _isLoadingInstacart
                                ? 'Opening...'
                                : _preferredRetailerName != null
                                ? 'Shop at $_preferredRetailerName'
                                : 'Shop on Instacart',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF43B02A,
                            ), // Instacart green
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (_preferredRetailerName != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _changeRetailer,
                          icon: const Icon(Icons.store, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          tooltip: 'Change store',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGradientColor() {
    switch (recipe.cuisineType.toLowerCase()) {
      case 'italian':
        return const Color(0xFFE8F5E9);
      case 'mexican':
        return const Color(0xFFFFF3E0);
      case 'asian':
      case 'chinese':
      case 'japanese':
      case 'thai':
        return const Color(0xFFFFEBEE);
      case 'indian':
        return const Color(0xFFFFF8E1);
      case 'mediterranean':
      case 'greek':
        return const Color(0xFFE3F2FD);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  String _getCuisineEmoji() {
    switch (recipe.cuisineType.toLowerCase()) {
      case 'italian':
        return '🍝';
      case 'mexican':
        return '🌮';
      case 'chinese':
        return '🥡';
      case 'japanese':
        return '🍣';
      case 'indian':
        return '🍛';
      case 'thai':
        return '🍜';
      case 'mediterranean':
      case 'greek':
        return '🥙';
      case 'american':
        return '🍔';
      case 'french':
        return '🥐';
      default:
        return '🍽️';
    }
  }

  Color _getMatchColor() {
    if (recipe.matchPercentage >= 80) return AppColors.success;
    if (recipe.matchPercentage >= 60) return AppColors.primary;
    return AppColors.warning;
  }

  void _showRecipeDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _instacartService = InstacartService();
  final _preferencesService = PreferencesService();
  final _historyService = RecipeHistoryService();
  bool _isLoadingInstacart = false;
  String? _preferredRetailerName;
  int _timesCooked = 0;

  Recipe get recipe => widget.recipe;

  @override
  void initState() {
    super.initState();
    _loadPreferredRetailer();
    _loadTimesCooked();
  }

  Future<void> _loadTimesCooked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final count = await _historyService.getTimesCooked(user.uid, recipe.id);
    if (mounted && count > 0) {
      setState(() => _timesCooked = count);
    }
  }

  Future<void> _scheduleMeal() async {
    HapticFeedback.mediumImpact();
    await ScheduleMealSheet.show(context, recipe);
  }

  Future<void> _loadPreferredRetailer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await _preferencesService.getPreferences(user.uid);
    if (mounted && prefs?.preferredRetailerName != null) {
      setState(() => _preferredRetailerName = prefs!.preferredRetailerName);
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
      final result = await _instacartService.shopRecipeIngredients(recipe);

      if (!result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to open Instacart'),
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

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryLight.withValues(alpha: 0.3),
            AppColors.primaryLight.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 80))),
    );
  }

  Color _getMatchColor() {
    if (recipe.matchPercentage >= 80) return AppColors.success;
    if (recipe.matchPercentage >= 60) return AppColors.primary;
    if (recipe.matchPercentage > 0) return AppColors.warning;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background image - fixed at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child:
                recipe.imageUrl != null
                    ? Image.network(
                      recipe.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                    )
                    : _buildImagePlaceholder(),
          ),
          // Scrollable content with rounded top
          SingleChildScrollView(
            child: Column(
              children: [
                // Spacer for the image area
                const SizedBox(height: 280),
                // Content container with rounded corners overlapping the image
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and match
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                recipe.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getMatchColor(),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${recipe.matchPercentage}%',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // "Cooked X times" badge
                        if (_timesCooked > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _timesCooked == 1
                                      ? "You've made this recipe"
                                      : "You've made this $_timesCooked times",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          recipe.description,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
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
                        const SizedBox(height: 28),
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
                        ...recipe.ingredients.map(
                          (ing) => _IngredientItem(ingredient: ing),
                        ),
                        const SizedBox(height: 28),
                        // Instructions
                        Text(
                          'Directions',
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
                        const SizedBox(height: 100), // Space for bottom bar
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
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
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          // Calendar & Save buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: Row(
              children: [
                // Calendar button (schedule meal)
                GestureDetector(
                  onTap: () => _scheduleMeal(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
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
                    child: const Icon(
                      Icons.calendar_month,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Bookmark button
                Container(
                  padding: const EdgeInsets.all(10),
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
                  child: const Icon(
                    Icons.bookmark_border,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
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
                      const Icon(
                        Icons.store,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
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
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingInstacart ? null : _shopOnInstacart,
                      icon:
                          _isLoadingInstacart
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                              : Icon(Icons.shopping_cart, size: 20, color: AppColors.primary),
                      label: Text(
                        _isLoadingInstacart
                            ? 'Opening...'
                            : _preferredRetailerName != null
                            ? 'Shop'
                            : 'Choose Store',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Start Cooking button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CookingModeScreen(recipe: widget.recipe),
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
          Icon(
            ingredient.isAvailable ? Icons.check_circle : Icons.circle_outlined,
            color:
                ingredient.isAvailable ? AppColors.success : AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ingredient.formatted,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color:
                    ingredient.isAvailable
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                decoration:
                    ingredient.isAvailable ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
          if (ingredient.isOptional)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'optional',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppColors.textSecondary,
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

  const _InstructionStep({required this.stepNumber, required this.instruction});

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

class _ErrorView extends StatelessWidget {
  final String error;

  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😕', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🤔', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'No recipes found',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adding more ingredients or adjusting your preferences',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
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

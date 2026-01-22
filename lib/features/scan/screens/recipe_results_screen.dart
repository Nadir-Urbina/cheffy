import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/recipe_model.dart';
import '../../../core/theme/app_colors.dart';

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
          child: result.hasError
              ? _ErrorView(error: result.error!)
              : result.hasRecipes
                  ? _RecipeList(recipes: result.recipes, ingredients: result.availableIngredients)
                  : const _EmptyView(),
        ),
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  final List<Recipe> recipes;
  final List<String> ingredients;

  const _RecipeList({required this.recipes, required this.ingredients});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Ingredients summary
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('🥗', style: TextStyle(fontSize: 28)),
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
                      ),
                    ),
                    Text(
                      ingredients.take(5).join(', ') + 
                          (ingredients.length > 5 ? '...' : ''),
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
            ],
          ),
        ),
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
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
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
              return _RecipeCard(
                recipe: recipes[index],
                rank: index + 1,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final int rank;

  const _RecipeCard({required this.recipe, required this.rank});

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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  // Recipe image or emoji fallback
                  if (recipe.imageUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
                        recipe.imageUrl!,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          const Icon(Icons.shopping_cart_outlined, 
                              size: 18, color: AppColors.warning),
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
        builder: (context) => _RecipeDetailScreen(recipe: recipe),
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

class _RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const _RecipeDetailScreen({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF8),
      body: CustomScrollView(
        slivers: [
          // App bar with back button
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
              background: recipe.imageUrl != null
                  ? Image.network(
                      recipe.imageUrl!,
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
                          child: Text('🍽️', style: TextStyle(fontSize: 80)),
                        ),
                      ),
                    )
                  : Container(
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
                        child: Text('🍽️', style: TextStyle(fontSize: 80)),
                      ),
                    ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and match
                  Row(
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
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
                  const SizedBox(height: 8),
                  Text(
                    recipe.description,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom action button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
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
          child: ElevatedButton(
            onPressed: () {
              // TODO: Mark as cooking / enter cooking mode
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Start Cooking',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
            color: ingredient.isAvailable ? AppColors.success : AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ingredient.formatted,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: ingredient.isAvailable 
                    ? AppColors.textPrimary 
                    : AppColors.textSecondary,
                decoration: ingredient.isAvailable 
                    ? null 
                    : TextDecoration.lineThrough,
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

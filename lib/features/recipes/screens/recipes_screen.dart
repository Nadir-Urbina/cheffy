import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/recipe_model.dart';
import '../../../core/services/spoonacular_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../scan/screens/recipe_results_screen.dart' show RecipeDetailScreen;

/// Recipe browsing screen with search and categories
class RecipesScreen extends StatefulWidget {
  final bool isActive;

  const RecipesScreen({super.key, this.isActive = true});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _searchController = TextEditingController();
  final _spoonacularService = SpoonacularService();
  final _scrollController = ScrollController();
  Timer? _debounceTimer;

  // Category data
  static const List<_RecipeCategory> _categories = [
    _RecipeCategory(
      name: 'Breakfast',
      tag: 'breakfast',
      emoji: '🥞',
    ),
    _RecipeCategory(
      name: 'Lunch',
      tag: 'lunch',
      emoji: '🥪',
    ),
    _RecipeCategory(
      name: 'Dinner',
      tag: 'dinner',
      emoji: '🍝',
    ),
    _RecipeCategory(
      name: 'Desserts',
      tag: 'dessert',
      emoji: '🧁',
    ),
    _RecipeCategory(
      name: 'Seafood',
      tag: 'seafood',
      emoji: '🦐',
    ),
    _RecipeCategory(
      name: 'Salads',
      tag: 'salad',
      emoji: '🥗',
    ),
  ];

  Map<String, List<Recipe>> _categoryRecipes = {};
  Map<String, bool> _categoryLoading = {};
  bool _isSearching = false;
  List<Recipe> _searchResults = [];
  String _searchQuery = '';
  bool _hasLoadedInitially = false;

  @override
  void initState() {
    super.initState();
    // Load only if active on first build
    if (widget.isActive) {
      _loadInitialDataIfNeeded();
    }
  }

  @override
  void didUpdateWidget(RecipesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Load when becoming active
    if (widget.isActive && !oldWidget.isActive) {
      _loadInitialDataIfNeeded();
    }
  }

  void _loadInitialDataIfNeeded() {
    if (!_hasLoadedInitially && mounted) {
      _hasLoadedInitially = true;
      _loadAllCategories();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllCategories({bool forceRefresh = false}) async {
    for (final category in _categories) {
      _loadCategory(category, forceRefresh: forceRefresh);
    }
  }

  Future<void> _loadCategory(_RecipeCategory category, {bool forceRefresh = false}) async {
    setState(() {
      _categoryLoading[category.tag] = true;
    });

    try {
      final recipes = await _spoonacularService.getPopularRecipes(
        count: 6,
        tags: category.tag,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _categoryRecipes[category.tag] = recipes;
          _categoryLoading[category.tag] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categoryLoading[category.tag] = false;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final results = await _spoonacularService.searchRecipes(
        query: query,
        count: 12,
      );

      if (mounted && _searchQuery == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _searchQuery = '';
    });
  }

  void _openRecipeDetail(Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    );
  }

  void _openCategoryFullView(_RecipeCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CategoryFullScreen(
          category: category,
          spoonacularService: _spoonacularService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: _searchQuery.isNotEmpty
                    ? _buildSearchResults()
                    : _buildCategoryList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            'Recipes',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search recipes...',
            hintStyle: GoogleFonts.poppins(
              color: AppColors.textHint,
              fontSize: 15,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: AppColors.textSecondary,
              size: 22,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: _clearSearch,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          onChanged: (value) {
            setState(() {});
            _debounceTimer?.cancel();
            if (value.isEmpty) {
              _clearSearch();
            } else if (value.length >= 3) {
              _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                _performSearch(value);
              });
            }
          },
          onSubmitted: (value) {
            _debounceTimer?.cancel();
            if (value.trim().isNotEmpty) {
              _performSearch(value);
            }
          },
          textInputAction: TextInputAction.search,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No recipes found for "$_searchQuery"',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Results for "$_searchQuery"',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildRecipeGrid(_searchResults),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return RefreshIndicator(
      onRefresh: () async {
        _categoryRecipes.clear();
        await _loadAllCategories(forceRefresh: true);
      },
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _buildCategorySection(category);
        },
      ),
    );
  }

  Widget _buildCategorySection(_RecipeCategory category) {
    final recipes = _categoryRecipes[category.tag] ?? [];
    final isLoading = _categoryLoading[category.tag] ?? true;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category.name,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _openCategoryFullView(category),
                  child: Text(
                    'See more',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Recipe grid
          if (isLoading)
            _buildLoadingGrid()
          else if (recipes.isEmpty)
            _buildEmptyCategory()
          else
            _buildHorizontalRecipeList(recipes),
        ],
      ),
    );
  }

  Widget _buildHorizontalRecipeList(List<Recipe> recipes) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recipes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _RecipeCard(
            recipe: recipes[index],
            onTap: () => _openRecipeDetail(recipes[index]),
            width: 160,
          );
        },
      ),
    );
  }

  Widget _buildRecipeGrid(List<Recipe> recipes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        return _RecipeCard(
          recipe: recipes[index],
          onTap: () => _openRecipeDetail(recipes[index]),
        );
      },
    );
  }

  Widget _buildLoadingGrid() {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => _RecipeCardSkeleton(width: 160),
      ),
    );
  }

  Widget _buildEmptyCategory() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'No recipes available',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Recipe category data model
class _RecipeCategory {
  final String name;
  final String tag;
  final String emoji;

  const _RecipeCategory({
    required this.name,
    required this.tag,
    required this.emoji,
  });
}

/// Recipe card widget
class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final double? width;

  const _RecipeCard({
    required this.recipe,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: recipe.imageUrl != null
                    ? Image.network(
                        recipe.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      )
                    : _buildPlaceholder(),
              ),
            ),
            // Content
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(recipe.normalizedDifficulty)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            recipe.difficultyLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: _getDifficultyColor(recipe.normalizedDifficulty),
                        ),
                      ),
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
                          recipe.totalTimeFormatted,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primaryLight.withValues(alpha: 0.2),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 40,
          color: AppColors.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF4A9BD9); // Calm blue -- inviting
      case 'intermediate':
        return AppColors.primary;       // App green -- positive
      case 'advanced':
        return const Color(0xFF8B5CF6); // Vibrant purple -- exciting
      default:
        return AppColors.textSecondary;
    }
  }
}

/// Skeleton loader for recipe cards
class _RecipeCardSkeleton extends StatelessWidget {
  final double? width;

  const _RecipeCardSkeleton({this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 20,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full screen view for a category
class _CategoryFullScreen extends StatefulWidget {
  final _RecipeCategory category;
  final SpoonacularService spoonacularService;

  const _CategoryFullScreen({
    required this.category,
    required this.spoonacularService,
  });

  @override
  State<_CategoryFullScreen> createState() => _CategoryFullScreenState();
}

class _CategoryFullScreenState extends State<_CategoryFullScreen> {
  List<Recipe> _recipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    
    try {
      final recipes = await widget.spoonacularService.getPopularRecipes(
        count: 20,
        tags: widget.category.tag,
      );

      if (mounted) {
        setState(() {
          _recipes = recipes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.category.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            Text(
              widget.category.name,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadRecipes,
              color: AppColors.primary,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _recipes.length,
                itemBuilder: (context, index) {
                  return _RecipeCard(
                    recipe: _recipes[index],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecipeDetailScreen(
                            recipe: _recipes[index],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

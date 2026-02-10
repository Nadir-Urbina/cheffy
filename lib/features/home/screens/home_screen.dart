import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/recipe_model.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/spoonacular_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../chat/screens/chat_ingredients_screen.dart';
import '../../meal_planning/screens/meal_plan_screen.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../profile/screens/help_support_screen.dart';
import '../../profile/screens/settings_screen.dart';
import '../../recipes/screens/recipes_screen.dart';
import '../../scan/screens/scan_ingredients_screen.dart';
import '../../scan/screens/recipe_results_screen.dart' show RecipeDetailScreen;
import '../../video/screens/video_recipe_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthService authService;

  const HomeScreen({super.key, required this.authService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _HomeContent(
              authService: widget.authService,
              onProfileTap: () => setState(() => _currentIndex = 3),
            ),
            RecipesScreen(isActive: _currentIndex == 1),
            const MealPlanScreen(),
            _ProfileScreen(authService: widget.authService),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                isActive: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: 'Recipes',
                isActive: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _NavItem(
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month,
                label: 'Meal Plan',
                isActive: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                isActive: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home tab content
class _HomeContent extends StatefulWidget {
  final AuthService authService;
  final VoidCallback? onProfileTap;

  const _HomeContent({required this.authService, this.onProfileTap});

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  final SpoonacularService _spoonacularService = SpoonacularService();
  final PreferencesService _preferencesService = PreferencesService();
  List<Recipe> _popularRecipes = [];
  bool _isLoading = true;
  String? _selectedCategory;
  UserPreferences? _userPreferences;

  // Category data with emoji icons and API tags
  static const List<_CategoryData> _categories = [
    _CategoryData(name: 'All', emoji: '🍽️', tag: null),
    _CategoryData(name: 'Breakfast', emoji: '🥞', tag: 'breakfast'),
    _CategoryData(name: 'Lunch', emoji: '🍱', tag: 'lunch'),
    _CategoryData(name: 'Dinner', emoji: '🍝', tag: 'dinner'),
    _CategoryData(name: 'Dessert', emoji: '🧁', tag: 'dessert'),
    _CategoryData(name: 'Salad', emoji: '🥗', tag: 'salad'),
    _CategoryData(name: 'Soup', emoji: '🍲', tag: 'soup'),
    _CategoryData(name: 'Appetizer', emoji: '🍤', tag: 'appetizer'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserPreferencesAndRecipes();
  }

  Future<void> _loadUserPreferencesAndRecipes() async {
    // Load user preferences first
    final userId = widget.authService.currentUser?.uid;
    if (userId != null) {
      _userPreferences = await _preferencesService.getPreferences(userId);
    }
    await _loadPopularRecipes();
  }

  Future<void> _loadPopularRecipes({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      // Fetch more recipes so we can filter by skill level
      final recipes = await _spoonacularService.getPopularRecipes(
        count: 12, // Fetch extra to have enough after filtering
        tags: _selectedCategory,
        forceRefresh: forceRefresh,
      );
      
      // Sort/filter by user's skill level
      final sortedRecipes = _sortBySkillLevel(recipes);
      
      if (mounted) {
        setState(() {
          _popularRecipes = sortedRecipes.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Sort recipes based on user's skill level preference
  /// Beginner: 3 beginner, 1 intermediate, 1 advanced
  /// Intermediate: 1 beginner, 3 intermediate, 1 advanced
  /// Advanced: 1 beginner, 1 intermediate, 3 advanced
  ///
  /// Results are always ordered: beginner first, then intermediate, then advanced
  List<Recipe> _sortBySkillLevel(List<Recipe> recipes) {
    if (recipes.isEmpty) return recipes;
    
    final skillLevel = _userPreferences?.skillLevel ?? CookingSkillLevel.beginner;
    
    // Separate recipes by difficulty
    final beginner = recipes.where((r) => r.normalizedDifficulty == 'beginner').toList();
    final intermediate = recipes.where((r) => r.normalizedDifficulty == 'intermediate').toList();
    final advanced = recipes.where((r) => r.normalizedDifficulty == 'advanced').toList();
    
    // Determine counts based on skill level
    int beginnerCount, intermediateCount, advancedCount;
    switch (skillLevel) {
      case CookingSkillLevel.beginner:
        beginnerCount = 3;
        intermediateCount = 1;
        advancedCount = 1;
        break;
      case CookingSkillLevel.intermediate:
        beginnerCount = 1;
        intermediateCount = 3;
        advancedCount = 1;
        break;
      case CookingSkillLevel.advanced:
        beginnerCount = 1;
        intermediateCount = 1;
        advancedCount = 3;
        break;
    }
    
    // Build result list in order: beginner -> intermediate -> advanced
    final result = <Recipe>[];
    result.addAll(beginner.take(beginnerCount));
    result.addAll(intermediate.take(intermediateCount));
    result.addAll(advanced.take(advancedCount));
    
    // If we don't have enough in preferred categories, fill from others
    if (result.length < 5) {
      final remaining = recipes.where((r) => !result.contains(r)).toList();
      result.addAll(remaining.take(5 - result.length));
    }
    
    return result;
  }

  void _onCategorySelected(String? tag) {
    if (_selectedCategory != tag) {
      setState(() => _selectedCategory = tag);
      _loadPopularRecipes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _loadPopularRecipes(forceRefresh: true),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildActionCards(context),
            const SizedBox(height: 28),
            _buildPopularRecipes(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Get user's info
    final user = widget.authService.currentUser;
    final displayName = user?.displayName ?? '';
    final firstName = displayName.isNotEmpty 
        ? displayName.split(' ').first 
        : 'Chef';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row with avatar and greeting
        Row(
          children: [
            // User avatar
            GestureDetector(
              onTap: widget.onProfileTap,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                  backgroundImage: user?.photoURL != null 
                      ? NetworkImage(user!.photoURL!) 
                      : null,
                  child: user?.photoURL == null
                      ? Text(
                          (displayName.isNotEmpty ? displayName[0] : 'C').toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Greeting
            Text(
              'Hey $firstName,',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Main question
        Text(
          'What would you like\nto cook today?',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ActionCard(
              svgPath: 'assets/icons/home_page_feature_icons/camera.svg',
              title: 'Scan Your\nIngredients',
              onTap: () => _navigateToScan(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              svgPath: 'assets/icons/home_page_feature_icons/clapboard.svg',
              title: 'Paste a\nCooking Video',
              onTap: () => _navigateToVideo(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              svgPath: 'assets/icons/home_page_feature_icons/chat_bubble.svg',
              title: 'Chat What\nYou Have',
              onTap: () => _navigateToChat(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularRecipes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Popular Recipes',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (!_isLoading && _popularRecipes.isNotEmpty)
              GestureDetector(
                onTap: () => _loadPopularRecipes(forceRefresh: true),
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Refresh',
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
        ),
        const SizedBox(height: 12),
        // Category filters
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = _selectedCategory == category.tag;
              return _CategoryChip(
                category: category,
                isSelected: isSelected,
                onTap: () => _onCategorySelected(category.tag),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, __) => _RecipeCardSkeleton(),
            ),
          )
        else if (_popularRecipes.isEmpty)
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_menu, size: 32, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'Unable to load recipes',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: _loadPopularRecipes,
                    child: Text('Try Again'),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _popularRecipes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                return _PopularRecipeCard(
                  recipe: _popularRecipes[index],
                  onTap: () => _showRecipeDetail(_popularRecipes[index]),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showRecipeDetail(Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    );
  }

  void _navigateToScan(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanIngredientsScreen()),
    );
  }

  void _navigateToChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatIngredientsScreen()),
    );
  }

  void _navigateToVideo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VideoRecipeScreen()),
    );
  }
}

/// Popular recipe card with real image
class _PopularRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _PopularRecipeCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 175,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: recipe.imageUrl != null
                  ? Image.network(
                      recipe.imageUrl!,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 130,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    )
                  : _buildPlaceholder(),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(recipe.normalizedDifficulty).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          recipe.difficultyLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _getDifficultyColor(recipe.normalizedDifficulty),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
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
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 130,
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
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 175,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 20,
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Action card widget
class _ActionCard extends StatelessWidget {
  final String svgPath;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({
    required this.svgPath,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: SvgPicture.asset(
                  svgPath,
                  width: 26,
                  height: 26,
                  colorFilter: ColorFilter.mode(
                    AppColors.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile screen
class _ProfileScreen extends StatefulWidget {
  final AuthService authService;

  const _ProfileScreen({required this.authService});

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  // Key to force rebuild when returning from edit profile
  Key _profileKey = UniqueKey();

  void _refreshProfile() {
    setState(() {
      _profileKey = UniqueKey();
    });
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          authService: widget.authService as FirebaseAuthService,
        ),
      ),
    );

    // Refresh profile if changes were made
    if (result == true) {
      _refreshProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;

    return Padding(
      key: _profileKey,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Profile avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
            backgroundImage:
                user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null
                ? Text(
                    (user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0]
                            : user?.email?[0] ?? 'U')
                        .toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            user?.displayName ?? 'Chef',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          // Email
          Text(
            user?.email ?? '',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          // Menu items
          _ProfileMenuItem(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            onTap: _navigateToEditProfile,
          ),
          _ProfileMenuItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () {},
          ),
          _ProfileMenuItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    authService: widget.authService as FirebaseAuthService,
                  ),
                ),
              );
            },
          ),
          _ProfileMenuItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
              );
            },
          ),
          const Spacer(),
          // Sign out button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => widget.authService.signOut(),
              icon: const Icon(Icons.logout),
              label: Text(
                'Sign Out',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Profile menu item
class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Category data model
class _CategoryData {
  final String name;
  final String emoji;
  final String? tag;

  const _CategoryData({
    required this.name,
    required this.emoji,
    required this.tag,
  });
}

/// Category filter chip widget
class _CategoryChip extends StatelessWidget {
  final _CategoryData category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
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
            child: Center(
              child: Text(
                category.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.name,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom nav item
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


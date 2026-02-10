import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_model.dart';

/// Service for caching recipes locally to reduce API calls
class RecipeCacheService {
  static const String _popularRecipesKey = 'cache_popular_recipes';
  static const String _categoryRecipesPrefix = 'cache_category_';
  static const String _timestampSuffix = '_timestamp';

  // Cache durations (max 1 hour per Spoonacular API Terms of Use)
  static const Duration popularRecipesCacheDuration = Duration(minutes: 55);
  static const Duration categoryRecipesCacheDuration = Duration(minutes: 55);

  SharedPreferences? _prefs;

  /// Initialize the cache service
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure prefs is initialized
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ============ Popular Recipes Cache ============

  /// Get cached popular recipes if still valid
  Future<List<Recipe>?> getCachedPopularRecipes({String? tag}) async {
    try {
      final prefs = await _preferences;
      final key = tag != null ? '${_popularRecipesKey}_$tag' : _popularRecipesKey;
      final timestampKey = '$key$_timestampSuffix';

      final cachedData = prefs.getString(key);
      final cachedTimestamp = prefs.getInt(timestampKey);

      if (cachedData == null || cachedTimestamp == null) {
        return null;
      }

      // Check if cache is still valid
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
      if (DateTime.now().difference(cacheTime) > popularRecipesCacheDuration) {
        debugPrint('📦 Popular recipes cache expired (tag: $tag)');
        return null;
      }

      final List<dynamic> jsonList = jsonDecode(cachedData);
      final recipes = jsonList.map((json) => Recipe.fromJson(json)).toList();
      
      debugPrint('📦 Using cached popular recipes (${recipes.length} items, tag: $tag)');
      return recipes;
    } catch (e) {
      debugPrint('❌ Error reading popular recipes cache: $e');
      return null;
    }
  }

  /// Cache popular recipes
  Future<void> cachePopularRecipes(List<Recipe> recipes, {String? tag}) async {
    try {
      final prefs = await _preferences;
      final key = tag != null ? '${_popularRecipesKey}_$tag' : _popularRecipesKey;
      final timestampKey = '$key$_timestampSuffix';

      final jsonList = recipes.map((r) => r.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('📦 Cached ${recipes.length} popular recipes (tag: $tag)');
    } catch (e) {
      debugPrint('❌ Error caching popular recipes: $e');
    }
  }

  // ============ Category Recipes Cache ============

  /// Get cached category recipes if still valid
  Future<List<Recipe>?> getCachedCategoryRecipes(String categoryTag) async {
    try {
      final prefs = await _preferences;
      final key = '$_categoryRecipesPrefix$categoryTag';
      final timestampKey = '$key$_timestampSuffix';

      final cachedData = prefs.getString(key);
      final cachedTimestamp = prefs.getInt(timestampKey);

      if (cachedData == null || cachedTimestamp == null) {
        return null;
      }

      // Check if cache is still valid
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
      if (DateTime.now().difference(cacheTime) > categoryRecipesCacheDuration) {
        debugPrint('📦 Category cache expired: $categoryTag');
        return null;
      }

      final List<dynamic> jsonList = jsonDecode(cachedData);
      final recipes = jsonList.map((json) => Recipe.fromJson(json)).toList();
      
      debugPrint('📦 Using cached category recipes: $categoryTag (${recipes.length} items)');
      return recipes;
    } catch (e) {
      debugPrint('❌ Error reading category cache: $e');
      return null;
    }
  }

  /// Cache category recipes
  Future<void> cacheCategoryRecipes(String categoryTag, List<Recipe> recipes) async {
    try {
      final prefs = await _preferences;
      final key = '$_categoryRecipesPrefix$categoryTag';
      final timestampKey = '$key$_timestampSuffix';

      final jsonList = recipes.map((r) => r.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('📦 Cached ${recipes.length} recipes for category: $categoryTag');
    } catch (e) {
      debugPrint('❌ Error caching category recipes: $e');
    }
  }

  // ============ Cache Management ============

  /// Clear all recipe caches
  Future<void> clearAllCaches() async {
    try {
      final prefs = await _preferences;
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith('cache_')) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('📦 All recipe caches cleared');
    } catch (e) {
      debugPrint('❌ Error clearing caches: $e');
    }
  }

  /// Clear only popular recipes cache (for manual refresh)
  Future<void> clearPopularRecipesCache({String? tag}) async {
    try {
      final prefs = await _preferences;
      final key = tag != null ? '${_popularRecipesKey}_$tag' : _popularRecipesKey;
      final timestampKey = '$key$_timestampSuffix';
      
      await prefs.remove(key);
      await prefs.remove(timestampKey);
      
      debugPrint('📦 Popular recipes cache cleared (tag: $tag)');
    } catch (e) {
      debugPrint('❌ Error clearing popular cache: $e');
    }
  }

  /// Clear category cache (for manual refresh)
  Future<void> clearCategoryCache(String categoryTag) async {
    try {
      final prefs = await _preferences;
      final key = '$_categoryRecipesPrefix$categoryTag';
      final timestampKey = '$key$_timestampSuffix';
      
      await prefs.remove(key);
      await prefs.remove(timestampKey);
      
      debugPrint('📦 Category cache cleared: $categoryTag');
    } catch (e) {
      debugPrint('❌ Error clearing category cache: $e');
    }
  }

  /// Get cache stats for debugging
  Future<Map<String, dynamic>> getCacheStats() async {
    final prefs = await _preferences;
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_') && !k.endsWith('_timestamp'));
    
    final stats = <String, dynamic>{};
    for (final key in keys) {
      final timestampKey = '$key$_timestampSuffix';
      final timestamp = prefs.getInt(timestampKey);
      if (timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final age = DateTime.now().difference(cacheTime);
        stats[key] = {
          'age_minutes': age.inMinutes,
          'cached_at': cacheTime.toIso8601String(),
        };
      }
    }
    
    return stats;
  }
}

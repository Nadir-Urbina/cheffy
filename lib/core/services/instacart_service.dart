import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/instacart_models.dart';
import '../models/recipe_model.dart';

/// Service for Instacart Developer Platform API integration
///
/// Documentation: https://docs.instacart.com/developer_platform_api/
///
/// Key Features:
/// - Create shopping list pages from recipe ingredients
/// - Create recipe pages with full details
/// - Get nearby retailers
/// - Launch Instacart checkout flow
class InstacartService {
  static final InstacartService _instance = InstacartService._internal();
  factory InstacartService() => _instance;
  InstacartService._internal();

  // API Configuration
  // Reference: https://docs.instacart.com/developer_platform_api/api/overview/
  static const String _productionUrl = 'https://connect.instacart.com';
  static const String _developmentUrl = 'https://connect.dev.instacart.tools';

  // Set to true when ready for production
  static const bool _useProduction = false;

  String get _apiKey => dotenv.env['INSTACART_API_KEY'] ?? '';

  String get _currentBaseUrl =>
      _useProduction ? _productionUrl : _developmentUrl;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $_apiKey',
  };

  /// Create a shopping list page on Instacart
  ///
  /// Returns a URL that users can click to view the shopping list
  /// and add items to their Instacart cart.
  ///
  /// Reference: https://docs.instacart.com/developer_platform_api/api/products/create_shopping_list_page
  Future<InstacartLinkResponse> createShoppingList({
    required String title,
    required List<InstacartLineItem> items,
    String? imageUrl,
  }) async {
    try {
      final request = CreateShoppingListRequest(
        title: title,
        lineItems: items,
        imageUrl: imageUrl,
        linkType: 'shopping_list',
      );

      final response = await http.post(
        Uri.parse('$_currentBaseUrl/idp/v1/products/products_link'),
        headers: _headers,
        body: jsonEncode(request.toJson()),
      );

      debugPrint('🛒 Instacart Shopping List Response: ${response.statusCode}');
      debugPrint('📦 Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return InstacartLinkResponse.fromJson(data);
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage =
            errorBody['error']?.toString() ??
            errorBody['message']?.toString() ??
            'Failed to create shopping list';
        return InstacartLinkResponse.error(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ Instacart Error: $e');
      return InstacartLinkResponse.error('Failed to connect to Instacart: $e');
    }
  }

  /// Create a recipe page on Instacart
  ///
  /// Creates a full recipe page with ingredients, instructions,
  /// and shopping functionality.
  ///
  /// Set [onlyMissingIngredients] to true (default) to only include
  /// ingredients the user doesn't have. Set to false to include all.
  ///
  /// Reference: https://docs.instacart.com/developer_platform_api/api/products/create_recipe_page
  Future<InstacartLinkResponse> createRecipePage({
    required Recipe recipe,
    bool onlyMissingIngredients = true,
  }) async {
    try {
      // Filter ingredients based on availability
      final ingredientsToShop = onlyMissingIngredients
          ? recipe.ingredients.where((ing) => !ing.isAvailable).toList()
          : recipe.ingredients;
      
      debugPrint('🛒 Shopping for ${ingredientsToShop.length} of ${recipe.ingredients.length} ingredients (missing only: $onlyMissingIngredients)');
      
      // If all ingredients are available, notify the user
      if (ingredientsToShop.isEmpty) {
        return InstacartLinkResponse.error(
          'You already have all the ingredients for this recipe!'
        );
      }
      
      // Convert recipe ingredients to Instacart line items
      final lineItems =
          ingredientsToShop.map((ing) {
            return InstacartLineItem.fromIngredient(
              name: ing.name,
              quantity: ing.quantity,
              unit: ing.unit,
              displayText: ing.formatted,
            );
          }).toList();

      final request = CreateRecipePageRequest(
        title: recipe.name,
        lineItems: lineItems,
        imageUrl: recipe.imageUrl,
        servings: recipe.servings,
        prepTime: recipe.totalTimeMinutes,
        instructions: recipe.instructions,
      );

      final response = await http.post(
        Uri.parse('$_currentBaseUrl/idp/v1/products/products_link'),
        headers: _headers,
        body: jsonEncode(request.toJson()),
      );

      debugPrint('🍳 Instacart Recipe Page Response: ${response.statusCode}');
      debugPrint('📦 Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return InstacartLinkResponse.fromJson(data);
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage =
            errorBody['error']?.toString() ??
            errorBody['message']?.toString() ??
            'Failed to create recipe page';
        return InstacartLinkResponse.error(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ Instacart Recipe Error: $e');
      return InstacartLinkResponse.error('Failed to connect to Instacart: $e');
    }
  }

  /// Create a shopping list from a list of ingredient names
  ///
  /// Simplified method for when you just have ingredient names
  /// without detailed measurements.
  Future<InstacartLinkResponse> createShoppingListFromIngredients({
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) async {
    final lineItems =
        ingredients.map((name) {
          return InstacartLineItem(name: name, displayText: name);
        }).toList();

    return createShoppingList(
      title: title,
      items: lineItems,
      imageUrl: imageUrl,
    );
  }

  /// Get nearby retailers based on postal code
  ///
  /// Reference: https://docs.instacart.com/developer_platform_api/api/retailers/get_nearby_retailers
  Future<NearbyRetailersResponse> getNearbyRetailers({
    required String postalCode,
    String countryCode = 'US',
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_currentBaseUrl/idp/v1/retailers?postal_code=$postalCode&country_code=$countryCode',
        ),
        headers: _headers,
      );

      debugPrint('🏪 Instacart Retailers Response: ${response.statusCode}');
      debugPrint('📦 Retailers Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = NearbyRetailersResponse.fromJson(data);
        
        // Debug: log retailer IDs
        for (final r in result.retailers) {
          debugPrint('  Retailer: ${r.name} (id=${r.id})');
        }
        
        return result;
      } else {
        return NearbyRetailersResponse.error('Failed to fetch retailers');
      }
    } catch (e) {
      debugPrint('❌ Instacart Retailers Error: $e');
      return NearbyRetailersResponse.error(
        'Failed to connect to Instacart: $e',
      );
    }
  }

  /// Open an Instacart link in the browser or app
  ///
  /// This will open the shopping list or recipe page in:
  /// - Instacart app if installed
  /// - Web browser otherwise
  Future<bool> openInstacartLink(String url) async {
    try {
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        debugPrint('❌ Cannot launch URL: $url');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error launching Instacart: $e');
      return false;
    }
  }

  /// Convenience method: Create shopping list and open it
  ///
  /// Creates a shopping list from recipe ingredients and immediately
  /// opens it in Instacart.
  ///
  /// By default, only includes ingredients the user doesn't have.
  /// Set [onlyMissingIngredients] to false to include all ingredients.
  Future<InstacartResult> shopRecipeIngredients(
    Recipe recipe, {
    bool onlyMissingIngredients = true,
  }) async {
    // Create the shopping list
    final response = await createRecipePage(
      recipe: recipe,
      onlyMissingIngredients: onlyMissingIngredients,
    );

    if (!response.success || response.productsLinkUrl == null) {
      return InstacartResult(
        success: false,
        error: response.error ?? 'Failed to create Instacart link',
      );
    }

    // Open the link
    final opened = await openInstacartLink(response.productsLinkUrl!);

    return InstacartResult(
      success: opened,
      linkUrl: response.productsLinkUrl,
      error: opened ? null : 'Failed to open Instacart',
    );
  }

  /// Convenience method: Create shopping list from ingredient names and open it
  Future<InstacartResult> shopIngredientsList({
    required String title,
    required List<String> ingredients,
  }) async {
    final response = await createShoppingListFromIngredients(
      title: title,
      ingredients: ingredients,
    );

    if (!response.success || response.productsLinkUrl == null) {
      return InstacartResult(
        success: false,
        error: response.error ?? 'Failed to create Instacart link',
      );
    }

    final opened = await openInstacartLink(response.productsLinkUrl!);

    return InstacartResult(
      success: opened,
      linkUrl: response.productsLinkUrl,
      error: opened ? null : 'Failed to open Instacart',
    );
  }
}

/// Result of an Instacart operation
class InstacartResult {
  final bool success;
  final String? linkUrl;
  final String? error;

  const InstacartResult({required this.success, this.linkUrl, this.error});
}

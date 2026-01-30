/// Instacart API data models
/// Based on: https://docs.instacart.com/developer_platform_api/

/// Measurement unit for ingredients
/// Reference: https://docs.instacart.com/developer_platform_api/api/units_of_measurement
class InstacartMeasurement {
  final String unit;
  final double quantity;

  const InstacartMeasurement({
    required this.unit,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'unit': unit,
    'quantity': quantity,
  };

  /// Common unit mappings from recipe formats to Instacart format
  static String normalizeUnit(String unit) {
    final normalized = unit.toLowerCase().trim();
    
    // Volume measurements
    if (normalized.contains('cup')) return 'cups';
    if (normalized.contains('tablespoon') || normalized == 'tbsp' || normalized == 'tb') return 'tablespoons';
    if (normalized.contains('teaspoon') || normalized == 'tsp' || normalized == 'ts') return 'teaspoons';
    if (normalized.contains('fl oz') || normalized == 'fluid ounce') return 'fl oz';
    if (normalized.contains('gallon') || normalized == 'gal') return 'gallons';
    if (normalized.contains('liter') || normalized == 'l') return 'liters';
    if (normalized.contains('ml') || normalized.contains('milliliter')) return 'ml';
    if (normalized.contains('pint') || normalized == 'pt') return 'pints';
    if (normalized.contains('quart') || normalized == 'qt') return 'quarts';
    
    // Weight measurements
    if (normalized.contains('pound') || normalized == 'lb' || normalized == 'lbs') return 'lbs';
    if (normalized.contains('ounce') || normalized == 'oz') return 'oz';
    if (normalized.contains('gram') || normalized == 'g') return 'grams';
    if (normalized.contains('kilogram') || normalized == 'kg') return 'kg';
    
    // Countable items
    if (normalized.contains('bunch')) return 'bunches';
    if (normalized.contains('head')) return 'heads';
    if (normalized.contains('large') || normalized == 'lg') return 'large';
    if (normalized.contains('medium') || normalized == 'med') return 'medium';
    if (normalized.contains('small') || normalized == 'sm') return 'small';
    if (normalized.contains('can')) return 'cans';
    if (normalized.contains('package') || normalized.contains('pkg')) return 'packages';
    if (normalized.contains('clove')) return 'cloves';
    
    // Default to "each" for countable items
    return 'each';
  }
}

/// Line item for shopping list or recipe
class InstacartLineItem {
  final String name;
  final List<InstacartMeasurement>? measurements;
  final String? displayText;
  final Map<String, dynamic>? filters;

  const InstacartLineItem({
    required this.name,
    this.measurements,
    this.displayText,
    this.filters,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
    };
    
    if (measurements != null && measurements!.isNotEmpty) {
      json['line_item_measurements'] = measurements!.map((m) => m.toJson()).toList();
    }
    
    if (displayText != null) {
      json['display_text'] = displayText;
    }
    
    if (filters != null) {
      json['filters'] = filters;
    }
    
    return json;
  }

  /// Create from a recipe ingredient
  factory InstacartLineItem.fromIngredient({
    required String name,
    double? quantity,
    String? unit,
    String? displayText,
  }) {
    List<InstacartMeasurement>? measurements;
    
    if (quantity != null && quantity > 0) {
      measurements = [
        InstacartMeasurement(
          unit: unit != null ? InstacartMeasurement.normalizeUnit(unit) : 'each',
          quantity: quantity,
        ),
      ];
    }
    
    return InstacartLineItem(
      name: name,
      measurements: measurements,
      displayText: displayText ?? name,
    );
  }
}

/// Request to create a shopping list page
class CreateShoppingListRequest {
  final String title;
  final List<InstacartLineItem> lineItems;
  final String? imageUrl;
  final String? linkType; // 'shopping_list' or 'recipe'
  final String? partnerLinkbackUrl;

  const CreateShoppingListRequest({
    required this.title,
    required this.lineItems,
    this.imageUrl,
    this.linkType = 'shopping_list',
    this.partnerLinkbackUrl,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'title': title,
      'line_items': lineItems.map((item) => item.toJson()).toList(),
    };
    
    if (imageUrl != null) {
      json['image_url'] = imageUrl;
    }
    
    if (linkType != null) {
      json['link_type'] = linkType;
    }
    
    if (partnerLinkbackUrl != null) {
      json['partner_linkback_url'] = partnerLinkbackUrl;
    }
    
    return json;
  }
}

/// Request to create a recipe page
class CreateRecipePageRequest {
  final String title;
  final List<InstacartLineItem> lineItems;
  final String? imageUrl;
  final String? author;
  final int? servings;
  final int? prepTime; // in minutes
  final int? cookTime; // in minutes
  final List<String>? instructions;
  final String? partnerLinkbackUrl;

  const CreateRecipePageRequest({
    required this.title,
    required this.lineItems,
    this.imageUrl,
    this.author,
    this.servings,
    this.prepTime,
    this.cookTime,
    this.instructions,
    this.partnerLinkbackUrl,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'title': title,
      'line_items': lineItems.map((item) => item.toJson()).toList(),
      'link_type': 'recipe',
    };
    
    if (imageUrl != null) json['image_url'] = imageUrl;
    if (author != null) json['author'] = author;
    if (servings != null) json['servings'] = servings;
    if (prepTime != null) json['prep_time'] = prepTime;
    if (cookTime != null) json['cook_time'] = cookTime;
    if (instructions != null) json['instructions'] = instructions;
    if (partnerLinkbackUrl != null) json['partner_linkback_url'] = partnerLinkbackUrl;
    
    return json;
  }
}

/// Response from creating a shopping list or recipe page
class InstacartLinkResponse {
  final String? productsLinkUrl;
  final String? error;
  final bool success;

  const InstacartLinkResponse({
    this.productsLinkUrl,
    this.error,
    required this.success,
  });

  factory InstacartLinkResponse.fromJson(Map<String, dynamic> json) {
    return InstacartLinkResponse(
      productsLinkUrl: json['products_link_url'] as String?,
      success: json['products_link_url'] != null,
    );
  }

  factory InstacartLinkResponse.error(String message) {
    return InstacartLinkResponse(
      error: message,
      success: false,
    );
  }
}

/// Retailer information
class InstacartRetailer {
  final String id;
  final String name;
  final String? logoUrl;
  final String? address;
  final String? postalCode;
  final double? distance; // in miles
  final bool isAvailable;

  const InstacartRetailer({
    required this.id,
    required this.name,
    this.logoUrl,
    this.address,
    this.postalCode,
    this.distance,
    this.isAvailable = true,
  });

  factory InstacartRetailer.fromJson(Map<String, dynamic> json) {
    // Parse address from various possible structures
    String? address = json['address'] as String?;
    
    // Try to build address from location object if direct address is null
    if (address == null && json['location'] != null) {
      final location = json['location'] as Map<String, dynamic>;
      final parts = <String>[];
      
      if (location['address_line_1'] != null) {
        parts.add(location['address_line_1'] as String);
      }
      if (location['city'] != null) {
        parts.add(location['city'] as String);
      }
      if (location['state'] != null) {
        final state = location['state'] as String;
        if (location['zip_code'] != null) {
          parts.add('$state ${location['zip_code']}');
        } else {
          parts.add(state);
        }
      }
      
      if (parts.isNotEmpty) {
        address = parts.join(', ');
      }
    }
    
    // Try formatted_address field
    address ??= json['formatted_address'] as String?;
    
    // Try address fields at root level
    if (address == null) {
      final parts = <String>[];
      if (json['address_line_1'] != null) parts.add(json['address_line_1'] as String);
      if (json['city'] != null) parts.add(json['city'] as String);
      if (json['state'] != null) {
        final state = json['state'] as String;
        if (json['zip_code'] != null) {
          parts.add('$state ${json['zip_code']}');
        } else {
          parts.add(state);
        }
      }
      if (parts.isNotEmpty) {
        address = parts.join(', ');
      }
    }
    
    return InstacartRetailer(
      id: json['id']?.toString() ?? json['retailer_key']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown Store',
      logoUrl: json['retailer_logo_url'] as String? ?? json['logo_url'] as String?,
      address: address,
      postalCode: json['postal_code'] as String? ?? json['zip_code'] as String?,
      distance: (json['distance'] as num?)?.toDouble(),
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  /// Create a copy with updated postal code (for when we know the search postal code)
  InstacartRetailer withPostalCode(String postalCode) {
    return InstacartRetailer(
      id: id,
      name: name,
      logoUrl: logoUrl,
      address: address,
      postalCode: postalCode,
      distance: distance,
      isAvailable: isAvailable,
    );
  }
}

/// Response from getting nearby retailers
class NearbyRetailersResponse {
  final List<InstacartRetailer> retailers;
  final String? error;
  final bool success;

  const NearbyRetailersResponse({
    required this.retailers,
    this.error,
    required this.success,
  });

  factory NearbyRetailersResponse.fromJson(Map<String, dynamic> json) {
    final retailersList = (json['retailers'] as List?)
        ?.map((r) => InstacartRetailer.fromJson(r as Map<String, dynamic>))
        .toList() ?? [];
    
    return NearbyRetailersResponse(
      retailers: retailersList,
      success: true,
    );
  }

  factory NearbyRetailersResponse.error(String message) {
    return NearbyRetailersResponse(
      retailers: [],
      error: message,
      success: false,
    );
  }
}

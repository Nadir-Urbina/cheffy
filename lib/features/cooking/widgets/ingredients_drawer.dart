import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/recipe_model.dart';
import '../../../core/theme/app_colors.dart';

/// Bottom sheet drawer showing all recipe ingredients
class IngredientsDrawer extends StatelessWidget {
  final List<RecipeIngredient> ingredients;
  final Function(RecipeIngredient)? onIngredientTap;

  const IngredientsDrawer({
    super.key,
    required this.ingredients,
    this.onIngredientTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.list_alt,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ingredients',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${ingredients.length} items',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Ingredients list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: ingredients.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, index) {
                final ingredient = ingredients[index];
                return _IngredientTile(
                  ingredient: ingredient,
                  onTap: onIngredientTap != null 
                      ? () => onIngredientTap!(ingredient)
                      : null,
                );
              },
            ),
          ),
          // Tip
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap an ingredient to hear the amount',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _IngredientTile extends StatefulWidget {
  final RecipeIngredient ingredient;
  final VoidCallback? onTap;

  const _IngredientTile({
    required this.ingredient,
    this.onTap,
  });

  @override
  State<_IngredientTile> createState() => _IngredientTileState();
}

class _IngredientTileState extends State<_IngredientTile> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        widget.onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => setState(() => _isChecked = !_isChecked),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _isChecked ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isChecked ? AppColors.primary : AppColors.border,
                    width: 2,
                  ),
                ),
                child: _isChecked
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            // Ingredient info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ingredient.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _isChecked 
                          ? AppColors.textSecondary 
                          : AppColors.textPrimary,
                      decoration: _isChecked 
                          ? TextDecoration.lineThrough 
                          : null,
                    ),
                  ),
                  if (widget.ingredient.quantity > 0 || 
                      widget.ingredient.unit.isNotEmpty)
                    Text(
                      _formatAmount(),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        decoration: _isChecked 
                            ? TextDecoration.lineThrough 
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            // Speak button
            if (widget.onTap != null)
              IconButton(
                icon: Icon(
                  Icons.volume_up_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: widget.onTap,
              ),
          ],
        ),
      ),
    );
  }

  String _formatAmount() {
    final quantity = widget.ingredient.quantity;
    final unit = widget.ingredient.unit;
    
    if (quantity > 0 && unit.isNotEmpty) {
      return '${_formatQuantity(quantity)} $unit';
    } else if (quantity > 0) {
      return _formatQuantity(quantity);
    } else if (unit.isNotEmpty) {
      return unit;
    }
    return '';
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    
    // Handle common fractions
    final whole = quantity.floor();
    final fraction = quantity - whole;
    
    String fractionStr = '';
    if ((fraction - 0.5).abs() < 0.01) {
      fractionStr = '½';
    } else if ((fraction - 0.25).abs() < 0.01) {
      fractionStr = '¼';
    } else if ((fraction - 0.75).abs() < 0.01) {
      fractionStr = '¾';
    } else if ((fraction - 0.33).abs() < 0.05) {
      fractionStr = '⅓';
    } else if ((fraction - 0.67).abs() < 0.05) {
      fractionStr = '⅔';
    } else {
      return quantity.toStringAsFixed(1);
    }
    
    if (whole > 0) {
      return '$whole $fractionStr';
    }
    return fractionStr;
  }
}

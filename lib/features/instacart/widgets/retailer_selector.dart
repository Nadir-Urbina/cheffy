import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/instacart_models.dart';
import '../../../core/services/instacart_service.dart';
import '../../../core/theme/app_colors.dart';

/// Bottom sheet for selecting a nearby retailer for Instacart shopping
class RetailerSelectorSheet extends StatefulWidget {
  final String? initialPostalCode;
  final Function(InstacartRetailer retailer)? onRetailerSelected;

  const RetailerSelectorSheet({
    super.key,
    this.initialPostalCode,
    this.onRetailerSelected,
  });

  /// Show the retailer selector as a bottom sheet
  static Future<InstacartRetailer?> show(
    BuildContext context, {
    String? initialPostalCode,
  }) async {
    return showModalBottomSheet<InstacartRetailer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RetailerSelectorSheet(
        initialPostalCode: initialPostalCode,
      ),
    );
  }

  @override
  State<RetailerSelectorSheet> createState() => _RetailerSelectorSheetState();
}

class _RetailerSelectorSheetState extends State<RetailerSelectorSheet> {
  final _instacartService = InstacartService();
  final _postalCodeController = TextEditingController();
  
  List<InstacartRetailer> _retailers = [];
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  String? _error;
  InstacartRetailer? _selectedRetailer;
  bool _locationPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPostalCode != null) {
      _postalCodeController.text = widget.initialPostalCode!;
      _searchRetailers();
    } else {
      // Try to get location automatically on first open
      _checkAndRequestLocation();
    }
  }

  Future<void> _checkAndRequestLocation() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return; // Location services disabled, user can enter manually
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Don't auto-request, wait for user to tap the button
      return;
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationPermissionDenied = true);
      return;
    }

    // We have permission, get location
    await _getLocationAndSearch();
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable location services'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          setState(() => _isLoadingLocation = false);
        }
        return;
      }

      // Request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() => _isLoadingLocation = false);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationPermissionDenied = true;
            _isLoadingLocation = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission denied. Please enable in Settings.'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      // Permission granted, get location
      await _getLocationAndSearch();
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _getLocationAndSearch() async {
    try {
      setState(() => _isLoadingLocation = true);

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // Low accuracy is faster and sufficient for ZIP
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Reverse geocode to get postal code
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && placemarks.first.postalCode != null) {
        final postalCode = placemarks.first.postalCode!;
        if (mounted) {
          setState(() {
            _postalCodeController.text = postalCode;
            _isLoadingLocation = false;
          });
          // Auto-search with the detected location
          _searchRetailers();
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not determine your ZIP code'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  void dispose() {
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _searchRetailers() async {
    final postalCode = _postalCodeController.text.trim();
    if (postalCode.isEmpty) {
      setState(() => _error = 'Please enter a postal code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _instacartService.getNearbyRetailers(
        postalCode: postalCode,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success) {
            _retailers = response.retailers;
            if (_retailers.isEmpty) {
              _error = 'No stores found near $postalCode';
            }
          } else {
            _error = response.error ?? 'Failed to find stores';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error searching for stores';
        });
      }
    }
  }

  void _selectRetailer(InstacartRetailer retailer) {
    HapticFeedback.selectionClick();
    setState(() => _selectedRetailer = retailer);
  }

  void _confirmSelection() {
    if (_selectedRetailer != null) {
      HapticFeedback.mediumImpact();
      // Attach the postal code used for the search
      final postalCode = _postalCodeController.text.trim();
      final retailerWithPostal = _selectedRetailer!.withPostalCode(postalCode);
      widget.onRetailerSelected?.call(retailerWithPostal);
      Navigator.of(context).pop(retailerWithPostal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF43B02A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.store,
                        color: Color(0xFF43B02A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Your Store',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Select where to shop on Instacart',
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
                const SizedBox(height: 16),
                // Use My Location button
                if (!_locationPermissionDenied)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingLocation ? null : _requestLocationPermission,
                        icon: _isLoadingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Color(0xFF43B02A)),
                                ),
                              )
                            : const Icon(Icons.my_location, size: 20),
                        label: Text(
                          _isLoadingLocation ? 'Finding your location...' : 'Use My Location',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF43B02A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF43B02A), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Postal code input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _postalCodeController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Enter ZIP code',
                          hintStyle: GoogleFonts.poppins(
                            color: AppColors.textHint,
                          ),
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: AppColors.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) => _searchRetailers(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _searchRetailers,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF43B02A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Divider
          const Divider(height: 1),
          // Content
          Flexible(
            child: _buildContent(),
          ),
          // Confirm button
          if (_selectedRetailer != null)
            Container(
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
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirmSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF43B02A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Shop at ${_selectedRetailer!.name}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null && _retailers.isEmpty) {
      return _buildEmptyState();
    }

    if (_retailers.isEmpty && !_isLoading) {
      return _buildInitialState();
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _retailers.length,
      itemBuilder: (context, index) {
        final retailer = _retailers[index];
        // Use identical() for object identity comparison
        // This works because we're comparing the exact same object from _retailers list
        final isSelected = identical(_selectedRetailer, retailer);
        
        return _RetailerTile(
          retailer: retailer,
          isSelected: isSelected,
          onTap: () => _selectRetailer(retailer),
        );
      },
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Find Stores Near You',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your ZIP code to see available Instacart stores in your area',
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.store_mall_directory_outlined,
                size: 48,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Stores Found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Try a different ZIP code',
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

/// Individual retailer tile
class _RetailerTile extends StatelessWidget {
  final InstacartRetailer retailer;
  final bool isSelected;
  final VoidCallback onTap;

  const _RetailerTile({
    required this.retailer,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF43B02A).withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF43B02A)
                : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Store logo/icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: retailer.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        retailer.logoUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _buildDefaultIcon(),
                      ),
                    )
                  : _buildDefaultIcon(),
            ),
            const SizedBox(width: 12),
            // Store info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    retailer.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (retailer.address != null && retailer.address!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            retailer.address!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (retailer.distance != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_walk,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${retailer.distance!.toStringAsFixed(1)} mi away',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Selection indicator
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF43B02A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.border,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Center(
      child: Icon(
        Icons.storefront,
        size: 28,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
    );
  }
}

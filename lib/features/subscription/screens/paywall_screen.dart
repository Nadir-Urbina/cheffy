import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/services/subscription_service.dart';
import '../../../core/theme/app_colors.dart';

/// Premium paywall screen with monthly/yearly options.
class PaywallScreen extends StatefulWidget {
  /// Optional message shown at the top explaining why they need premium.
  final String? featureName;

  const PaywallScreen({super.key, this.featureName});

  /// Show the paywall as a modal bottom sheet or full-screen push.
  static Future<bool> show(BuildContext context, {String? featureName}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaywallScreen(featureName: featureName),
      ),
    );
    return result ?? false;
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _subscriptionService = SubscriptionService();

  Offerings? _offerings;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  int _selectedPlanIndex = 1; // Default to yearly (best value)

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final offerings = await _subscriptionService.getOfferings();
    debugPrint('📦 Offerings loaded: ${offerings != null}');
    debugPrint('📦 Current offering: ${offerings?.current?.identifier}');
    debugPrint('📦 Available packages: ${offerings?.current?.availablePackages.map((p) => '${p.packageType}: ${p.storeProduct.identifier}').toList()}');
    if (mounted) {
      setState(() {
        _offerings = offerings;
        _isLoading = false;
      });
    }
  }

  List<Package> get _availablePackages {
    final current = _offerings?.current;
    if (current == null) return [];
    return current.availablePackages;
  }

  Package? get _monthlyPackage {
    try {
      return _availablePackages.firstWhere(
        (p) => p.packageType == PackageType.monthly,
      );
    } catch (_) {
      return _availablePackages.isNotEmpty ? _availablePackages.first : null;
    }
  }

  Package? get _annualPackage {
    try {
      return _availablePackages.firstWhere(
        (p) => p.packageType == PackageType.annual,
      );
    } catch (_) {
      return _availablePackages.length > 1 ? _availablePackages[1] : null;
    }
  }

  Future<void> _purchase(Package package) async {
    HapticFeedback.mediumImpact();
    setState(() => _isPurchasing = true);

    final success = await _subscriptionService.purchasePackage(package);

    if (mounted) {
      setState(() => _isPurchasing = false);
      if (success) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _isRestoring = true);

    final success = await _subscriptionService.restorePurchases();

    if (mounted) {
      setState(() => _isRestoring = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No active subscription found',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildFeatureContext(),
                    const SizedBox(height: 24),
                    _buildFeaturesList(),
                    const SizedBox(height: 28),
                    _buildPlanSelector(),
                    const SizedBox(height: 24),
                    _buildSubscribeButton(),
                    const SizedBox(height: 12),
                    _buildRestoreButton(),
                    const SizedBox(height: 8),
                    _buildLegalLinks(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.85),
                const Color(0xFF0D8A56),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Brand logo
              Image.asset(
                'assets/images/My Chefsito App Brand Image.png',
                height: 80,
              ),
              const SizedBox(height: 16),
              Text(
                'Upgrade to Chefsito Pro',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock the full cooking experience',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // Close button
        Positioned(
          top: 8,
          right: 12,
          child: IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close, color: Colors.white70, size: 26),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureContext() {
    if (widget.featureName == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${widget.featureName} is a Pro feature',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      _FeatureItem(
        icon: Icons.camera_alt_outlined,
        title: 'Scan Your Ingredients',
        subtitle: 'AI-powered ingredient recognition',
      ),
      _FeatureItem(
        icon: Icons.videocam_outlined,
        title: 'Video Recipe Extraction',
        subtitle: 'Turn any cooking video into a recipe',
      ),
      _FeatureItem(
        icon: Icons.restaurant_outlined,
        title: 'Cooking Mode',
        subtitle: 'Step-by-step guidance with voice control',
      ),
      _FeatureItem(
        icon: Icons.record_voice_over_outlined,
        title: 'Conversational Mode',
        subtitle: 'Hands-free voice commands while cooking',
      ),
      _FeatureItem(
        icon: Icons.auto_fix_high,
        title: 'AI-Generated Instructions',
        subtitle: 'Get steps for any recipe automatically',
      ),
      _FeatureItem(
        icon: Icons.shopping_cart_outlined,
        title: 'Instacart Integration',
        subtitle: 'Shop ingredients with one tap',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Everything in Pro',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(f.icon, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.title,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            f.subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    final monthly = _monthlyPackage;
    final annual = _annualPackage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          if (annual != null)
            _PlanCard(
              title: 'Yearly',
              price: annual.storeProduct.priceString,
              period: '/year',
              savings: 'Save 44%',
              isSelected: _selectedPlanIndex == 1,
              onTap: () => setState(() => _selectedPlanIndex = 1),
            ),
          const SizedBox(height: 10),
          if (monthly != null)
            _PlanCard(
              title: 'Monthly',
              price: monthly.storeProduct.priceString,
              period: '/month',
              isSelected: _selectedPlanIndex == 0,
              onTap: () => setState(() => _selectedPlanIndex = 0),
            ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton() {
    final package = _selectedPlanIndex == 1 ? _annualPackage : _monthlyPackage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: (_isPurchasing || package == null)
              ? null
              : () => _purchase(package),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: _isPurchasing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  'Start 7-Day Free Trial',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: _isRestoring ? null : _restore,
      child: _isRestoring
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              'Restore Purchases',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
    );
  }

  Widget _buildLegalLinks() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        'Payment will be charged to your Apple ID account. '
        'Subscription automatically renews unless canceled at least '
        '24 hours before the end of the current period.',
        style: GoogleFonts.poppins(
          color: AppColors.textHint,
          fontSize: 10,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;

  _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? savings;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    this.savings,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textHint,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            // Plan details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (savings != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            savings!,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (savings != null)
                    Text(
                      'Just \$3.33/month',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            // Price
            Text(
              '$price$period',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

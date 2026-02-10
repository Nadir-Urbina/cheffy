import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Manages RevenueCat subscriptions and premium entitlement checks.
///
/// Free features: Recipe search, Chat
/// Premium features: Scan Ingredients, Video Recipe, Cooking Mode, AI Instructions
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  static const String _entitlementId = 'My Chefsito Pro';

  bool _initialized = false;
  bool _isPremium = false;

  /// Whether the user has an active premium subscription.
  bool get isPremium => _isPremium;

  /// Initialize RevenueCat SDK. Call once at app start.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final String apiKey;
      if (Platform.isIOS) {
        apiKey = 'appl_hysyeGAgkgEQmocflAqkjUjuSVn';
      } else if (Platform.isAndroid) {
        apiKey = 'appl_hysyeGAgkgEQmocflAqkjUjuSVn'; // Replace with Google key when ready
      } else {
        debugPrint('⚠️ RevenueCat: Platform not supported');
        return;
      }

      await Purchases.configure(PurchasesConfiguration(apiKey));
      _initialized = true;

      // Check initial entitlement status
      await refreshPremiumStatus();

      // Listen for changes
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updatePremiumStatus(customerInfo);
      });

      debugPrint('✅ RevenueCat initialized (premium: $_isPremium)');
    } catch (e) {
      debugPrint('❌ RevenueCat initialization failed: $e');
    }
  }

  /// Refresh premium status from RevenueCat.
  Future<bool> refreshPremiumStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus(customerInfo);
      return _isPremium;
    } catch (e) {
      debugPrint('❌ Failed to check premium status: $e');
      return _isPremium;
    }
  }

  void _updatePremiumStatus(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.all[_entitlementId];
    _isPremium = entitlement?.isActive ?? false;
    debugPrint('🔑 Premium status: $_isPremium');
  }

  /// Get the current offerings (products/prices) from RevenueCat.
  Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings;
    } catch (e) {
      debugPrint('❌ Failed to get offerings: $e');
      return null;
    }
  }

  /// Purchase a specific package.
  Future<bool> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      _updatePremiumStatus(result.customerInfo);
      return _isPremium;
    } catch (e) {
      // User cancelled or other purchase error
      debugPrint('⚠️ Purchase cancelled or failed: $e');
      return false;
    }
  }

  /// Restore previous purchases.
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updatePremiumStatus(customerInfo);
      return _isPremium;
    } catch (e) {
      debugPrint('❌ Restore purchases failed: $e');
      return false;
    }
  }

  /// Log in a user (call after Firebase auth).
  Future<void> loginUser(String userId) async {
    if (!_initialized) return;
    try {
      final result = await Purchases.logIn(userId);
      _updatePremiumStatus(result.customerInfo);
    } catch (e) {
      debugPrint('❌ RevenueCat login failed: $e');
    }
  }

  /// Log out (call on Firebase sign out).
  Future<void> logoutUser() async {
    if (!_initialized) return;
    try {
      await Purchases.logOut();
      _isPremium = false;
    } catch (e) {
      debugPrint('❌ RevenueCat logout failed: $e');
    }
  }
}

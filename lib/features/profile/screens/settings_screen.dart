import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/user_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import 'cooking_preferences_screen.dart';

class SettingsScreen extends StatefulWidget {
  final FirebaseAuthService authService;

  const SettingsScreen({super.key, required this.authService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _preferencesService = PreferencesService();

  bool _useMetricUnits = true;
  bool _isLoading = true;
  String? _provider;
  UserPreferences? _userPreferences;

  // TODO: Update these URLs with your actual policy links
  static const String _privacyPolicyUrl = 'https://turbinapps.com/privacy';
  static const String _termsOfServiceUrl = 'https://turbinapps.com/terms';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    // Load measurement unit preference
    final prefs = await SharedPreferences.getInstance();
    _useMetricUnits = prefs.getBool('useMetricUnits') ?? true;

    // Load provider
    _provider = await widget.authService.getUserProvider();

    // Load user preferences
    _userPreferences = await _preferencesService.getPreferences(user.uid);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleMeasurementUnits(bool useMetric) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useMetricUnits', useMetric);
    setState(() => _useMetricUnits = useMetric);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Using ${useMetric ? 'metric' : 'imperial'} units'),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Cache',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will clear cached recipes and images. Your saved data will not be affected.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear SharedPreferences cache keys (not user preferences)
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = prefs.getKeys().where((key) => 
        key.startsWith('cache_') || key.startsWith('recipe_cache_')
      ).toList();
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache cleared'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showDeleteAccountFlow() {
    // If provider is email, need to re-authenticate
    if (_provider == 'email') {
      _showReauthenticateSheet();
    } else {
      // For Google/Apple, skip to warning
      _showDeleteWarning();
    }
  }

  void _showReauthenticateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReauthenticateSheet(
        authService: widget.authService,
        onSuccess: () {
          Navigator.pop(context);
          _showDeleteWarning();
        },
      ),
    );
  }

  void _showDeleteWarning() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DeleteAccountWarningScreen(
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Preferences Section
                _buildSectionHeader('Preferences'),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  icon: Icons.restaurant_menu,
                  title: 'Cooking Preferences',
                  subtitle: 'Dietary restrictions, cuisines, skill level',
                  onTap: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CookingPreferencesScreen(
                          userPreferences: _userPreferences,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadSettings(); // Reload preferences
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildMeasurementUnitsTile(),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Instacart Settings',
                  subtitle: _userPreferences?.preferredRetailerName ?? 'Set your preferred store',
                  onTap: () {
                    // TODO: Navigate to Instacart settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Coming soon'),
                        backgroundColor: AppColors.textPrimary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Data Section
                _buildSectionHeader('Data'),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear Cache',
                  subtitle: 'Free up storage space',
                  onTap: _clearCache,
                ),

                const SizedBox(height: 32),

                // Legal Section
                _buildSectionHeader('Legal'),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we handle your data',
                  onTap: () => _launchUrl(_privacyPolicyUrl),
                  showChevron: false,
                  trailing: const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  subtitle: 'Rules and guidelines',
                  onTap: () => _launchUrl(_termsOfServiceUrl),
                  showChevron: false,
                  trailing: const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                // Danger Zone
                _buildSectionHeader('Account', color: AppColors.error),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  icon: Icons.delete_outline,
                  title: 'Delete Account',
                  subtitle: 'Permanently remove your data',
                  onTap: _showDeleteAccountFlow,
                  iconColor: AppColors.error,
                  titleColor: AppColors.error,
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showChevron = true,
    Widget? trailing,
    Color? iconColor,
    Color? titleColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                (showChevron
                    ? const Icon(Icons.chevron_right, color: AppColors.textSecondary)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementUnitsTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.straighten,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Measurement Units',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _useMetricUnits ? 'Metric (g, ml, °C)' : 'Imperial (oz, cups, °F)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildUnitOption('Metric', _useMetricUnits, () => _toggleMeasurementUnits(true)),
                const SizedBox(width: 4),
                _buildUnitOption('Imperial', !_useMetricUnits, () => _toggleMeasurementUnits(false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitOption(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Re-authenticate sheet for email users
class _ReauthenticateSheet extends StatefulWidget {
  final FirebaseAuthService authService;
  final VoidCallback onSuccess;

  const _ReauthenticateSheet({
    required this.authService,
    required this.onSuccess,
  });

  @override
  State<_ReauthenticateSheet> createState() => _ReauthenticateSheetState();
}

class _ReauthenticateSheetState extends State<_ReauthenticateSheet> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user logged in');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordController.text,
      );

      await user.reauthenticateWithCredential(credential);
      widget.onSuccess();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.code == 'wrong-password' 
            ? 'Incorrect password' 
            : 'Authentication failed';
      });
    } catch (e) {
      setState(() => _error = 'Authentication failed');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Confirm Your Identity',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please enter your password to continue',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: GoogleFonts.poppins(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                errorText: _error,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Continue',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Delete account warning screen
class _DeleteAccountWarningScreen extends StatefulWidget {
  final FirebaseAuthService authService;

  const _DeleteAccountWarningScreen({required this.authService});

  @override
  State<_DeleteAccountWarningScreen> createState() => _DeleteAccountWarningScreenState();
}

class _DeleteAccountWarningScreenState extends State<_DeleteAccountWarningScreen> {
  bool _isDeleting = false;

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Mark account for deletion in Firestore
      // The Cloud Function will handle the actual deletion
      await FirebaseFirestore.instance.collection('account_deletions').doc(user.uid).set({
        'userId': user.uid,
        'email': user.email,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Sign out the user
      await widget.authService.signOut();

      if (mounted) {
        // Show farewell screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const _FarewellScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Delete Account',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.error,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            
            // Warning icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 60,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'Are you sure?',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'This action cannot be undone. All your data will be permanently deleted, including:',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // What will be deleted
            _buildDeleteItem('Your profile and preferences'),
            _buildDeleteItem('Saved recipes and meal plans'),
            _buildDeleteItem('Cooking history'),
            _buildDeleteItem('All account data'),

            const Spacer(),

            // Buttons
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isDeleting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Keep My Account',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isDeleting ? null : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Delete My Account',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.remove_circle_outline,
            size: 18,
            color: AppColors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Farewell screen shown after account deletion
class _FarewellScreen extends StatelessWidget {
  const _FarewellScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Goodbye illustration
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.waving_hand,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Goodbye!',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Your account has been scheduled for deletion. We\'re sorry to see you go!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'If you ever change your mind, we\'d love to have you back. Happy cooking!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Restart the app by navigating to the auth wrapper
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

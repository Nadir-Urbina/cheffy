import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  final FirebaseAuthService authService;

  const EditProfileScreen({super.key, required this.authService});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _preferencesService = PreferencesService();
  final _storageService = StorageService();

  late TextEditingController _nameController;
  late TextEditingController _bioController;

  int _householdSize = 2;
  String? _provider;
  String? _photoUrl;
  File? _selectedImage;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    // Load display name and photo from Firebase Auth
    _nameController.text = user.displayName ?? '';
    _photoUrl = user.photoURL;

    // Load bio and provider from Firestore
    final bio = await widget.authService.getUserBio();
    final provider = await widget.authService.getUserProvider();

    // Load household size from preferences
    final prefs = await _preferencesService.getPreferences(user.uid);

    if (mounted) {
      setState(() {
        _bioController.text = bio ?? '';
        _provider = provider;
        _householdSize = prefs?.householdSize ?? 2;
        _isLoading = false;
      });
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Change Profile Photo',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _PhotoOptionTile(
              icon: Icons.camera_alt_outlined,
              title: 'Take Photo',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            _PhotoOptionTile(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_photoUrl != null || _selectedImage != null)
              _PhotoOptionTile(
                icon: Icons.delete_outline,
                title: 'Remove Photo',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _storageService.pickImage(source: source);
    if (image != null && mounted) {
      setState(() => _selectedImage = image);
      _uploadPhoto(image);
    }
  }

  Future<void> _uploadPhoto(File image) async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final result = await _storageService.uploadProfilePhoto(
        userId: user.uid,
        imageFile: image,
      );

      if (!mounted) return;

      if (result.success && result.downloadUrl != null) {
        // Update auth profile with new URL
        final updateResult = await widget.authService.updatePhotoUrl(result.downloadUrl!);
        
        if (updateResult.success) {
          setState(() => _photoUrl = result.downloadUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo updated successfully'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          throw Exception(updateResult.errorMessage);
        }
      } else {
        throw Exception(result.error);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _selectedImage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _removePhoto() async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      // Delete from storage
      await _storageService.deleteProfilePhoto(user.uid);

      // Update auth profile to remove URL
      final updateResult = await widget.authService.updatePhotoUrl('');

      if (mounted) {
        if (updateResult.success) {
          setState(() {
            _photoUrl = null;
            _selectedImage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo removed'),
              backgroundColor: AppColors.textPrimary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove photo'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = widget.authService.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Update display name
      final nameResult =
          await widget.authService.updateDisplayName(_nameController.text.trim());
      if (!nameResult.success) {
        throw Exception(nameResult.errorMessage);
      }

      // Update bio
      final bioResult =
          await widget.authService.updateBio(_bioController.text.trim());
      if (!bioResult.success) {
        throw Exception(bioResult.errorMessage);
      }

      // Update household size
      await _preferencesService.updateHouseholdSize(user.uid, _householdSize);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes were made
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChangePasswordSheet(authService: widget.authService),
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
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile picture section
                    _buildProfilePictureSection(),
                    const SizedBox(height: 32),

                    // Display Name
                    _buildSectionLabel('Display Name'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'Your name',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Bio
                    _buildSectionLabel('Bio'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _bioController,
                      hint: 'Tell us about yourself...',
                      maxLines: 3,
                      maxLength: 150,
                    ),
                    const SizedBox(height: 24),

                    // Household Size
                    _buildSectionLabel('Household Size'),
                    const SizedBox(height: 4),
                    Text(
                      'Helps us suggest appropriate serving sizes',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildHouseholdSizeSelector(),
                    const SizedBox(height: 32),

                    // Change Password (only for email users)
                    if (_provider == 'email') ...[
                      _buildSectionLabel('Security'),
                      const SizedBox(height: 12),
                      _buildChangePasswordButton(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfilePictureSection() {
    final displayName = _nameController.text.isNotEmpty 
        ? _nameController.text 
        : widget.authService.currentUser?.displayName ?? '';

    // Determine what image to show
    ImageProvider? imageProvider;
    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!);
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_photoUrl!);
    }

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploadingPhoto ? null : _showPhotoOptions,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                  backgroundImage: imageProvider,
                  child: _isUploadingPhoto
                      ? const CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        )
                      : imageProvider == null
                          ? Text(
                              (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isUploadingPhoto ? null : _showPhotoOptions,
            child: Text(
              _isUploadingPhoto ? 'Uploading...' : 'Change Photo',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _isUploadingPhoto ? AppColors.textSecondary : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      style: GoogleFonts.poppins(
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          fontSize: 15,
          color: AppColors.textHint,
        ),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildHouseholdSizeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(6, (index) {
          final size = index + 1;
          final isSelected = _householdSize == size;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _householdSize = size);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    size == 6 ? '6+' : '$size',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildChangePasswordButton() {
    return GestureDetector(
      onTap: _showChangePasswordSheet,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
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
                Icons.lock_outline,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change Password',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Update your account password',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for changing password
class _ChangePasswordSheet extends StatefulWidget {
  final FirebaseAuthService authService;

  const _ChangePasswordSheet({required this.authService});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await widget.authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      if (result.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Failed to change password'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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

              // Title
              Text(
                'Change Password',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your current password and choose a new one',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Current Password
              _buildPasswordField(
                controller: _currentPasswordController,
                label: 'Current Password',
                obscure: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // New Password
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'New Password',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm Password
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                obscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
                          'Update Password',
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}

/// Option tile for photo selection bottom sheet
class _PhotoOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _PhotoOptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isDestructive ? AppColors.error : AppColors.primary)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isDestructive ? AppColors.error : AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}

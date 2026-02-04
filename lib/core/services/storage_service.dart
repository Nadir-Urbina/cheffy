import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Service for handling file uploads to Firebase Storage
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick an image from gallery or camera
  Future<File?> pickImage({
    required ImageSource source,
    int maxWidth = 512,
    int maxHeight = 512,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Upload profile photo and return the download URL
  Future<StorageResult> uploadProfilePhoto({
    required String userId,
    required File imageFile,
  }) async {
    try {
      // Create a reference to the profile photo location
      final ref = _storage.ref().child('profile_photos').child('$userId.jpg');

      // Upload the file
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Profile photo uploaded: $downloadUrl');
      return StorageResult.success(downloadUrl);
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase Storage error: ${e.code} - ${e.message}');
      return StorageResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return StorageResult.failure('Failed to upload photo');
    }
  }

  /// Delete profile photo
  Future<bool> deleteProfilePhoto(String userId) async {
    try {
      final ref = _storage.ref().child('profile_photos').child('$userId.jpg');
      await ref.delete();
      debugPrint('✅ Profile photo deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      return false;
    }
  }

  /// Convert Firebase Storage error codes to user-friendly messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'storage/unauthorized':
        return 'You don\'t have permission to upload photos';
      case 'storage/canceled':
        return 'Upload was cancelled';
      case 'storage/unknown':
        return 'An unknown error occurred';
      case 'storage/object-not-found':
        return 'Photo not found';
      case 'storage/quota-exceeded':
        return 'Storage quota exceeded';
      case 'storage/retry-limit-exceeded':
        return 'Upload failed. Please try again';
      default:
        return 'Failed to upload photo';
    }
  }
}

/// Result of a storage operation
class StorageResult {
  final bool success;
  final String? downloadUrl;
  final String? error;

  StorageResult.success(this.downloadUrl)
      : success = true,
        error = null;

  StorageResult.failure(this.error)
      : success = false,
        downloadUrl = null;
}

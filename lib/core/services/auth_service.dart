import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Result wrapper for authentication operations
class AuthResult {
  final User? user;
  final String? errorMessage;
  final bool success;

  AuthResult.success(this.user)
      : success = true,
        errorMessage = null;

  AuthResult.failure(this.errorMessage)
      : success = false,
        user = null;
}

/// Authentication service - provider agnostic interface
/// Currently implements Firebase Auth but can be swapped
abstract class AuthService {
  /// Current authenticated user
  User? get currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges;

  /// Sign in with email and password
  Future<AuthResult> signInWithEmail(String email, String password);

  /// Create account with email and password
  Future<AuthResult> createAccountWithEmail(
      String email, String password, String fullName);

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle();

  /// Sign in with Apple
  Future<AuthResult> signInWithApple();

  /// Sign out
  Future<void> signOut();

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email);
}

/// Firebase implementation of AuthService
class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Reference to users collection
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login time
      if (credential.user != null) {
        await _updateLastLogin(credential.user!.uid);
      }

      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  @override
  Future<AuthResult> createAccountWithEmail(
      String email, String password, String fullName) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name on Firebase Auth profile
      await credential.user?.updateDisplayName(fullName);

      // Create user document in Firestore
      if (credential.user != null) {
        await _createUserDocument(
          user: credential.user!,
          displayName: fullName,
          provider: 'email',
        );
      }

      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return AuthResult.failure('Google sign in was cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Create or update user document
      if (userCredential.user != null) {
        await _createOrUpdateUserDocument(
          user: userCredential.user!,
          provider: 'google',
        );
      }

      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      debugPrint('Google sign in error: $e');
      return AuthResult.failure('Failed to sign in with Google');
    }
  }

  @override
  Future<AuthResult> signInWithApple() async {
    try {
      // Generate nonce for security
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Apple only provides name on first sign in
      String? displayName;
      if (appleCredential.givenName != null) {
        displayName =
            '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'
                .trim();
        await userCredential.user?.updateDisplayName(displayName);
      }

      // Create or update user document
      if (userCredential.user != null) {
        await _createOrUpdateUserDocument(
          user: userCredential.user!,
          displayName: displayName,
          provider: 'apple',
        );
      }

      return AuthResult.success(userCredential.user);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.failure('Apple sign in was cancelled');
      }
      return AuthResult.failure('Failed to sign in with Apple');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      debugPrint('Apple sign in error: $e');
      return AuthResult.failure('Failed to sign in with Apple');
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  @override
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Create a new user document in Firestore
  Future<void> _createUserDocument({
    required User user,
    String? displayName,
    required String provider,
  }) async {
    final now = DateTime.now();

    await _usersCollection.doc(user.uid).set({
      'email': user.email,
      'displayName': displayName ?? user.displayName,
      'photoUrl': user.photoURL,
      'provider': provider,
      'createdAt': Timestamp.fromDate(now),
      'lastLoginAt': Timestamp.fromDate(now),
    });
  }

  /// Create user document if it doesn't exist, or update last login
  Future<void> _createOrUpdateUserDocument({
    required User user,
    String? displayName,
    required String provider,
  }) async {
    final docRef = _usersCollection.doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      // User exists, update last login
      await _updateLastLogin(user.uid);
    } else {
      // New user, create document
      await _createUserDocument(
        user: user,
        displayName: displayName,
        provider: provider,
      );
    }
  }

  /// Update the last login timestamp
  Future<void> _updateLastLogin(String uid) async {
    await _usersCollection.doc(uid).update({
      'lastLoginAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Generate a random nonce for Apple Sign In
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// SHA256 hash of a string
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Update user's display name
  Future<AuthResult> updateDisplayName(String displayName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure('No user logged in');
      }

      // Update Firebase Auth profile
      await user.updateDisplayName(displayName);

      // Update Firestore document
      await _usersCollection.doc(user.uid).update({
        'displayName': displayName,
      });

      return AuthResult.success(user);
    } catch (e) {
      debugPrint('Update display name error: $e');
      return AuthResult.failure('Failed to update name');
    }
  }

  /// Update user's profile photo URL
  Future<AuthResult> updatePhotoUrl(String photoUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure('No user logged in');
      }

      // Update Firebase Auth profile
      await user.updatePhotoURL(photoUrl);

      // Update Firestore document
      await _usersCollection.doc(user.uid).update({
        'photoUrl': photoUrl,
      });

      return AuthResult.success(user);
    } catch (e) {
      debugPrint('Update photo URL error: $e');
      return AuthResult.failure('Failed to update photo');
    }
  }

  /// Update user's bio in Firestore
  Future<AuthResult> updateBio(String bio) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure('No user logged in');
      }

      await _usersCollection.doc(user.uid).update({
        'bio': bio,
      });

      return AuthResult.success(user);
    } catch (e) {
      debugPrint('Update bio error: $e');
      return AuthResult.failure('Failed to update bio');
    }
  }

  /// Get user's bio from Firestore
  Future<String?> getUserBio() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _usersCollection.doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['bio'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Get user bio error: $e');
      return null;
    }
  }

  /// Get user's auth provider
  Future<String?> getUserProvider() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _usersCollection.doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['provider'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Get user provider error: $e');
      return null;
    }
  }

  /// Change password (only for email/password users)
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return AuthResult.failure('No user logged in');
      }

      // Re-authenticate user first
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      debugPrint('Change password error: $e');
      return AuthResult.failure('Failed to change password');
    }
  }

  /// Convert Firebase error codes to user-friendly messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'operation-not-allowed':
        return 'This sign in method is not enabled';
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        return 'An error occurred. Please try again';
    }
  }
}

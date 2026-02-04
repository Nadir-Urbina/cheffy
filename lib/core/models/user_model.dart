import 'package:cloud_firestore/cloud_firestore.dart';

/// User model representing a user in Firestore
class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? bio;
  final String? provider; // 'email', 'google', 'apple'
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.bio,
    this.provider,
    required this.createdAt,
    this.lastLoginAt,
  });

  /// Create from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      provider: data['provider'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLoginAt: data['lastLoginAt'] != null
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'provider': provider,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    String? bio,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      provider: provider,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

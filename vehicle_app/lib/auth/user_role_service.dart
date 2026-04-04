import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRoleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';

  /// Create user profile if it doesn't exist
  static Future<void> createDefaultUserProfile(
    User user, {
    required String fullName,
    required String phone,
    required String address,
  }) async {
    final ref = _firestore.collection(_usersCollection).doc(user.uid);

    await ref.set({
      'uid': user.uid,
      'email': user.email,
      'fullName': fullName,
      'phone': phone,
      'address': address,
      'role': 'customer',
      'assignedInsurerId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user profile by UID
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();

      if (!snapshot.exists) return null;

      return snapshot.data();
    } catch (e) {
      print("Firestore error: $e");
      return null;
    }
  }

  /// Get profile for logged in user
  static Future<Map<String, dynamic>?> getUserProfileForUser(User user) async {
    // First try by UID
    final byUid = await getUserProfile(user.uid);
    if (byUid != null) return byUid;

    // fallback: search by email
    final email = user.email?.trim();
    if (email == null || email.isEmpty) return null;

    final query = await _firestore
        .collection(_usersCollection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    return query.docs.first.data();
  }

  /// Normalize role values
  static String normalizeRole(dynamic rawRole) {
    final role = (rawRole ?? 'customer')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');

    return role.isEmpty ? 'customer' : role;
  }

  /// Get role directly
  static Future<String> getRole(String uid) async {
    final profile = await getUserProfile(uid);

    if (profile == null) {
      return 'customer';
    }

    return normalizeRole(profile['role']);
  }
}
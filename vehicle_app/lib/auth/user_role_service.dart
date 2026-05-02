import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRoleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';

  static CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(_usersCollection);

  /// Create user profile if it doesn't exist
  static Future<void> createDefaultUserProfile(
    User user, {
    required String fullName,
    required String phone,
    required String address,
  }) async {
    final ref = _usersRef.doc(user.uid);

    await ref.set({
      'uid': user.uid,
      'email': user.email,
      'fullName': fullName,
      'phone': phone,
      'address': address,
      'role': 'customer',
      'assignedInsurerId': null,
      'preferredInsurerId': null,
      'preferredInsurerName': null,
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
    final snapshot = await getUserProfileSnapshotForUser(user);
    return snapshot?.data();
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?>
  getUserProfileSnapshotForUser(User user) async {
    // First try by UID
    final uidDoc = await _usersRef.doc(user.uid).get();
    if (uidDoc.exists) return uidDoc;

    // fallback: search by email
    final email = user.email?.trim();
    if (email == null || email.isEmpty) return null;

    final query = await _usersRef
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) return query.docs.first;

    final byUidField = await _usersRef.where('uid', isEqualTo: user.uid).limit(1).get();
    if (byUidField.docs.isEmpty) return null;
    return byUidField.docs.first;
  }

  static Future<DocumentReference<Map<String, dynamic>>>
  resolveUserProfileRefForUser(User user) async {
    final snapshot = await getUserProfileSnapshotForUser(user);
    return snapshot?.reference ?? _usersRef.doc(user.uid);
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

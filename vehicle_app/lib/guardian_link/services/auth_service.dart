import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import 'guardian_firebase.dart';

class AuthService {
  FirebaseAuth get _firebaseAuth => GuardianFirebase.auth;
  FirebaseDatabase get _database => GuardianFirebase.database;

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Register a new user
  Future<UserModel?> registerUser({
    required String email,
    required String password,
    required String name,
    required UserType userType,
    String? nicNumber,
    String? address,
    String? phoneNumber,
    int? age,
    BloodGroup? bloodGroup,
    String? medicalDescription,
    String? photoBase64,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();

      // Create Firebase Auth user
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      User user = userCredential.user!;

      // Create user document in Realtime Database
      final userModel = UserModel(
        id: user.uid,
        name: name,
        email: email,
        photoBase64: photoBase64,
        nicNumber: nicNumber,
        address: address,
        phoneNumber: phoneNumber,
        age: age,
        bloodGroup: bloodGroup,
        medicalDescription: medicalDescription,
        userType: userType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Realtime Database
      await _database.ref('users/${user.uid}').set(userModel.toJson());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw Exception('Registration failed: ${e.message}');
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  // Register a guardian without logging out current user
  Future<UserModel> registerGuardian({
    required String email,
    required String password,
    required String name,
    required String address,
    required String phoneNumber,
    required int age,
    required String linkedUserId,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      await GuardianFirebase.ensureInitialized();

      // Initialize secondary app to create user without signing out current user
      secondaryApp = await Firebase.initializeApp(
        name: 'GuardianLinkSecondary-${DateTime.now().microsecondsSinceEpoch}',
        options: GuardianFirebase.app.options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(
        app: secondaryApp,
      ).createUserWithEmailAndPassword(email: email, password: password);

      User user = userCredential.user!;

      final guardianUser = UserModel(
        id: user.uid,
        name: name,
        email: email,
        address: address,
        phoneNumber: phoneNumber,
        age: age,
        userType: UserType.guardian,
        linkedUserId: linkedUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save Guardian to DB
      await _database.ref('users/${user.uid}').set(guardianUser.toJson());

      // Update the Linked User (Ward) to have this guardian
      await _database.ref('users/$linkedUserId').update({
        'linkedUserId': user.uid,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return guardianUser;
    } catch (e) {
      throw Exception('Failed to register guardian: $e');
    } finally {
      await secondaryApp?.delete();
    }
  }

  // Login user
  Future<UserModel?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();

      UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      User user = userCredential.user!;

      // Fetch user data from Realtime Database
      final snapshot = await _database.ref('users/${user.uid}').get();

      if (snapshot.exists) {
        return UserModel.fromJson(snapshot.value as Map<dynamic, dynamic>);
      }

      return null;
    } on FirebaseAuthException catch (e) {
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('users/$userId').get();
      if (snapshot.exists) {
        return UserModel.fromJson(snapshot.value as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? address,
    BloodGroup? bloodGroup,
    String? medicalDescription,
    String? photoUrl,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      Map<String, dynamic> updates = {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (name != null) updates['name'] = name;
      if (address != null) updates['address'] = address;
      if (bloodGroup != null)
        updates['bloodGroup'] = bloodGroup
            .toString()
            .split('.')
            .last; // Save as string
      if (medicalDescription != null)
        updates['medicalDescription'] = medicalDescription;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      await _database.ref('users/$userId').update(updates);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Update user type
  Future<void> updateUserType({
    required String userId,
    required UserType userType,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      Map<String, dynamic> updates = {
        'userType': userType.toString().split('.').last,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _database.ref('users/$userId').update(updates);
    } catch (e) {
      throw Exception('Failed to update user type: $e');
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      await GuardianFirebase.ensureInitialized();
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await GuardianFirebase.ensureInitialized();
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to send reset email: $e');
    }
  }

  // Delete user account
  Future<void> deleteUserAccount(String userId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      // Delete user document from Realtime Database
      await _database.ref('users/$userId').remove();

      // Delete Firebase Auth user
      await currentUser?.delete();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  // Get all users of a specific type (for admin)
  Future<List<UserModel>> getUsersByType(UserType userType) async {
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('users').get();
      List<UserModel> users = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final userJson = value as Map<dynamic, dynamic>;
          final user = UserModel.fromJson(userJson);
          if (user.userType == userType) {
            users.add(user);
          }
        });
      }

      return users;
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }
}

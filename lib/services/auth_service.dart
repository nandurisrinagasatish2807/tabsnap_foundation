import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Checks if the Firestore document exists for the newly authenticated User.
  /// If missing, provisions a baseline document.
  Future<void> syncUserToFirestore(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      final newUser = UserModel(
        uid: user.uid,
        fullName: user.displayName ?? '',
        email: user.email ?? '',
        handle: '', // Handled later in profile setup
        createdAt: DateTime.now(),
      );

      await docRef.set(newUser.toFirestore());
    }
  }

  /// Transactionally reserves a unique handle and updates the user's profile.
  /// Generates the format: tabsnap://user/{uid} for the QR value.
  Future<bool> setupUserProfile({
    required String uid,
    required String fullName,
    required String handle,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final usernameRef = _firestore.collection('usernames').doc(handle.toLowerCase());

    try {
      await _firestore.runTransaction((transaction) async {
        final usernameSnapshot = await transaction.get(usernameRef);
        
        if (usernameSnapshot.exists) {
          throw Exception('Handle is already taken');
        }

        // Reserve handle
        transaction.set(usernameRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update user profile with qrValue format exactly as requested
        transaction.update(userRef, {
          'fullName': fullName,
          'handle': handle,
          'qrValue': 'tabsnap://user/$uid',
        });
      });
      return true;
    } catch (e) {
      // Re-throw or handle error
      return false;
    }
  }
}

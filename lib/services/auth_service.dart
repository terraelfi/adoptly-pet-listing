// auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Hard-coded admin UID for role-based features
  static const String adminUid = 'Tb283fE0wJXmdDsgK4JvWKarce73';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Check if current user is admin
  bool get isAdmin => _auth.currentUser?.uid == adminUid;

  // Ensure Firebase is initialized before performing any auth operations
  Future<void> _ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      print('Error ensuring Firebase is initialized: $e');
    }
  }

  // Sign up with email and password
  Future<UserCredential> signUp(
    String email,
    String password,
    String username,
  ) async {
    try {
      // Ensure Firebase is initialized
      await _ensureFirebaseInitialized();

      // Create user with email and password
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Save additional user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': username,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSignInAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Start listening for chat notifications
      _notificationService.startListeningForMessages();

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      // Ensure Firebase is initialized
      await _ensureFirebaseInitialized();

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ensure Firestore user doc exists and update sign-in time
      try {
        final uid = result.user!.uid;
        final userDocRef = _firestore.collection('users').doc(uid);
        final snap = await userDocRef.get();
        final now = FieldValue.serverTimestamp();
        if (!snap.exists) {
          final authEmail = result.user!.email;
          final defaultUsername =
              (authEmail != null && authEmail.isNotEmpty)
                  ? authEmail.split('@').first
                  : 'User';
          await userDocRef.set({
            'username': defaultUsername,
            'email': authEmail,
            'createdAt': now,
            'lastSignInAt': now,
            'updatedAt': now,
          }, SetOptions(merge: true));
        } else {
          await userDocRef.set({
            'lastSignInAt': now,
            'updatedAt': now,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        // Non-fatal; continue sign-in
        print('Failed to ensure user doc / update lastSignInAt: $e');
      }

      // Start listening for chat notifications
      _notificationService.startListeningForMessages();

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    // Ensure Firebase is initialized
    await _ensureFirebaseInitialized();

    // Stop listening for notifications before signing out
    _notificationService.stopListeningForMessages();
    await _auth.signOut();
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    if (_auth.currentUser == null) return null;

    try {
      DocumentSnapshot doc =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .get();

      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Get username by user ID
  Future<String> getUsernameById(String userId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)['username'] ??
            'Unknown User';
      }
      return 'Unknown User';
    } catch (e) {
      print('Error getting username: $e');
      return 'Unknown User';
    }
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}

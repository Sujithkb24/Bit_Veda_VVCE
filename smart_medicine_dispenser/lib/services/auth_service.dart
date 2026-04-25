// lib/services/auth_service.dart
// Handles all Firebase Authentication operations
import 'notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  // Get the Firebase Auth instance (singleton)
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of auth state changes — emits User when logged in, null when logged out
  // Use this in main.dart to decide which screen to show
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current logged-in user (null if not logged in)
  User? get currentUser => _auth.currentUser;

  // ── SIGN UP ──────────────────────────────────────────────────────────────
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required int age,
    required String bloodGroup,
    required String deviceId,
  }) async {
    try {
      // Create user with email/password
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      final token = await NotificationService().getToken();

      // Save additional user info to Firestore
      // Firebase Auth only stores email+password — everything else goes in Firestore
      await _db.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'age': age,
        'bloodGroup': bloodGroup,
        'dispenserDeviceId': deviceId,
        'medications': [],
        'fcmToken': token, //this was added
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // null means success
    } on FirebaseAuthException catch (e) {
      // Return a human-readable error message
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        default:
          return 'Sign up failed: ${e.message}';
      }
    }
  }

  // ── SIGN IN ──────────────────────────────────────────────────────────────
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
  email: email,
  password: password,
);

final uid = credential.user!.uid;

// Get FCM token
final token = await NotificationService().getToken();

// Save token in Firestore
if (token != null) {
  await _db.collection('users').doc(uid).update({
    'fcmToken': token,
  });
}
      return null; // null means success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        default:
          return 'Login failed: ${e.message}';
      }
    }
  }

  // ── SIGN OUT ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── FORGOT PASSWORD ───────────────────────────────────────────────────────
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // ── GET USER DATA ─────────────────────────────────────────────────────────
  Future<UserModel?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(uid, doc.data()!);
  }
}
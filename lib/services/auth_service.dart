import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, SupabaseClient;

enum UserRole {
  user,
  admin,
}

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final Logger _logger = Logger();


  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserRole> getCurrentUserRole() async {
    try {
      final userId = currentUser?.uid;
      if (userId == null) throw 'User not authenticated';

      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      return docSnapshot.data()?['role'] == 'admin' ? UserRole.admin : UserRole.user;
    } catch (e) {
      _logger.e('Error getting user role: $e');
      return UserRole.user;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    UserRole role = UserRole.user,
  }) async {
    try {
      _logger.d('Signing up user: $email');

      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw 'Signup failed: No user returned';
      }

      // Create user profile in Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'fullName': fullName,
        'email': email,
        'role': role.toString().split('.').last,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update display name
      await credential.user!.updateDisplayName(fullName);

      _logger.d('User signed up successfully: ${credential.user!.uid}');
    } catch (e) {
      _logger.e('Error during signup: $e');
      throw 'Error during signup: $e';
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _logger.d('Signing in user: $email');

      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw 'Login failed: No user returned';
      }

      _logger.d('User signed in successfully: ${credential.user!.uid}');
    } catch (e) {
      _logger.e('Error during login: $e');
      throw 'Error during login: $e';
    }
  }

  Future<void> signOut() async {
    try {
      _logger.d('Signing out user');
      await _auth.signOut();
      _logger.d('User signed out successfully');
    } catch (e) {
      _logger.e('Error during sign out: $e');
      throw 'Error during sign out: $e';
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _logger.d('Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      _logger.d('Password reset email sent successfully');
    } catch (e) {
      _logger.e('Error sending password reset: $e');
      throw 'Error sending password reset: $e';
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      _logger.d('Updating user password');
      if (currentUser == null) throw 'No user logged in';
      await currentUser!.updatePassword(newPassword);
      _logger.d('Password updated successfully');
    } catch (e) {
      _logger.e('Error updating password: $e');
      throw 'Error updating password: $e';
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final userId = currentUser?.uid;
      if (userId == null) throw 'User not authenticated';

      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!docSnapshot.exists) {
        throw 'User profile not found';
      }

      return docSnapshot.data() ?? {};
    } catch (e) {
      _logger.e('Error getting user profile: $e');
      throw 'Error getting user profile: $e';
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final userId = currentUser?.uid;
      if (userId == null) throw 'User not authenticated';

      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update display name if it's being changed
      if (data.containsKey('fullName')) {
        await currentUser!.updateDisplayName(data['fullName']);
      }

      _logger.d('Profile updated successfully');
    } catch (e) {
      _logger.e('Error updating profile: $e');
      throw 'Error updating profile: $e';
    }
  }

  // Additional Firebase-specific methods

  Future<void> verifyEmail() async {
    try {
      final user = currentUser;
      if (user == null) throw 'No user logged in';
      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      _logger.e('Error sending verification email: $e');
      throw 'Error sending verification email: $e';
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      // Create a GoogleSignIn instance
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) throw 'Google sign in aborted';

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Create/Update user profile in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'fullName': userCredential.user!.displayName,
        'email': userCredential.user!.email,
        'role': 'user',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      _logger.e('Error signing in with Google: $e');
      throw 'Error signing in with Google: $e';
    }
  }
}
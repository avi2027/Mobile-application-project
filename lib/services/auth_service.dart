import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:split/models/user_model.dart';
import 'package:split/services/user_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserService _userService = UserService();
  
  User? get currentUser => _auth.currentUser;
  
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    } catch (e) {
      throw 'An error occurred: ${e.toString()}';
    }
  }

  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    try {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);
        
        // Create user document in Firestore
        final userModel = UserModel(
          id: user.uid,
          email: user.email ?? email,
          displayName: displayName,
          avatarUrl: user.photoURL,
        );
        await _userService.createUser(userModel);
      }
    
    return credential;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    } catch (e) {
      throw 'An error occurred: ${e.toString()}';
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      // Sign out first to ensure clean state
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get Google authentication tokens. This usually means:\n'
            '1. SHA-1 fingerprint is not added to Firebase Console\n'
            '2. Google Sign-In is not enabled in Firebase Authentication\n'
            '3. OAuth client is not properly configured\n\n'
            'See GOOGLE_SIGNIN_SETUP.md for instructions.');
      }
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        // Check if user document exists, if not create it
        final existingUser = await _userService.getUserById(user.uid);
        if (existingUser == null) {
          final userModel = UserModel(
            id: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
            avatarUrl: user.photoURL,
          );
          await _userService.createUser(userModel);
        } else {
          // Update user info if it changed
          if (user.displayName != existingUser.displayName || 
              user.photoURL != existingUser.avatarUrl) {
            final updatedUser = UserModel(
              id: existingUser.id,
              email: existingUser.email,
              displayName: user.displayName ?? existingUser.displayName,
              avatarUrl: user.photoURL ?? existingUser.avatarUrl,
            );
            await _userService.updateUser(updatedUser);
          }
        }
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    } catch (e) {
      // Handle PlatformException for Google Sign-In errors
      final errorString = e.toString();
      if (errorString.contains('PlatformException') || 
          errorString.contains('ApiException') ||
          errorString.contains('sign_in_failed') ||
          errorString.contains('12500') ||
          errorString.contains('10')) {
        throw _getGoogleSignInErrorMessage(e);
      }
      if (errorString.contains('cancelled') || errorString.contains('12501')) {
        throw 'Sign in was cancelled';
      }
      // If the error message already contains helpful info, use it
      if (errorString.contains('SHA-1') || errorString.contains('Firebase Console')) {
        throw errorString;
      }
      throw 'An error occurred: $errorString';
    }
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-api-key':
      case 'api-key-not-valid':
        return 'Firebase API key is not valid. Please check your Firebase configuration.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'invalid-email':
        return 'Invalid email address. Please check and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        if (e.message != null && e.message!.contains('API key')) {
          return 'Firebase configuration error. Please check your Firebase setup.';
        }
        return e.message ?? 'An authentication error occurred.';
    }
  }

  String _getGoogleSignInErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('apiException: 10') || 
        errorString.contains('developer_error') ||
        errorString.contains('sign_in_failed') ||
        errorString.contains('12500')) {
      return 'Google Sign-In Configuration Error\n\n'
          'Firebase Console setup is incomplete. Follow these steps:\n\n'
          'STEP 1: Add SHA-1 Fingerprint\n'
          '• Go to: https://console.firebase.google.com/\n'
          '• Project: split-expense-2c469\n'
          '• Settings ⚙️ → Project settings\n'
          '• Your apps → Android app (com.splitter.split)\n'
          '• Click "Add fingerprint"\n'
          '• Paste: 5F:2B:10:91:73:ED:D6:D3:14:4B:FC:76:2F:6B:05:75:57:74:67:55\n'
          '• Click Save\n\n'
          'STEP 2: Enable Google Sign-In\n'
          '• Authentication → Sign-in method\n'
          '• Click "Google" → Enable\n'
          '• Enter support email → Save\n\n'
          'STEP 3: Download & Rebuild\n'
          '• Project Settings → Download google-services.json\n'
          '• Replace: android/app/google-services.json\n'
          '• Run: flutter clean && flutter run\n\n'
          'Wait 2-5 minutes after changes, then try again.';
    }
    
    if (errorString.contains('cancelled')) {
      return 'Sign in was cancelled';
    }
    
    if (errorString.contains('network')) {
      return 'Network error. Please check your internet connection.';
    }
    
    if (errorString.contains('12501')) {
      return 'Sign in was cancelled by user';
    }
    
    return 'Google Sign-In failed: ${error.toString()}';
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    } catch (e) {
      throw 'An error occurred: ${e.toString()}';
    }
  }
}

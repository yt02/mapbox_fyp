import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Stream to listen for auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Sign in with email/username and password
  Future<UserCredential> signInWithEmailPassword(String emailOrUsername, String password) async {
    try {
      // Check if input is email or username
      bool isEmail = emailOrUsername.contains('@');
      
      if (isEmail) {
        // Direct sign in with email
        final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: emailOrUsername,
          password: password,
        );
        
        // Save login state
        await _saveLoginState(true);
        
        return userCredential;
      } else {
        // If username, find associated email first
        final QuerySnapshot userQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: emailOrUsername)
            .limit(1)
            .get();
        
        if (userQuery.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No user found with this username.',
          );
        }
        
        // Get email from the document
        final String email = userQuery.docs.first.get('email');
        
        // Sign in with retrieved email
        final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Save login state
        await _saveLoginState(true);
        
        return userCredential;
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Register with email, password, username, and phone number
  Future<UserCredential> registerWithEmailPassword(
    String email, 
    String password, 
    {String? username, 
    String? phoneNum}
  ) async {
    try {
      // Check if username already exists
      if (username != null && username.isNotEmpty) {
        final QuerySnapshot usernameQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
        
        if (usernameQuery.docs.isNotEmpty) {
          throw FirebaseAuthException(
            code: 'username-already-in-use',
            message: 'An account already exists with this username.',
          );
        }
      }
      
      // Create user with email and password
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Save additional user data to Firestore
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'username': username ?? '',
          'phoneNum': phoneNum ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Save login state
      await _saveLoginState(true);
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
  
  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Begin interactive sign-in process
      final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
      
      if (gUser == null) {
        return null; // User canceled the sign-in flow
      }
      
      // Obtain auth details from request
      final GoogleSignInAuthentication gAuth = await gUser.authentication;
      
      // Create new credential for user
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      
      // Sign in with credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Check if this is a new user and save additional data
      if (userCredential.additionalUserInfo?.isNewUser == true && userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'username': userCredential.user!.displayName ?? '',
          'phoneNum': userCredential.user!.phoneNumber ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Save login state
      await _saveLoginState(true);
      
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }
  
  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (currentUser == null) return null;

      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();

      if (doc.exists) {
        return doc.data();
      } else {
        // If document doesn't exist, create it with basic user info
        await _createUserDocument();
        // Try to get the document again
        final newDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
        return newDoc.data();
      }
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Create user document if it doesn't exist
  Future<void> _createUserDocument() async {
    if (currentUser == null) return;

    try {
      await _firestore.collection('users').doc(currentUser!.uid).set({
        'email': currentUser!.email ?? '',
        'username': currentUser!.displayName ?? '',
        'phoneNum': currentUser!.phoneNumber ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user document: $e');
      rethrow;
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile({String? username, String? phoneNum}) async {
    try {
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final Map<String, dynamic> updateData = {};

      if (username != null && username.isNotEmpty) {
        // Check if username is already taken by another user
        final QuerySnapshot usernameQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();

        if (usernameQuery.docs.isNotEmpty &&
            usernameQuery.docs.first.id != currentUser!.uid) {
          throw Exception('Username already taken');
        }

        updateData['username'] = username;
      }

      if (phoneNum != null) {
        updateData['phoneNum'] = phoneNum;
      }

      if (updateData.isNotEmpty) {
        // Add timestamp for when the profile was last updated
        updateData['updatedAt'] = FieldValue.serverTimestamp();

        await _firestore.collection('users').doc(currentUser!.uid).update(updateData);
      }
    } on FirebaseException catch (e) {
      print('Firebase error updating user profile: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied: Please check your Firestore security rules');
      } else if (e.code == 'not-found') {
        throw Exception('User profile not found. Please try logging out and back in.');
      }
      rethrow;
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      // Clear login state
      await _saveLoginState(false);
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
  
  // Save login state to shared preferences
  Future<void> _saveLoginState(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }
  
  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }
} 